/**
 * AI Workout of the Week API
 *
 * GET /api/ai/workout-of-the-week
 *
 * Generates a personalized "Workout of the Week" recommendation:
 * - Uses training profile for personalization
 * - Considers recent workout history to avoid overtraining
 * - Varies workout types for balanced training
 * - Can return existing workout or generate new one
 * - RESTRICTED TO PAID TIERS ONLY (Core and Pro)
 */
import { NextRequest, NextResponse } from 'next/server';
import { getAuthenticatedSession } from '@/lib/api-auth';
import { dynamoDBUsers, dynamoDBWorkouts, DynamoDBWorkout } from '@/lib/dynamodb';
import { generateWorkout, validateGeneratedWorkout } from '@/lib/ai/workout-generator';
import { getAIRequestLimit, normalizeSubscriptionTier } from '@/lib/subscription-tiers';
import { checkRateLimit } from '@/lib/rate-limit';
import { hasRole } from '@/lib/rbac';
import { isMonthlyResetDue } from '@/lib/quota-reset';

interface WorkoutOfTheWeekResponse {
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
 * Get the start date of the current week (Monday)
 */
function getWeekStartDate(): string {
  const now = new Date();
  const dayOfWeek = now.getDay();
  const diff = dayOfWeek === 0 ? -6 : 1 - dayOfWeek; // Adjust when day is Sunday
  const monday = new Date(now);
  monday.setDate(now.getDate() + diff);
  return monday.toISOString().split('T')[0];
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
    console.error('[WOW] Error fetching recent workouts:', error);
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

export async function GET(req: NextRequest): Promise<NextResponse<WorkoutOfTheWeekResponse>> {
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
      console.log('[WOW] User not found in DynamoDB, creating with defaults');
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
        console.error('[WOW] Failed to create user:', createError);
        return NextResponse.json(
          { success: false, error: 'User not found and could not be created' },
          { status: 500 }
        );
      }
    }

    // PAID TIER CHECK: Workout of the Week is only available to Core and Pro subscribers
    const tier = normalizeSubscriptionTier(user.subscriptionTier);
    const isAdmin = hasRole(user, 'admin');

    let aiUsed = user.aiRequestsUsed || 0;
    if (!isAdmin && isMonthlyResetDue(user.lastAiRequestReset)) {
      await dynamoDBUsers.resetAIQuota(userId);
      aiUsed = 0;
    }

    if (!isAdmin && tier === 'free') {
      return NextResponse.json(
        {
          success: false,
          error: 'Workout of the Week is only available to paid subscribers. Upgrade to Core ($8.99/mo) or Pro ($24.99/mo) to unlock this feature.',
        },
        { status: 403 }
      );
    }

    // Get recent workouts to analyze training patterns
    const recentWorkouts = await getRecentWorkouts(userId, 7);

    // If not forcing generation, try to return this week's scheduled workout
    if (!forceGenerate) {
      const weekStart = getWeekStartDate();
      const weekEnd = new Date(weekStart);
      weekEnd.setDate(weekEnd.getDate() + 6);
      const weekEndStr = weekEnd.toISOString().split('T')[0];

      // Check for any workout with 'workout-of-the-week' tag scheduled this week
      const allScheduled = await dynamoDBWorkouts.list(userId);
      const weeklyWorkout = allScheduled.find(w =>
        w.tags?.includes('workout-of-the-week') &&
        w.scheduledDate &&
        w.scheduledDate >= weekStart &&
        w.scheduledDate <= weekEndStr
      );

      if (weeklyWorkout) {
        console.log('[WOW] Returning scheduled workout for this week');
        return NextResponse.json({
          success: true,
          workout: weeklyWorkout,
          isNew: false,
          rationale: 'You have a workout of the week already scheduled. Complete this to stay on track with your training plan!',
        });
      }
    }

    // Check AI quota
    const aiLimit = getAIRequestLimit(tier);

    // ADMIN BYPASS: Admins have unlimited AI quotas
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
    const prompt = `Create a ${workoutFocus} optimized for this week. Duration: 45-60 minutes. Make it challenging but achievable.`;

    console.log('[WOW] Generating workout of the week...');
    console.log('[WOW] Focus:', workoutFocus);
    console.log('[WOW] Recent workouts:', recentWorkouts.length);

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
      console.error('[WOW] Generated workout failed validation:', validation.errors);
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
    const weekStart = getWeekStartDate();
    const newWorkout: Partial<DynamoDBWorkout> = {
      userId,
      workoutId: `wow_${Date.now()}`,
      title: `This Week's Workout - ${result.workout.title || 'AI Generated'}`,
      description: result.workout.description || '',
      exercises,
      content: prompt,
      tags: [...(result.workout.tags || []), 'workout-of-the-week'],
      difficulty: result.workout.difficulty || 'intermediate',
      totalDuration: result.workout.duration || 60,
      source: 'ai-wow',
      type: 'manual',
      workoutType: 'standard',
      aiEnhanced: true,
      aiNotes: [
        `Workout of the Week generated on ${weekStart}`,
        `Focus: ${workoutFocus}`,
        `Rationale: ${result.rationale}`,
      ],
      status: 'scheduled',
      scheduledDate: weekStart,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    await dynamoDBWorkouts.upsert(userId, newWorkout as DynamoDBWorkout);
    const savedWorkout = newWorkout as DynamoDBWorkout;

    console.log('[WOW] Success!');
    console.log('[WOW] Workout:', savedWorkout.title);
    console.log('[WOW] Exercises:', exercises.length);
    console.log('[WOW] Focus:', workoutFocus);

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
    console.error('[WOW] Error:', error);

    return NextResponse.json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Failed to get workout of the week',
      },
      { status: 500 }
    );
  }
}
