/**
 * AI Token Usage Tracking and Cost Monitoring
 *
 * This module provides comprehensive tracking of AI token usage and costs
 * per user, subscription tier, and time period.
 */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  PutCommand,
  QueryCommand,
  UpdateCommand,
  GetCommand,
} from "@aws-sdk/lib-dynamodb";
import type { BedrockResponse } from "./bedrock-client";
import { getMonthKey } from "../quota-reset";

// Lazy-initialized DynamoDB client
let dynamoDbInstance: DynamoDBDocumentClient | null = null;

function getDynamoDb(): DynamoDBDocumentClient {
  if (!dynamoDbInstance) {
    const client = new DynamoDBClient({
      region: process.env.AWS_REGION || "us-east-1",
    });
    dynamoDbInstance = DynamoDBDocumentClient.from(client);
  }
  return dynamoDbInstance;
}

// Table names
const AI_USAGE_TABLE = process.env.DYNAMODB_AI_USAGE_TABLE || "spotter-ai-usage";
const USERS_TABLE = process.env.DYNAMODB_USERS_TABLE || "spotter-users";

/**
 * AI Usage Log Entry
 * Stores detailed token usage and cost data for each AI request
 */
export interface AIUsageLog {
  // Primary Keys
  userId: string;                    // Partition key
  requestId: string;                 // Sort key (timestamp-uuid)

  // Request Metadata
  timestamp: string;                 // ISO timestamp
  operation: string;                 // e.g., "generate-workout", "enhance-workout"
  model: string;                     // e.g., "opus", "sonnet", "haiku"

  // Token Usage
  inputTokens: number;
  outputTokens: number;
  cacheCreationTokens?: number;
  cacheReadTokens?: number;
  totalTokens: number;               // Sum of all tokens

  // Cost (USD)
  inputCost: number;
  outputCost: number;
  cacheCost?: number;
  totalCost: number;

  // User Context
  subscriptionTier: string;          // Tier at time of request

  // Optional Metadata
  workoutId?: string;                // If generating/enhancing a workout
  success: boolean;                  // Whether the request succeeded
  errorType?: string;                // Error type if failed

  // TTL for automatic cleanup (30 days)
  ttl?: number;
}

/**
 * User Cost Summary
 * Aggregated cost tracking per user stored in user table
 */
export interface UserCostSummary {
  // Current Period (Month)
  currentMonthCost: number;
  currentMonthTokens: number;
  currentMonthRequests: number;

  // All-Time Totals
  totalCost: number;
  totalTokens: number;
  totalRequests: number;

  // Last Reset
  lastCostReset: string;             // ISO timestamp
}

/**
 * Usage Cap Configuration per Tier
 */
export interface UsageCapConfig {
  maxMonthlyRequests: number;        // Request count limit
  maxMonthlyCost?: number;           // Optional cost cap in USD
  maxMonthlyTokens?: number;         // Optional token cap
  warnThreshold: number;             // % threshold to warn user (e.g., 0.8 for 80%)
}

/**
 * Default usage caps per subscription tier
 */
export const USAGE_CAPS: Record<string, UsageCapConfig> = {
  free: {
    maxMonthlyRequests: 1,
    maxMonthlyCost: 0.10,              // $0.10/month (safety cap)
    maxMonthlyTokens: 10000,
    warnThreshold: 0.8,
  },
  core: {
    maxMonthlyRequests: 10,
    maxMonthlyCost: 1.00,              // $1/month (~66 requests with Sonnet)
    maxMonthlyTokens: 100000,
    warnThreshold: 0.8,
  },
  pro: {
    maxMonthlyRequests: 30,
    maxMonthlyCost: 3.00,              // $3/month (~200 requests with Sonnet)
    maxMonthlyTokens: 300000,
    warnThreshold: 0.8,
  },
  elite: {
    maxMonthlyRequests: 100,
    maxMonthlyCost: 15.00,             // $15/month cap for Elite
    maxMonthlyTokens: 1000000,         // 1M tokens/month
    warnThreshold: 0.9,                // Warn at 90% for Elite
  },
};

/**
 * Log AI usage to DynamoDB
 */
