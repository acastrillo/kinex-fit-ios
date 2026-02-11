/**
 * DynamoDB Body Metrics Operations
 *
 * Table: spotter-body-metrics
 * Partition Key: userId
 * Sort Key: metricType#date (e.g., "weight#2024-11-18" or "measurements#2024-11-18")
 */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  PutCommand,
  QueryCommand,
  DeleteCommand,
} from "@aws-sdk/lib-dynamodb";
import type { BodyWeightEntry, BodyMeasurements, BodyComposition } from "./body-metrics";

const client = new DynamoDBClient({
  region: process.env.AWS_REGION || "us-east-1",
});

const dynamoDb = DynamoDBDocumentClient.from(client);

const BODY_METRICS_TABLE = process.env.DYNAMODB_BODY_METRICS_TABLE || "spotter-body-metrics";

// Internal DynamoDB representation
interface DynamoDBBodyMetric {
  userId: string; // Partition key
  metricKey: string; // Sort key: "weight#2024-11-18", "measurements#2024-11-18", "composition#2024-11-18"
  metricType: 'weight' | 'measurements' | 'composition';
  date: string; // ISO string
  data: BodyWeightEntry | BodyMeasurements | BodyComposition;
  createdAt: string;
  updatedAt: string;
}

/**
 * Body Weight Operations
 */
export const dynamoDBBodyWeight = {
  /**
   * Log body weight
   */
  async log(entry: BodyWeightEntry): Promise<void> {
    const now = new Date().toISOString();
    const metricKey = `weight#${entry.date}`;

    await dynamoDb.send(
      new PutCommand({
        TableName: BODY_METRICS_TABLE,
        Item: {
          userId: entry.userId,
          metricKey,
          metricType: 'weight',
          date: entry.date,
          data: entry,
          createdAt: now,
          updatedAt: now,
        },
      })
    );
  },

  /**
   * Get weight history for user
   */
  async list(userId: string, limit: number = 100): Promise<BodyWeightEntry[]> {
    const result = await dynamoDb.send(
      new QueryCommand({
        TableName: BODY_METRICS_TABLE,
        KeyConditionExpression: "userId = :userId AND begins_with(metricKey, :prefix)",
        ExpressionAttributeValues: {
          ":userId": userId,
          ":prefix": "weight#",
        },
        Limit: limit,
        ScanIndexForward: false, // Most recent first
      })
    );

    return (result.Items || []).map(item => (item as DynamoDBBodyMetric).data as BodyWeightEntry);
  },

  /**
   * Get weight entries within date range
   */
  async getRange(userId: string, startDate: string, endDate: string): Promise<BodyWeightEntry[]> {
    const result = await dynamoDb.send(
      new QueryCommand({
        TableName: BODY_METRICS_TABLE,
        KeyConditionExpression: "userId = :userId AND metricKey BETWEEN :start AND :end",
        ExpressionAttributeValues: {
          ":userId": userId,
          ":start": `weight#${startDate}`,
          ":end": `weight#${endDate}`,
        },
        ScanIndexForward: true, // Chronological order
      })
    );

    return (result.Items || []).map(item => (item as DynamoDBBodyMetric).data as BodyWeightEntry);
  },

  /**
   * Delete weight entry
   */
  async delete(userId: string, date: string): Promise<void> {
    await dynamoDb.send(
      new DeleteCommand({
        TableName: BODY_METRICS_TABLE,
        Key: {
          userId,
          metricKey: `weight#${date}`,
        },
      })
    );
  },
};

/**
 * Body Measurements Operations
 */
export const dynamoDBBodyMeasurements = {
  /**
   * Log body measurements
   */
  async log(measurements: BodyMeasurements): Promise<void> {
    const now = new Date().toISOString();
    const metricKey = `measurements#${measurements.date}`;

    await dynamoDb.send(
      new PutCommand({
        TableName: BODY_METRICS_TABLE,
        Item: {
          userId: measurements.userId,
          metricKey,
          metricType: 'measurements',
          date: measurements.date,
          data: measurements,
          createdAt: now,
          updatedAt: now,
        },
      })
    );
  },

  /**
   * Get measurement history for user
   */
  async list(userId: string, limit: number = 100): Promise<BodyMeasurements[]> {
    const result = await dynamoDb.send(
      new QueryCommand({
        TableName: BODY_METRICS_TABLE,
        KeyConditionExpression: "userId = :userId AND begins_with(metricKey, :prefix)",
        ExpressionAttributeValues: {
          ":userId": userId,
          ":prefix": "measurements#",
        },
        Limit: limit,
        ScanIndexForward: false, // Most recent first
      })
    );

    return (result.Items || []).map(item => (item as DynamoDBBodyMetric).data as BodyMeasurements);
  },

  /**
   * Delete measurement entry
   */
  async delete(userId: string, date: string): Promise<void> {
    await dynamoDb.send(
      new DeleteCommand({
        TableName: BODY_METRICS_TABLE,
        Key: {
          userId,
          metricKey: `measurements#${date}`,
        },
      })
    );
  },
};

/**
 * Body Composition Operations
 */
export const dynamoDBBodyComposition = {
  /**
   * Log body composition
   */
  async log(composition: BodyComposition): Promise<void> {
    const now = new Date().toISOString();
    const metricKey = `composition#${composition.date}`;

    await dynamoDb.send(
      new PutCommand({
        TableName: BODY_METRICS_TABLE,
        Item: {
          userId: composition.userId,
          metricKey,
          metricType: 'composition',
          date: composition.date,
          data: composition,
          createdAt: now,
          updatedAt: now,
        },
      })
    );
  },

  /**
   * Get composition history for user
   */
  async list(userId: string, limit: number = 100): Promise<BodyComposition[]> {
    const result = await dynamoDb.send(
      new QueryCommand({
        TableName: BODY_METRICS_TABLE,
        KeyConditionExpression: "userId = :userId AND begins_with(metricKey, :prefix)",
        ExpressionAttributeValues: {
          ":userId": userId,
          ":prefix": "composition#",
        },
        Limit: limit,
        ScanIndexForward: false, // Most recent first
      })
    );

    return (result.Items || []).map(item => (item as DynamoDBBodyMetric).data as BodyComposition);
  },

  /**
   * Delete composition entry
   */
  async delete(userId: string, date: string): Promise<void> {
    await dynamoDb.send(
      new DeleteCommand({
        TableName: BODY_METRICS_TABLE,
        Key: {
          userId,
          metricKey: `composition#${date}`,
        },
      })
    );
  },
};

/**
 * Delete all body metrics for a user (used during account deletion)
 */
export async function deleteAllUserMetrics(userId: string): Promise<void> {
  // Query all metrics for the user
  const result = await dynamoDb.send(
    new QueryCommand({
      TableName: BODY_METRICS_TABLE,
      KeyConditionExpression: "userId = :userId",
      ExpressionAttributeValues: {
        ":userId": userId,
      },
      Limit: 1000, // Get up to 1000 metrics
    })
  );

  const items = result.Items || [];

  // Delete all metrics
  await Promise.all(
    items.map(item =>
      dynamoDb.send(
        new DeleteCommand({
          TableName: BODY_METRICS_TABLE,
          Key: {
            userId: item.userId,
            metricKey: item.metricKey,
          },
        })
      )
    )
  );

  console.log(`Deleted ${items.length} body metrics for user ${userId}`);
}
