import { NextRequest, NextResponse } from 'next/server'
import { getAuthenticatedUserId } from '@/lib/api-auth'
import { checkRateLimit } from '@/lib/rate-limit'
import { parseWorkoutContentWithFallback } from '@/lib/workout-parser'
import { dynamoDBUsers } from '@/lib/dynamodb'
import { getQuotaLimit, normalizeSubscriptionTier } from '@/lib/subscription-tiers'
import { hasRole } from '@/lib/rbac'
import { isMonthlyResetDue, isWeeklyResetDue } from '@/lib/quota-reset'

interface ApifyInstagramResult {
  url?: string
  caption?: string
  displayUrl?: string
  timestamp?: string
  likesCount?: number
  commentsCount?: number
  ownerUsername?: string
  ownerFullName?: string
  text?: string
  // Additional possible fields
  id?: string
  shortcode?: string
  videoUrl?: string
  alt?: string
}

interface InstagramFetchRequest {
  url: string
}

export async function POST(request: NextRequest) {
  try {
    // SECURITY FIX: Use new auth utility
    const auth = await getAuthenticatedUserId();
    if ('error' in auth) return auth.error;
    const { userId } = auth;

    // RATE LIMITING: Check rate limit (20 Instagram requests per hour)
    const rateLimit = await checkRateLimit(userId, 'api:instagram');
    if (!rateLimit.success) {
      return NextResponse.json(
        {
          error: 'Too many Instagram requests',
          message: 'You have exceeded the rate limit for Instagram fetching. Please try again later.',
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
          },
        }
      );
    }

    // Check Instagram import quota
    const user = await dynamoDBUsers.get(userId);
    if (!user) {
      return NextResponse.json({ error: 'User not found' }, { status: 404 });
    }

    // ADMIN BYPASS: Admins have unlimited quotas
    const isAdmin = hasRole(user, 'admin');

    // Get quota limit based on subscription tier
    const tier = normalizeSubscriptionTier(user.subscriptionTier);

    // Free tier has monthly limit (instagramSavesMonthly)
    // Core tier has weekly limit (instagramSavesWeekly)
    // Pro/Elite have unlimited (null)
    const monthlyLimit = getQuotaLimit(tier, 'instagramSavesMonthly');
    const weeklyLimit = getQuotaLimit(tier, 'instagramSavesWeekly');

    // Use whichever limit is defined for this tier
    const limit = monthlyLimit !== null ? monthlyLimit : weeklyLimit;
    let importsUsed = user.instagramImportsUsed || 0;

    if (!isAdmin && limit !== null) {
      const shouldReset = monthlyLimit !== null
        ? isMonthlyResetDue(user.lastInstagramImportReset)
        : isWeeklyResetDue(user.lastInstagramImportReset);

      if (shouldReset) {
        await dynamoDBUsers.resetInstagramQuota(userId);
        importsUsed = 0;
      }
    }

    const { url }: InstagramFetchRequest = await request.json()

    if (!url) {
      return NextResponse.json(
        { error: 'Instagram URL is required' },
        { status: 400 }
      )
    }

    // Validate Instagram URL format
    const instagramUrlPattern = /^https?:\/\/(www\.)?(instagram\.com|instagr\.am)\/(p|reel)\/[\w-]+\/?/
    if (!instagramUrlPattern.test(url)) {
      return NextResponse.json(
        { error: 'Invalid Instagram URL format' },
        { status: 400 }
      )
    }

    let importsUsedAfter = importsUsed;
    if (!isAdmin && limit !== null) {
      if (limit <= 0) {
        const limitPeriod = monthlyLimit !== null ? 'month' : 'week';
        return NextResponse.json(
          {
            error: 'Instagram import quota exceeded',
            message: `You have reached your Instagram import limit (${importsUsed}/${limit} per ${limitPeriod}). Upgrade your subscription for more imports.`,
            quotaUsed: importsUsed,
            quotaLimit: limit,
            subscriptionTier: user.subscriptionTier
          },
          { status: 429 }
        );
      }

      const consumeResult = await dynamoDBUsers.consumeQuota(userId, 'instagramImportsUsed', limit);
      if (!consumeResult.success) {
        const limitPeriod = monthlyLimit !== null ? 'month' : 'week';
        return NextResponse.json(
          {
            error: 'Instagram import quota exceeded',
            message: `You have reached your Instagram import limit (${importsUsed}/${limit} per ${limitPeriod}). Upgrade your subscription for more imports.`,
            quotaUsed: importsUsed,
            quotaLimit: limit,
            subscriptionTier: user.subscriptionTier
          },
          { status: 429 }
        );
      }
      importsUsedAfter = consumeResult.newValue ?? importsUsed + 1;
    }

    const apifyApiToken = process.env.APIFY_API_TOKEN
    if (!apifyApiToken) {
      // SECURITY FIX: Don't log token presence
      console.error('[Instagram] APIFY_API_TOKEN not configured')
      return NextResponse.json(
        {
          error:
            'Missing APIFY_API_TOKEN environment variable. See .env.example for setup.',
        },
        { status: 500 }
      )
    }

    // SECURITY FIX: Log masked token for debugging (only first 4 chars in production)
    const isProduction = process.env.NODE_ENV === 'production';
    const maskedToken = isProduction ? apifyApiToken.substring(0, 4) + '***' : apifyApiToken.substring(0, 8) + '...';
    console.log('[Instagram] Using APIFY token:', maskedToken);

    // Fetching Instagram URL

    try {
      // Call Apify Instagram scraper - start the run
      const apifyResponse = await fetch('https://api.apify.com/v2/acts/shu8hvrXbJbY3Eb9W/runs', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apifyApiToken}`,
        },
        body: JSON.stringify({
          directUrls: [url],
          resultsLimit: 1,
          resultsType: "posts",
          addParentData: false,
          enhanceUserSearchWithFacebookPage: false,
          isUserReelFeedURL: false,
          isUserTaggedFeedURL: false,
          searchLimit: 1,
        }),
      })


      if (!apifyResponse.ok) {
        // SECURITY FIX: Don't log full error (may contain token)
        console.error('[Instagram] Apify API error:', apifyResponse.status)
        return NextResponse.json(
          {
            error: `Failed to start Instagram scraper: ${apifyResponse.status}`,
            // SECURITY FIX: Don't expose internal error details to client
          },
          { status: apifyResponse.status }
        )
      }

      const runResponse = await apifyResponse.json()

      if (!runResponse || !runResponse.data || !runResponse.data.id) {
        // SECURITY FIX: Don't log full response (may contain sensitive data)
        console.error('[Instagram] No run ID in response')
        return NextResponse.json(
          { error: 'Failed to start Instagram scraper - no run ID returned' },
          { status: 500 }
        )
      }

      const runData = runResponse.data

      // Wait for the run to complete (poll the status)
      let attempts = 0
      const maxAttempts = 60 // 60 seconds max wait for Instagram scraping

      while (attempts < maxAttempts) {
        await new Promise(resolve => setTimeout(resolve, 1000)) // Wait 1 second

        const statusResponse = await fetch(`https://api.apify.com/v2/actor-runs/${runData.id}`, {
          headers: {
            'Authorization': `Bearer ${apifyApiToken}`,
          },
        })

        if (!statusResponse.ok) {
          console.error('Status check failed:', statusResponse.status)
          attempts++
          continue
        }

        const statusResponse_ = await statusResponse.json()
        const statusData = statusResponse_.data || statusResponse_

        if (!statusData || !statusData.status) {
          // SECURITY FIX: Don't log full response
          console.error('[Instagram] Invalid status response')
          attempts++
          continue
        }

        if (statusData.status === 'SUCCEEDED') {

          // Get the dataset results
          const datasetResponse = await fetch(
            `https://api.apify.com/v2/datasets/${statusData.defaultDatasetId}/items`,
            {
              headers: {
                'Authorization': `Bearer ${apifyApiToken}`,
              },
            }
          )

          if (!datasetResponse.ok) {
            // SECURITY FIX: Don't log or expose internal error details
            console.error('[Instagram] Dataset fetch error:', datasetResponse.status)
            return NextResponse.json(
              { error: 'Failed to fetch Instagram data' },
              { status: datasetResponse.status }
            )
          }

          const results: ApifyInstagramResult[] = await datasetResponse.json()

          if (!results || results.length === 0) {
            return NextResponse.json(
              { error: 'No Instagram post found' },
              { status: 404 }
            )
          }

          // Process the results
          const post = results[0]

          const caption = post.caption || post.text || ''
          const postUrl = post.url || url
          const timestamp = post.timestamp || new Date().toISOString()

          // Use smart workout parser for better accuracy
          const parsedWorkout = await parseWorkoutContentWithFallback(caption, {
            context: { userId, subscriptionTier: user.subscriptionTier },
          });
          const resolvedTitle = parsedWorkout.title
            || `Instagram Workout - ${new Date(timestamp).toLocaleDateString()}`;

          const workoutData = {
            url: postUrl,
            title: resolvedTitle,
            content: caption,
            author: {
              username: post.ownerUsername || 'unknown',
              fullName: post.ownerFullName || 'Unknown User',
            },
            stats: {
              likes: post.likesCount || 0,
              comments: post.commentsCount || 0,
            },
            image: post.displayUrl || '',
            timestamp: timestamp,
            parsedWorkout: {
              exercises: parsedWorkout.exercises.map(ex => ({
                name: ex.name,
                sets: ex.sets,
                reps: ex.reps,
                weight: ex.weight,
                time: ex.unit === 'time' ? ex.reps : undefined,
              })),
              rawText: caption,
              totalExercises: parsedWorkout.exercises.length,
              workoutInstructions: parsedWorkout.summary,
              workoutType: parsedWorkout.workoutType,
              structure: parsedWorkout.structure,
              amrapBlocks: parsedWorkout.amrapBlocks,
              emomBlocks: parsedWorkout.emomBlocks,
              confidence: parsedWorkout.confidence,
              usedLLM: parsedWorkout.usedLLM,
              source: parsedWorkout.source,
            },
          }

          // Add quota info to response
          const currentLimit = isAdmin ? null : limit;

          return NextResponse.json({
            ...workoutData,
            quotaUsed: isAdmin ? importsUsed : importsUsedAfter,
            quotaLimit: currentLimit,
            isUnlimited: isAdmin || currentLimit === null
          })

        } else if (statusData.status === 'FAILED') {
          console.error('Run failed:', statusData.statusMessage)
          return NextResponse.json(
            { error: `Instagram scraper failed: ${statusData.statusMessage}` },
            { status: 500 }
          )
        } else if (statusData.status === 'ABORTED') {
          return NextResponse.json(
            { error: 'Instagram scraper was aborted' },
            { status: 500 }
          )
        }

        attempts++
      }

      // If we get here, the run didn't complete in time
      return NextResponse.json(
        { error: 'Instagram scraper timed out. Try again in a moment.' },
        { status: 408 }
      )

    } catch (parseError) {
      console.error('JSON Parse error:', parseError)
      return NextResponse.json(
        { error: 'Failed to parse API response' },
        { status: 500 }
      )
    }


  } catch (error) {
    console.error('Instagram fetch error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