export async function logAIUsage(params: {
  userId: string;
  operation: string;
  bedrockResponse: BedrockResponse;
  subscriptionTier: string;
  workoutId?: string;
  success?: boolean;
  errorType?: string;
}): Promise<void> {
  const {
    userId,
    operation,
    bedrockResponse,
    subscriptionTier,
    workoutId,
    success = true,
    errorType,
  } = params;

  const timestamp = new Date().toISOString();
  const requestId = `${Date.now()}-${Math.random().toString(36).substring(7)}`;

  // Calculate totals
  const totalTokens =
    bedrockResponse.usage.inputTokens +
    bedrockResponse.usage.outputTokens +
    (bedrockResponse.usage.cacheCreationInputTokens || 0) +
    (bedrockResponse.usage.cacheReadInputTokens || 0);

  const usageLog: AIUsageLog = {
    userId,
    requestId,
    timestamp,
    operation,
    model: bedrockResponse.model || 'sonnet',
    inputTokens: bedrockResponse.usage.inputTokens,
    outputTokens: bedrockResponse.usage.outputTokens,
    cacheCreationTokens: bedrockResponse.usage.cacheCreationInputTokens,
    cacheReadTokens: bedrockResponse.usage.cacheReadInputTokens,
    totalTokens,
    inputCost: bedrockResponse.cost?.input || 0,
    outputCost: bedrockResponse.cost?.output || 0,
    cacheCost: bedrockResponse.cost?.cache || 0,
    totalCost: bedrockResponse.cost?.total || 0,
    subscriptionTier,
    workoutId,
    success,
    errorType,
    ttl: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60), // 30 days
  };

  try {
    // Log to usage table
    await getDynamoDb().send(
      new PutCommand({
        TableName: AI_USAGE_TABLE,
        Item: usageLog,
      })
    );

    // Update user cost summary
    await updateUserCostSummary(userId, {
      costIncrement: usageLog.totalCost,
      tokensIncrement: usageLog.totalTokens,
      requestsIncrement: 1,
    });

    console.log(`[AI Usage] ${operation} for user ${userId}: ${totalTokens} tokens, $${usageLog.totalCost.toFixed(4)}`);
  } catch (error) {
    console.error("Error logging AI usage:", error);
    // Don't throw - logging failure shouldn't break the request
  }
}

/**
 * Update user cost summary in user table
 */
async function updateUserCostSummary(
  userId: string,
  increments: {
    costIncrement: number;
    tokensIncrement: number;
    requestsIncrement: number;
  }
): Promise<void> {
  const now = new Date();
  const currentMonth = getMonthKey(now);

  try {
    const updateParams = {
      TableName: USERS_TABLE,
      Key: { id: userId },
      UpdateExpression: `
        SET
          currentMonthCost = if_not_exists(currentMonthCost, :zero) + :costInc,
          currentMonthTokens = if_not_exists(currentMonthTokens, :zero) + :tokensInc,
          currentMonthRequests = if_not_exists(currentMonthRequests, :zero) + :reqInc,
          totalCost = if_not_exists(totalCost, :zero) + :costInc,
          totalTokens = if_not_exists(totalTokens, :zero) + :tokensInc,
          totalRequests = if_not_exists(totalRequests, :zero) + :reqInc,
          lastCostUpdate = :now,
          costResetMonth = :month,
          updatedAt = :now
      `,
      ConditionExpression: "costResetMonth = :month",
      ExpressionAttributeValues: {
        ":zero": 0,
        ":costInc": increments.costIncrement,
        ":tokensInc": increments.tokensIncrement,
        ":reqInc": increments.requestsIncrement,
        ":now": now.toISOString(),
        ":month": currentMonth,
      },
    };

    try {
      await getDynamoDb().send(new UpdateCommand(updateParams));
    } catch (error: any) {
      if (error?.name !== "ConditionalCheckFailedException") {
        throw error;
      }

      await resetMonthlyCosts(userId);
      await getDynamoDb().send(new UpdateCommand(updateParams));
    }
  } catch (error) {
    console.error("Error updating user cost summary:", error);
    throw error;
  }
}

/**
 * Get user cost summary
 */
