import { NextRequest, NextResponse } from "next/server";
import { getAuthenticatedUserId } from "@/lib/api-auth";
import { dynamoDBUsers, dynamoDBWorkouts } from "@/lib/dynamodb";
import { createRequestLogger } from "@/lib/logger";
import { AppMetrics, PerformanceMonitor } from "@/lib/metrics";
import { checkRateLimit } from "@/lib/rate-limit";
import { getQuotaLimit, normalizeSubscriptionTier } from "@/lib/subscription-tiers";
import { hasRole } from "@/lib/rbac";
import { isWeeklyResetDue } from "@/lib/quota-reset";

// GET /api/workouts - List all workouts for the current user
export async function GET(request: NextRequest) {
  const reqLogger = createRequestLogger(request);

  try {
    // Use new auth utility - eliminates unsafe type casting
    const auth = await getAuthenticatedUserId();
    if ('error' in auth) {
      reqLogger.finish(401);
      AppMetrics.apiRequest("GET", "/api/workouts", 401);
      return auth.error;
    }

    const { userId } = auth;

    // RATE LIMITING: Check rate limit (100 reads per minute)
    const rateLimit = await checkRateLimit(userId, 'api:read');
    if (!rateLimit.success) {
      reqLogger.finish(429);
      AppMetrics.apiRequest("GET", "/api/workouts", 429);
      return NextResponse.json(
        {
          error: 'Too many requests',
          message: 'You have exceeded the rate limit. Please try again later.',
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
    const searchParams = request.nextUrl.searchParams;

    // Validate and bound the limit parameter to prevent DoS
    const limitParam = searchParams.get("limit");
    const limit = limitParam
      ? Math.min(Math.max(parseInt(limitParam, 10) || 50, 1), 1000)
      : 50;

    if (limitParam && isNaN(parseInt(limitParam, 10))) {
      reqLogger.finish(400);
      AppMetrics.apiRequest("GET", "/api/workouts", 400);
      return NextResponse.json({ error: "Invalid limit parameter" }, { status: 400 });
    }

    reqLogger.log("Fetching workouts", { userId, limit });

    const perf = new PerformanceMonitor("api.workouts.get", { userId });
    const workouts = await dynamoDBWorkouts.list(userId, limit);
    const duration = perf.finish();

    reqLogger.log("Workouts fetched successfully", {
      userId,
      count: workouts.length,
      duration,
    });

    reqLogger.finish(200);
    AppMetrics.apiRequest("GET", "/api/workouts", 200);

    // Add cache headers to reduce API calls
    return NextResponse.json(
      { workouts },
      {
        headers: {
          'Cache-Control': 'private, max-age=60, stale-while-revalidate=30',
        },
      }
    );
  } catch (error) {
    reqLogger.error("Error fetching workouts", error as Error);
    reqLogger.finish(500);
    AppMetrics.apiError("GET", "/api/workouts", "InternalServerError");
    AppMetrics.error("DatabaseError", "workouts.list");

    return NextResponse.json({ error: "Failed to fetch workouts" }, { status: 500 });
  }
}

// POST /api/workouts - Create a new workout
export async function POST(request: NextRequest) {
  const reqLogger = createRequestLogger(request);

  try {
    // Use new auth utility - eliminates unsafe type casting
    const auth = await getAuthenticatedUserId();
    if ('error' in auth) {
      reqLogger.finish(401);
      AppMetrics.apiRequest("POST", "/api/workouts", 401);
      return auth.error;
    }

    const { userId } = auth;

    // RATE LIMITING: Check rate limit (50 writes per minute)
    const rateLimit = await checkRateLimit(userId, 'api:write');
    if (!rateLimit.success) {
      reqLogger.finish(429);
      AppMetrics.apiRequest("POST", "/api/workouts", 429);
      return NextResponse.json(
        {
          error: 'Too many requests',
          message: 'You have exceeded the rate limit. Please try again later.',
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

    const body = await request.json();
    const {
      workoutId,
      title,
      description,
      exercises,
      content,
      author,
      source,
      type,
      totalDuration,
      difficulty,
      tags,
      llmData,
      workoutType,
      structure,
      amrapBlocks,
      emomBlocks,
      timerConfig,
      blockTimers,
      aiEnhanced,
      aiNotes,
      muscleGroups,
      thumbnailUrl,
    } = body;

    if (!workoutId || !title || !exercises || !content) {
      reqLogger.finish(400);
      AppMetrics.apiRequest("POST", "/api/workouts", 400);
      return NextResponse.json({ error: "Missing required fields" }, { status: 400 });
    }

    const user = await dynamoDBUsers.get(userId);
    if (!user) {
      reqLogger.finish(404);
      AppMetrics.apiRequest("POST", "/api/workouts", 404);
      return NextResponse.json({ error: "User not found" }, { status: 404 });
    }

    const isAdmin = hasRole(user, 'admin');
    const tier = normalizeSubscriptionTier(user.subscriptionTier);
    const weeklyLimit = getQuotaLimit(tier, 'workoutsWeekly');
    let weeklyUsed = user.workoutsWeeklyUsed || 0;

    if (!isAdmin && weeklyLimit !== null) {
      if (isWeeklyResetDue(user.lastWorkoutReset)) {
        await dynamoDBUsers.resetWorkoutWeeklyQuota(userId);
        weeklyUsed = 0;
      }

      if (weeklyLimit <= 0) {
        reqLogger.finish(429);
        AppMetrics.apiRequest("POST", "/api/workouts", 429);
        return NextResponse.json(
          {
            error: "Workout limit exceeded",
            message: "You have reached your weekly workout limit. Upgrade your subscription to save more workouts.",
            quotaUsed: weeklyUsed,
            quotaLimit: weeklyLimit,
            subscriptionTier: user.subscriptionTier,
          },
          { status: 429 }
        );
      }

      const consumeResult = await dynamoDBUsers.consumeQuota(userId, 'workoutsWeeklyUsed', weeklyLimit);
      if (!consumeResult.success) {
        reqLogger.finish(429);
        AppMetrics.apiRequest("POST", "/api/workouts", 429);
        return NextResponse.json(
          {
            error: "Workout limit exceeded",
            message: `You have reached your weekly workout limit (${weeklyLimit} per week). Upgrade your subscription to save more workouts.`,
            quotaUsed: weeklyUsed,
            quotaLimit: weeklyLimit,
            subscriptionTier: user.subscriptionTier,
          },
          { status: 429 }
        );
      }
      weeklyUsed = consumeResult.newValue ?? weeklyUsed + 1;
    }

    reqLogger.log("Creating workout", { userId, workoutId, title });

    const perf = new PerformanceMonitor("api.workouts.post", { userId });
    const workout = await dynamoDBWorkouts.upsert(userId, {
      workoutId,
      title,
      description,
      exercises,
      content,
      author,
      source,
      type,
      totalDuration,
      difficulty,
      tags,
      llmData,
      workoutType,
      structure,
      amrapBlocks,
      emomBlocks,
      timerConfig,
      blockTimers,
      aiEnhanced,
      aiNotes,
      muscleGroups,
      thumbnailUrl,
    });
    const duration = perf.finish();

    reqLogger.log("Workout created successfully", { userId, workoutId, duration });
    await dynamoDBUsers.incrementCounter(userId, 'workoutsSaved');

    reqLogger.finish(201);
    AppMetrics.apiRequest("POST", "/api/workouts", 201);
    AppMetrics.workoutCreated(userId, source || "unknown");

    return NextResponse.json({ workout }, { status: 201 });
  } catch (error) {
    reqLogger.error("Error creating workout", error as Error);
    reqLogger.finish(500);
    AppMetrics.apiError("POST", "/api/workouts", "InternalServerError");
    AppMetrics.error("DatabaseError", "workouts.upsert");

    return NextResponse.json({ error: "Failed to create workout" }, { status: 500 });
  }
}
