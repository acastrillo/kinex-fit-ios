/**
 * AI Workout of the Day API
 *
 * GET /api/ai/workout-of-the-day
 *
 * Generates a personalized "Workout of the Day" recommendation:
 * - Uses training profile for personalization
 * - Considers recent workout history to avoid overtraining
 * - Varies workout types for balanced training
 * - Can return existing workout or generate new one
 */
import { NextRequest, NextResponse } from 'next/server';
import { getAuthenticatedSession } from '@/lib/api-auth';
import { dynamoDBUsers, dynamoDBWorkouts, DynamoDBWorkout } from '@/lib/dynamodb';
import { generateWorkout, validateGeneratedWorkout } from '@/lib/ai/workout-generator';
import { getAIRequestLimit, normalizeSubscriptionTier } from '@/lib/subscription-tiers';
import { checkRateLimit } from '@/lib/rate-limit';
import { hasRole } from '@/lib/rbac';
import { isMonthlyResetDue } from '@/lib/quota-reset';

interface WorkoutOfTheDayResponse {
  success: boolean;
  workout?: DynamoDBWorkout;
  isNew?: boolean; // true if generated, false if existing
  rationale?: string;
  cost?: {
    inputTokens: number;
    outputTokens: number;
    estimatedCost: number;
  };
  quotaRemaining?: number;
  error?: string;
}

/**
 * Get the most recent workouts to analyze training patterns
 */
async function getRecentWorkouts(userId: string, days: number = 7): Promise<DynamoDBWorkout[]> {
  try {
    const allWorkouts = await dynamoDBWorkouts.list(userId);
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - days);

    return allWorkouts
      .filter(w => {
        const workoutDate = new Date(w.completedDate || w.createdAt);
        return workoutDate >= cutoffDate;
      })
      .sort((a, b) => {
        const dateA = new Date(a.completedDate || a.createdAt);
        const dateB = new Date(b.completedDate || b.createdAt);
        return dateB.getTime() - dateA.getTime();
      });
  } catch (error) {
    console.error('[WOD] Error fetching recent workouts:', error);
    return [];
  }
}

/**
 * Determine what type of workout to recommend based on recent history
 */
function determineWorkoutFocus(recentWorkouts: DynamoDBWorkout[]): string {
  if (recentWorkouts.length === 0) {
    return 'full body strength workout for beginners';
  }

  // Get the last workout's focus
  const lastWorkout = recentWorkouts[0];
  const lastWorkoutTags = lastWorkout.tags || [];

  // Create a simple rotation: upper -> lower -> full body -> cardio
  if (lastWorkoutTags.some(t => t.toLowerCase().includes('upper'))) {
    return 'lower body strength workout';
  } else if (lastWorkoutTags.some(t => t.toLowerCase().includes('lower'))) {
    return 'full body workout with compound movements';
  } else if (lastWorkoutTags.some(t => t.toLowerCase().includes('cardio'))) {
    return 'upper body strength and hypertrophy workout';
  } else {
    return 'cardio and conditioning workout';
  }
}