export async function getUserCostSummary(userId: string): Promise<UserCostSummary | null> {
  try {
    const result = await getDynamoDb().send(
      new GetCommand({
        TableName: USERS_TABLE,
        Key: { id: userId },
        ProjectionExpression:
          "currentMonthCost, currentMonthTokens, currentMonthRequests, " +
          "totalCost, totalTokens, totalRequests, lastCostReset, costResetMonth",
      })
    );

    if (!result.Item) {
      return null;
    }

    const now = new Date();
    const currentMonth = getMonthKey(now);
    const storedMonth = result.Item.costResetMonth;

    if (!storedMonth || storedMonth !== currentMonth) {
      await resetMonthlyCosts(userId);
      return {
        currentMonthCost: 0,
        currentMonthTokens: 0,
        currentMonthRequests: 0,
        totalCost: result.Item.totalCost || 0,
        totalTokens: result.Item.totalTokens || 0,
        totalRequests: result.Item.totalRequests || 0,
        lastCostReset: now.toISOString(),
      };
    }

    return {
      currentMonthCost: result.Item.currentMonthCost || 0,
      currentMonthTokens: result.Item.currentMonthTokens || 0,
      currentMonthRequests: result.Item.currentMonthRequests || 0,
      totalCost: result.Item.totalCost || 0,
      totalTokens: result.Item.totalTokens || 0,
      totalRequests: result.Item.totalRequests || 0,
      lastCostReset: result.Item.lastCostReset || result.Item.costResetMonth || new Date().toISOString(),
    };
  } catch (error) {
    console.error("Error getting user cost summary:", error);
    return null;
  }
}

/**
 * Check if user has exceeded usage caps
 */
export async function checkUsageCap(
  userId: string,
  subscriptionTier: string
): Promise<{
  allowed: boolean;
  reason?: string;
  usage: {
    requests: number;
    cost: number;
    tokens: number;
  };
  limits: UsageCapConfig;
  percentages: {
    requests: number;
    cost: number;
    tokens: number;
  };
  shouldWarn: boolean;
}> {
  const caps = USAGE_CAPS[subscriptionTier] || USAGE_CAPS.free;
  const summary = await getUserCostSummary(userId);

  if (!summary) {
    // No usage yet, allow
    return {
      allowed: true,
      usage: { requests: 0, cost: 0, tokens: 0 },
      limits: caps,
      percentages: { requests: 0, cost: 0, tokens: 0 },
      shouldWarn: false,
    };
  }

  const usage = {
    requests: summary.currentMonthRequests,
    cost: summary.currentMonthCost,
    tokens: summary.currentMonthTokens,
  };

  const percentages = {
    requests: usage.requests / caps.maxMonthlyRequests,
    cost: caps.maxMonthlyCost ? usage.cost / caps.maxMonthlyCost : 0,
    tokens: caps.maxMonthlyTokens ? usage.tokens / caps.maxMonthlyTokens : 0,
  };

  // Check if any limit is exceeded
  let allowed = true;
  let reason: string | undefined;

  if (usage.requests >= caps.maxMonthlyRequests) {
    allowed = false;
    reason = `Monthly request limit reached (${caps.maxMonthlyRequests} requests)`;
  } else if (caps.maxMonthlyCost && usage.cost >= caps.maxMonthlyCost) {
    allowed = false;
    reason = `Monthly cost cap reached ($${caps.maxMonthlyCost.toFixed(2)})`;
  } else if (caps.maxMonthlyTokens && usage.tokens >= caps.maxMonthlyTokens) {
    allowed = false;
    reason = `Monthly token limit reached (${caps.maxMonthlyTokens.toLocaleString()} tokens)`;
  }

  // Check if should warn (above threshold but not exceeded)
  const maxPercentage = Math.max(percentages.requests, percentages.cost, percentages.tokens);
  const shouldWarn = !allowed || maxPercentage >= caps.warnThreshold;

  return {
    allowed,
    reason,
    usage,
    limits: caps,
    percentages,
    shouldWarn,
  };
}

/**
 * Reset monthly cost counters for a user
 */
