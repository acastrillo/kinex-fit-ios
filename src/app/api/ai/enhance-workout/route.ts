/**
 * AI Workout Enhancement API
 *
 * POST /api/ai/enhance-workout
 *
 * Takes a workout and uses AI to:
 * - Clean up formatting
 * - Add missing details (rest times, tempo, form cues)
 * - Suggest alternatives for exercises
 * - Optimize exercise order
 * - Add personalized notes based on user's training profile
 */
import { NextRequest, NextResponse } from 'next/server';
import { getAuthenticatedSession } from '@/lib/api-auth';
import { dynamoDBUsers, dynamoDBWorkouts, DynamoDBWorkout } from '@/lib/dynamodb';
import {
  structureWorkout,
  estimateEnhancementCost,
  type TrainingContext
} from '@/lib/ai/workout-enhancer';
import {
  organizeWorkoutContent,
  validateOrganizedContent,
} from '@/lib/ai/workout-content-organizer';
import {
  suggestTimerForWorkout,
  type WorkoutForTimerSuggestion,
  type TimerSuggestion
} from '@/lib/ai/timer-suggester';
import { getAIRequestLimit, normalizeSubscriptionTier } from '@/lib/subscription-tiers';
import { checkRateLimit } from '@/lib/rate-limit';
import { hasRole } from '@/lib/rbac';
import { checkUsageCap } from '@/lib/ai/usage-tracking';
import { isMonthlyResetDue } from '@/lib/quota-reset';

interface EnhanceWorkoutRequest {
  // Either workoutId (enhance existing) or rawText (parse new)
  workoutId?: string;
  rawText?: string;
  enhancementType?: 'full' | 'format' | 'details' | 'optimize';
}

interface EnhanceWorkoutResponse {
  success: boolean;
  enhancedWorkout?: DynamoDBWorkout;
  cost?: {
    inputTokens: number;
    outputTokens: number;
    estimatedCost: number;
  };
  quotaRemaining?: number;
  error?: string;
}

/**
 * Convert AI flat format to DynamoDB format
 */
function convertAIToDynamoDB(aiExercises: any[]): any[] {
  return aiExercises.map((exercise) => {
    // AI now returns flat format matching our table structure
    // AI format: { name, sets: 3, reps: "10" or "150M", weight: "135 lbs", duration: 200, notes, restSeconds }
    // DynamoDB format: { id, name, sets: number, reps, weight, restSeconds, notes, setDetails: [] }

    return {
      id: `ex_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`,
      name: exercise.name,
      sets: exercise.sets || 1,
      reps: exercise.reps || null,
      weight: exercise.weight || null,
      restSeconds: exercise.restSeconds || null,
      notes: exercise.notes || null,
      duration: exercise.duration || null,
      // Keep empty setDetails for backward compatibility
      setDetails: [],
    };
  });
}