export async function GET(req: NextRequest): Promise<NextResponse<WorkoutOfTheDayResponse>> {
  try {
    // Authentication
    const auth = await getAuthenticatedSession();
    if ('error' in auth) {
      return NextResponse.json(
        { success: false, error: 'Unauthorized' },
        { status: 401 }
      );
    }
    const { userId, session } = auth;

    // Check if user wants to force generation (via query param)
    const { searchParams } = new URL(req.url);
    const forceGenerate = searchParams.get('generate') === 'true';

    // Get user
    let user = await dynamoDBUsers.get(userId);
    if (!user) {
      // User not synced to DynamoDB yet - create with defaults
      console.log('[WOD] User not found in DynamoDB, creating with defaults');
      try {
        const userEmail = session.user?.email || `user-${userId}@temp.com`;
        const firstName = (session.user as any)?.firstName || null;
        const lastName = (session.user as any)?.lastName || null;

        user = await dynamoDBUsers.upsert({
          id: userId,
          email: userEmail,
          firstName,
          lastName,
          subscriptionTier: 'free',
          aiRequestsLimit: 0,
        });
      } catch (createError) {
        console.error('[WOD] Failed to create user:', createError);
        return NextResponse.json(
          { success: false, error: 'User not found and could not be created' },
          { status: 500 }
        );
      }
    }

    // Get recent workouts to analyze training patterns
    const recentWorkouts = await getRecentWorkouts(userId, 7);

    // If not forcing generation, try to return today's scheduled workout
    if (!forceGenerate) {
      const today = new Date().toISOString().split('T')[0];
      const scheduledToday = await dynamoDBWorkouts.getScheduledForDate(userId, today);

      if (scheduledToday.length > 0) {
        console.log('[WOD] Returning scheduled workout for today');
        return NextResponse.json({
          success: true,
          workout: scheduledToday[0],
          isNew: false,
          rationale: 'You have a workout scheduled for today. Complete this to stay on track with your training plan!',
        });
      }
    }

    // Check AI quota
    const tier = normalizeSubscriptionTier(user.subscriptionTier);
    const aiLimit = getAIRequestLimit(tier);

    // ADMIN BYPASS: Admins have unlimited AI quotas
    const isAdmin = hasRole(user, 'admin');

    let aiUsed = user.aiRequestsUsed || 0;
    if (!isAdmin && isMonthlyResetDue(user.lastAiRequestReset)) {
      await dynamoDBUsers.resetAIQuota(userId);
      aiUsed = 0;
    }

    if (!isAdmin && aiLimit <= 0) {
      const upgradeMessage = aiLimit === 0
        ? 'AI workout generation is not available on the free tier. Upgrade to Core ($8.99/mo) for 10 AI requests per month.'
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

    // Rate limiting (30 AI requests per hour across all AI features)
    const rateLimit = await checkRateLimit(userId, 'api:ai');
    if (!rateLimit.success) {
      return NextResponse.json(
        {
          success: false,
          error: 'Too many AI requests',
          limit: rateLimit.limit,
          remaining: rateLimit.remaining,
          reset: rateLimit.reset,
        } as any,
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

    // Determine workout focus based on recent activity
    const workoutFocus = determineWorkoutFocus(recentWorkouts);
    const prompt = `Create a ${workoutFocus} optimized for today. Duration: 45-60 minutes. Make it challenging but achievable.`;

    console.log('[WOD] Generating workout of the day...');
    console.log('[WOD] Focus:', workoutFocus);
    console.log('[WOD] Recent workouts:', recentWorkouts.length);

    // Get user's training profile
    const trainingProfile = user.trainingProfile || undefined;

    // Generate workout using AI
    const result = await generateWorkout({
      prompt,
      trainingProfile,
      userId,
    });

    // Validate generated workout
    const validation = validateGeneratedWorkout(result.workout);
    if (!validation.valid) {
      console.error('[WOD] Generated workout failed validation:', validation.errors);
      return NextResponse.json(
        {
          success: false,
          error: 'Generated workout is invalid. Please try again.',
        },
        { status: 500 }
      );
    }

    // Convert AI workout format to DynamoDB format
    const exercises = result.workout.exercises?.map((exercise: any) => ({
      id: `ex_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`,
      name: exercise.name,
      sets: exercise.sets || 1,
      reps: exercise.reps || null,
      weight: exercise.weight || null,
      restSeconds: exercise.restSeconds || null,
      notes: exercise.notes || null,
      duration: exercise.duration || null,
      setDetails: [],
    })) || [];

    // Create workout in DynamoDB
    const today = new Date().toISOString().split('T')[0];
    const newWorkout: Partial<DynamoDBWorkout> = {
      userId,
      workoutId: `wod_${Date.now()}`,
      title: `Today's Workout - ${result.workout.title || 'AI Generated'}`,
      description: result.workout.description || '',
      exercises,
      content: prompt,
      tags: [...(result.workout.tags || []), 'workout-of-the-day'],
      difficulty: result.workout.difficulty || 'intermediate',
      totalDuration: result.workout.duration || 60,
      source: 'ai-wod',
      type: 'manual',
      workoutType: 'standard',
      aiEnhanced: true,
      aiNotes: [
        `Workout of the Day generated on ${today}`,
        `Focus: ${workoutFocus}`,
        `Rationale: ${result.rationale}`,
      ],
      status: 'scheduled',
      scheduledDate: today,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    await dynamoDBWorkouts.upsert(userId, newWorkout as DynamoDBWorkout);
    const savedWorkout = newWorkout as DynamoDBWorkout;

    console.log('[WOD] Success!');
    console.log('[WOD] Workout:', savedWorkout.title);
    console.log('[WOD] Exercises:', exercises.length);
    console.log('[WOD] Focus:', workoutFocus);

    return NextResponse.json({
      success: true,
      workout: savedWorkout,
      isNew: true,
      rationale: result.rationale,
      cost: {
        inputTokens: result.bedrockResponse.usage.inputTokens,
        outputTokens: result.bedrockResponse.usage.outputTokens,
        estimatedCost: result.bedrockResponse.cost?.total || 0,
      },
      quotaRemaining: isAdmin ? 999999 : Math.max(0, aiLimit - aiUsedAfter),
    });
  } catch (error) {
    console.error('[WOD] Error:', error);

    return NextResponse.json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Failed to get workout of the day',
      },
      { status: 500 }
    );
  }
}