export async function resetMonthlyCosts(
  userId: string,
  options: { force?: boolean } = {}
): Promise<void> {
  const now = new Date();
  const currentMonth = getMonthKey(now);

  try {
    const updateParams: {
      TableName: string;
      Key: { id: string };
      UpdateExpression: string;
      ExpressionAttributeValues: Record<string, unknown>;
      ConditionExpression?: string;
    } = {
      TableName: USERS_TABLE,
      Key: { id: userId },
      UpdateExpression: `
        SET
          currentMonthCost = :zero,
          currentMonthTokens = :zero,
          currentMonthRequests = :zero,
          lastCostReset = :now,
          costResetMonth = :month,
          updatedAt = :now
      `,
      ExpressionAttributeValues: {
        ":zero": 0,
        ":now": now.toISOString(),
        ":month": currentMonth,
      },
    };

    if (!options.force) {
      updateParams.ConditionExpression =
        "attribute_not_exists(costResetMonth) OR costResetMonth <> :month";
    }

    await getDynamoDb().send(new UpdateCommand(updateParams));
    console.log(`Reset monthly costs for user ${userId}`);
  } catch (error) {
    if (!options.force && (error as any)?.name === "ConditionalCheckFailedException") {
      return;
    }
    console.error("Error resetting monthly costs:", error);
    throw error;
  }
}

/**
 * Get usage logs for a user within a date range
 */
export async function getUserUsageLogs(
  userId: string,
  startDate: string,
  endDate: string,
  limit = 100
): Promise<AIUsageLog[]> {
  try {
    const result = await getDynamoDb().send(
      new QueryCommand({
        TableName: AI_USAGE_TABLE,
        KeyConditionExpression: "userId = :userId AND requestId BETWEEN :start AND :end",
        ExpressionAttributeValues: {
          ":userId": userId,
          ":start": startDate,
          ":end": endDate,
        },
        Limit: limit,
        ScanIndexForward: false, // Most recent first
      })
    );

    return (result.Items || []) as AIUsageLog[];
  } catch (error) {
    console.error("Error getting user usage logs:", error);
    return [];
  }
}

/**
 * Get aggregated usage stats by subscription tier
 */
export async function getTierUsageStats(
  subscriptionTier: string,
  startDate: string,
  endDate: string
): Promise<{
  totalCost: number;
  totalTokens: number;
  totalRequests: number;
  averageCostPerRequest: number;
  averageTokensPerRequest: number;
}> {
  // Note: This would require a GSI on subscriptionTier + timestamp
  // For now, this is a placeholder for admin analytics
  // Implementation would scan the usage table with filters

  console.warn("getTierUsageStats requires GSI implementation");
  return {
    totalCost: 0,
    totalTokens: 0,
    totalRequests: 0,
    averageCostPerRequest: 0,
    averageTokensPerRequest: 0,
  };
}

/**
 * Adjust quota based on actual costs (admin function)
 *
 * This allows admins to dynamically adjust quotas if costs exceed expectations
 */
export async function adjustQuotaBasedOnCost(
  subscriptionTier: string,
  targetMonthlyCost: number
): Promise<{
  oldCap: UsageCapConfig;
  newCap: UsageCapConfig;
  adjustmentReason: string;
}> {
  const oldCap = USAGE_CAPS[subscriptionTier];

  // Calculate new request limit based on target cost
  // Assuming average Sonnet cost: ~$0.015 per request (4K tokens in, 2K out)
  const avgCostPerRequest = 0.015;
  const newMaxRequests = Math.floor(targetMonthlyCost / avgCostPerRequest);

  const newCap: UsageCapConfig = {
    ...oldCap,
    maxMonthlyCost: targetMonthlyCost,
    maxMonthlyRequests: Math.min(newMaxRequests, oldCap.maxMonthlyRequests),
  };

  // Note: In production, this would update a configuration table
  // For now, log the recommendation
  const adjustmentReason =
    `Adjusted ${subscriptionTier} tier to target $${targetMonthlyCost}/month ` +
    `(~${newMaxRequests} requests at $${avgCostPerRequest} avg)`;

  console.log(adjustmentReason);

  return { oldCap, newCap, adjustmentReason };
}