export async function POST(req: NextRequest): Promise<NextResponse<EnhanceWorkoutResponse>> {
  try {
    // SECURITY FIX: Use new auth utility with session
    const auth = await getAuthenticatedSession();
    if ('error' in auth) {
      return NextResponse.json(
        { success: false, error: 'Unauthorized' },
        { status: 401 }
      );
    }
    const { userId, session } = auth;

    // RATE LIMITING: Check rate limit (30 AI requests per hour)
    const rateLimit = await checkRateLimit(userId, 'api:ai');
    if (!rateLimit.success) {
      return NextResponse.json(
        {
          success: false,
          error: 'Too many AI requests',
          limit: rateLimit.limit,
          remaining: rateLimit.remaining,
          reset: rateLimit.reset,
        },
        {
          status: 429,
          headers: {
            'X-RateLimit-Limit': rateLimit.limit.toString(),
            'X-RateLimit-Remaining': rateLimit.remaining.toString(),
            'X-RateLimit-Reset': rateLimit.reset.toString(),
            'Retry-After': Math.ceil((rateLimit.reset - Date.now()) / 1000).toString(),
          },
        }
      );
    }

    const body: EnhanceWorkoutRequest = await req.json();
    const { workoutId, rawText, enhancementType = 'full' } = body;

    if (!workoutId && !rawText) {
      return NextResponse.json(
        { success: false, error: 'Either workoutId or rawText is required' },
        { status: 400 }
      );
    }

    // Get user and check AI quota (create if doesn't exist)
    let user = await dynamoDBUsers.get(userId);
    if (!user) {
      // User not synced to DynamoDB yet - create with defaults
      console.log('[AI Enhance] User not found in DynamoDB, creating with defaults');
      try {
        const userEmail = session.user?.email || `user-${userId}@temp.com`;
        const firstName = (session.user as any)?.firstName || null;
        const lastName = (session.user as any)?.lastName || null;

        // Create user with free tier (production default)
        user = await dynamoDBUsers.upsert({
          id: userId,
          email: userEmail,
          firstName,
          lastName,
          subscriptionTier: 'free',
          aiRequestsLimit: 0,
        });
        console.log('[AI Enhance] User created successfully');
      } catch (createError) {
        console.error('[AI Enhance] Failed to create user:', createError);
        return NextResponse.json(
          { success: false, error: 'User not found and could not be created. Please try logging out and back in.' },
          { status: 500 }
        );
      }
    }

    const tier = normalizeSubscriptionTier(user.subscriptionTier);
    const aiLimit = getAIRequestLimit(tier);

    // ADMIN BYPASS: Admins have unlimited AI quotas
    const isAdmin = hasRole(user, 'admin');

    let aiUsed = user.aiRequestsUsed || 0;
    if (!isAdmin && isMonthlyResetDue(user.lastAiRequestReset)) {
      await dynamoDBUsers.resetAIQuota(userId);
      aiUsed = 0;
    }

    // Check if user has AI quota remaining (skip for admins)
    if (!isAdmin && aiLimit <= 0) {
      const upgradeMessage = aiLimit === 0
        ? 'AI features are not available on the free tier. Upgrade to Core ($8.99/mo) for 10 AI requests per month.'
        : `You've reached your AI request limit (${aiUsed}/${aiLimit} used this month). Upgrade to Pro for more AI requests.`;

      return NextResponse.json(
        {
          success: false,
          error: upgradeMessage,
          quotaRemaining: 0,
          tier,
          aiUsed,
          aiLimit,
        },
        { status: 403 }
      );
    }

    // Check usage caps (cost, tokens, requests) before consuming quota
    if (!isAdmin) {
      const capCheck = await checkUsageCap(userId, tier);
      if (!capCheck.allowed) {
        return NextResponse.json(
          {
            success: false,
            error: `Usage cap exceeded: ${capCheck.reason}. Your plan will reset next month.`,
            quotaRemaining: 0,
            tier,
            usage: capCheck.usage,
            limits: capCheck.limits,
          },
          { status: 403 }
        );
      }

      // Warn if approaching limits
      if (capCheck.shouldWarn) {
        console.warn(`[AI Enhance] User ${userId} approaching usage cap:`, {
          usage: capCheck.usage,
          limits: capCheck.limits,
          percentages: capCheck.percentages,
        });
      }
    }

    let aiUsedAfter = aiUsed;
    if (!isAdmin) {
      const consumeResult = await dynamoDBUsers.consumeQuota(userId, 'aiRequestsUsed', aiLimit);
      if (!consumeResult.success) {
        const upgradeMessage = `You've reached your AI request limit (${aiUsed}/${aiLimit} used this month). Upgrade to Pro for more AI requests.`;
        return NextResponse.json(
          {
            success: false,
            error: upgradeMessage,
            quotaRemaining: 0,
            tier,
            aiUsed,
            aiLimit,
          },
          { status: 403 }
        );
      }
      aiUsedAfter = consumeResult.newValue ?? aiUsed + 1;
    }

    // Determine what we're enhancing: existing workout or raw text
    let textToEnhance: string;
    let existingWorkout: DynamoDBWorkout | null = null;

    if (workoutId) {
      // Enhancing existing workout
      const workout = await dynamoDBWorkouts.get(userId, workoutId);
      if (!workout) {
        return NextResponse.json(
          { success: false, error: 'Workout not found' },
          { status: 404 }
        );
      }
      existingWorkout = workout;
      // Convert workout to text for enhancement
      textToEnhance = JSON.stringify({
        title: workout.title,
        description: workout.description,
        exercises: workout.exercises,
      }, null, 2);
    } else if (rawText) {
      // Parsing raw text (from OCR or social media)
      textToEnhance = rawText;
    } else {
      return NextResponse.json(
        { success: false, error: 'Either workoutId or rawText is required' },
        { status: 400 }
      );
    }

    console.log('[AI Enhance] Starting two-step agentic workflow...');
    console.log('[AI Enhance] Enhancement type:', enhancementType);
    console.log('[AI Enhance] Quota remaining:', isAdmin ? 'unlimited' : aiLimit - aiUsedAfter);

    // Build training context (TODO: Get PRs from user profile)
    const trainingContext: TrainingContext = {
      userId,
      experience: user.experience || 'intermediate',
      subscriptionTier: tier,
      workoutId: workoutId, // If enhancing existing workout
      // personalRecords: await getUserPRs(userId), // TODO: Implement
    };

    // STEP 1: Agent 1 - Organize Content (Filter exercises from fluff)
    console.log('[AI Enhance] Step 1: Organizing content with Agent 1 (Haiku)...');
    const organizationResult = await organizeWorkoutContent(textToEnhance);

    // Validate organized content
    if (!validateOrganizedContent(organizationResult.organized)) {
      console.error('[AI Enhance] Agent 1 returned invalid organized content');
      return NextResponse.json(
        { success: false, error: 'Failed to organize workout content. Please try again.' },
        { status: 500 }
      );
    }

    console.log('[AI Enhance] Agent 1 results:');
    console.log(`  - Exercise lines: ${organizationResult.organized.exerciseLines.length}`);
    console.log(`  - Notes: ${organizationResult.organized.notes.length}`);
    console.log(`  - Rejected: ${organizationResult.organized.rejected.length}`);
    if (organizationResult.organized.structure) {
      console.log(`  - Detected structure: ${organizationResult.organized.structure.type}`);
    }

    // STEP 2: Agent 2 - Structure Workout (Build final workout)
    console.log('[AI Enhance] Step 2: Structuring workout with Agent 2 (Sonnet)...');
    const result = await structureWorkout(organizationResult.organized, trainingContext);

    // STEP 3: Agent 3 - Suggest Timer Configuration (Optional)
    console.log('[AI Enhance] Step 3: Suggesting timer configuration with Agent 3 (Haiku)...');
    let timerSuggestion: TimerSuggestion | null = null;
    let timerSuggesterCost = 0;

    try {
      const workoutForTimer: WorkoutForTimerSuggestion = {
        title: result.enhancedWorkout.title,
        description: result.enhancedWorkout.description,
        workoutType: result.enhancedWorkout.workoutType,
        structure: result.enhancedWorkout.structure as any,
        exercises: result.enhancedWorkout.exercises as any,
        totalDuration: result.enhancedWorkout.duration,
        difficulty: result.enhancedWorkout.difficulty,
      };

      const timerResult = await suggestTimerForWorkout(workoutForTimer);
      timerSuggestion = timerResult.suggestion;
      timerSuggesterCost = timerResult.bedrockResponse.cost?.total || 0;

      console.log('[AI Enhance] Agent 3 results:');
      console.log(`  - Workout style: ${timerSuggestion.workoutStyle}`);
      console.log(`  - Primary goal: ${timerSuggestion.primaryGoal}`);
      if (timerSuggestion.suggestedTimer) {
        console.log(`  - Timer type: ${timerSuggestion.suggestedTimer.type}`);
        console.log(`  - Reason: ${timerSuggestion.suggestedTimer.reason}`);
      } else {
        console.log(`  - No timer suggested (not applicable for this workout)`);
      }
    } catch (error) {
      console.error('[AI Enhance] Timer suggestion failed (non-critical):', error);
      // Timer suggestion is optional, continue without it
    }

    // Calculate total cost (all three agents)
    const totalCost = (organizationResult.bedrockResponse.cost?.total || 0) +
                     (result.bedrockResponse.cost?.total || 0) +
                     timerSuggesterCost;
    console.log('[AI Enhance] Three-step workflow complete!');
    console.log(`  - Agent 1 cost: $${organizationResult.bedrockResponse.cost?.total.toFixed(4) || '0.0000'}`);
    console.log(`  - Agent 2 cost: $${result.bedrockResponse.cost?.total.toFixed(4) || '0.0000'}`);
    console.log(`  - Agent 3 cost: $${timerSuggesterCost.toFixed(4)}`);
    console.log(`  - Total cost: $${totalCost.toFixed(4)}`);

    // Convert AI exercises format to DynamoDB format
    const convertedExercises = result.enhancedWorkout.exercises
      ? convertAIToDynamoDB(result.enhancedWorkout.exercises)
      : [];

    // Extract workout structure metadata
    const workoutType = result.enhancedWorkout.workoutType || 'standard';
    const structure = result.enhancedWorkout.structure || null;

    // Build AI notes including timer suggestion
    const aiNotes = ['AI enhanced workout with standardized exercise names and proper structure detection'];
    if (timerSuggestion?.suggestedTimer) {
      aiNotes.push(
        `AI-suggested timer: ${timerSuggestion.suggestedTimer.type} - ${timerSuggestion.suggestedTimer.reason}`
      );
    }

    // Prepare timer config if suggested (will be stored in Phase 5 when DB schema is updated)
    const timerConfig = timerSuggestion?.suggestedTimer
      ? {
          params: timerSuggestion.suggestedTimer.params,
          aiGenerated: true,
          reason: timerSuggestion.suggestedTimer.reason,
        }
      : undefined;

    // If enhancing existing workout, merge with original
    let finalWorkout: DynamoDBWorkout;
    if (existingWorkout) {
      // Update existing workout
      const updates = {
        title: result.enhancedWorkout.title || existingWorkout.title,
        description: result.enhancedWorkout.description || existingWorkout.description || undefined,
        exercises: convertedExercises.length > 0 ? convertedExercises : existingWorkout.exercises,
        tags: result.enhancedWorkout.tags || existingWorkout.tags,
        difficulty: result.enhancedWorkout.difficulty || existingWorkout.difficulty,
        totalDuration: result.enhancedWorkout.duration || existingWorkout.totalDuration,
        workoutType,
        structure,
        aiEnhanced: true,
        aiNotes,
        timerConfig,
        updatedAt: new Date().toISOString(),
      };
      await dynamoDBWorkouts.update(userId, workoutId!, updates);
      finalWorkout = { ...existingWorkout, ...updates };
    } else {
      // Create new workout from parsed text
      const newWorkout: Partial<DynamoDBWorkout> = {
        userId,
        workoutId: `workout_${Date.now()}`,
        title: result.enhancedWorkout.title || 'Untitled Workout',
        description: result.enhancedWorkout.description || '',
        exercises: convertedExercises,
        content: textToEnhance, // Store original text
        tags: result.enhancedWorkout.tags || [],
        difficulty: result.enhancedWorkout.difficulty || 'intermediate',
        totalDuration: result.enhancedWorkout.duration || 60,
        source: 'ai-parse',
        type: 'manual',
        workoutType,
        structure,
        aiEnhanced: true,
        aiNotes,
        timerConfig,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };
      await dynamoDBWorkouts.upsert(userId, newWorkout as DynamoDBWorkout);
      finalWorkout = newWorkout as DynamoDBWorkout;
    }

    // Calculate cost
    const cost = estimateEnhancementCost(textToEnhance.length);

    console.log('[AI Enhance] Success!');
    console.log('[AI Enhance] Workout Type:', workoutType);
    console.log('[AI Enhance] Structure:', structure);
    console.log('[AI Enhance] Tokens:', result.bedrockResponse.usage);
    console.log('[AI Enhance] Estimated cost:', cost);

    return NextResponse.json({
      success: true,
      enhancedWorkout: finalWorkout,
      cost: {
        inputTokens: result.bedrockResponse.usage.inputTokens,
        outputTokens: result.bedrockResponse.usage.outputTokens,
        estimatedCost: result.bedrockResponse.cost?.total || cost,
      },
      quotaRemaining: isAdmin ? 999999 : Math.max(0, aiLimit - aiUsedAfter),
    });
  } catch (error) {
    console.error('[AI Enhance] Error:', error);

    return NextResponse.json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Failed to enhance workout',
      },
      { status: 500 }
    );
  }
}

