/**
 * Shared NextAuth configuration
 * Exposes multiple providers (Google, Facebook, Email) without routing through Cognito
 */

import GoogleProvider from "next-auth/providers/google";
import FacebookProvider from "next-auth/providers/facebook";
import CredentialsProvider from "next-auth/providers/credentials";
import { type NextAuthOptions } from "next-auth";
import { dynamoDBUsers } from "@/lib/dynamodb";
import { randomUUID } from "crypto";
import { compare } from "bcryptjs";
import { maskEmail } from "@/lib/safe-logger";
import { normalizeSubscriptionTier } from "@/lib/subscription-tiers";
import { checkRateLimit } from "@/lib/rate-limit";
import { getRequestIp } from "@/lib/request-ip";
import { sendSignupAlert } from "@/lib/email-service";
import { getSystemSettings } from "@/lib/system-settings";

// Extended user type for OAuth providers
interface OAuthUser {
  id?: string;
  email: string;
  firstName?: string | null;
  lastName?: string | null;
  name?: string | null;
  image?: string | null;
}

type GoogleProfile = {
  sub?: string;
  email?: string;
  given_name?: string;
  family_name?: string;
  name?: string;
  picture?: string;
  email_verified?: boolean;
};

type FacebookProfile = {
  id?: string;
  email?: string;
  name?: string;
  first_name?: string;
  last_name?: string;
  picture?: { data?: { url?: string } };
  verified?: boolean;
};

const {
  AUTH_SECRET,
  GOOGLE_CLIENT_ID,
  GOOGLE_CLIENT_SECRET,
  FACEBOOK_CLIENT_ID,
  FACEBOOK_CLIENT_SECRET,
  EMAIL_SERVER_HOST,
  EMAIL_SERVER_PORT,
  EMAIL_SERVER_USER,
  EMAIL_SERVER_PASSWORD,
  EMAIL_FROM,
} = process.env;

const isProduction = process.env.NODE_ENV === "production";
const allowDevLogin = process.env.ALLOW_DEV_LOGIN === "true";
const enableDevLogin = !isProduction && allowDevLogin;

// Check which providers are configured
const hasGoogle = !!(GOOGLE_CLIENT_ID && GOOGLE_CLIENT_SECRET);
const hasFacebook = !!(FACEBOOK_CLIENT_ID && FACEBOOK_CLIENT_SECRET);
const hasEmail = !!(EMAIL_SERVER_HOST && EMAIL_SERVER_PORT && EMAIL_SERVER_USER && EMAIL_SERVER_PASSWORD && EMAIL_FROM);

// Only validate at runtime (not during build)
const isRuntime = typeof window !== "undefined" || process.env.NODE_ENV === "production";
if (isRuntime && !AUTH_SECRET) {
  console.error("AUTH_SECRET environment variable is required for secure session signing");
}
if (isRuntime && !hasGoogle && !hasFacebook && !hasEmail) {
  console.error("At least one auth provider must be configured (Google, Facebook, or Email)");
}

// Build providers array based on what's configured
const providers = [];

if (hasGoogle && GOOGLE_CLIENT_ID && GOOGLE_CLIENT_SECRET) {
  providers.push(
    GoogleProvider({
      clientId: GOOGLE_CLIENT_ID,
      clientSecret: GOOGLE_CLIENT_SECRET,
      authorization: {
        params: {
          prompt: "select_account",  // Force account selection to prevent auto-sign-in
          access_type: "offline",
          response_type: "code"
        }
      },
      profile(profile) {
        const googleProfile = profile as GoogleProfile;
        return {
          id: googleProfile.sub ?? "",
          email: googleProfile.email ?? "",
          name: googleProfile.name ?? googleProfile.email ?? "",
          firstName: googleProfile.given_name ?? null,
          lastName: googleProfile.family_name ?? null,
          image: googleProfile.picture,
        };
      },
    })
  );
}

if (hasFacebook && FACEBOOK_CLIENT_ID && FACEBOOK_CLIENT_SECRET) {
  providers.push(
    FacebookProvider({
      clientId: FACEBOOK_CLIENT_ID,
      clientSecret: FACEBOOK_CLIENT_SECRET,
      profile(profile) {
        const fbProfile = profile as FacebookProfile;
        return {
          id: fbProfile.id ?? "",
          email: fbProfile.email ?? "",
          name: fbProfile.name ?? fbProfile.email ?? "",
          firstName: fbProfile.first_name ?? null,
          lastName: fbProfile.last_name ?? null,
          image: fbProfile.picture?.data?.url,
        };
      },
    })
  );
}

// Email/Password authentication (replaces EmailProvider magic links)
providers.push(
  CredentialsProvider({
    id: "credentials",
    name: "Email and Password",
    credentials: {
      email: { label: "Email", type: "email", placeholder: "your@email.com" },
      password: { label: "Password", type: "password" },
    },
    async authorize(credentials, req) {
      if (!credentials?.email || !credentials?.password) {
        console.log('[Credentials] Missing email or password');
        return null;
      }

      try {
        const rateLimit = await checkRateLimit(getRequestIp(req?.headers ?? null), 'auth:login');
        if (!rateLimit.success) {
          console.warn('[Credentials] Rate limit exceeded for login attempt');
          return null;
        }

        // Look up user by email
        const user = await dynamoDBUsers.getByEmail(credentials.email);

        if (!user) {
          console.log('[Credentials] User not found:', maskEmail(credentials.email));
          return null;
        }

        if (!user.passwordHash) {
          console.log('[Credentials] User exists but has no password (OAuth user):', maskEmail(credentials.email));
          return null;
        }

        // Verify password
        const isValid = await compare(credentials.password, user.passwordHash);

        if (!isValid) {
          console.log('[Credentials] Invalid password for:', maskEmail(credentials.email));
          return null;
        }

        console.log('[Credentials] ✓ Successful login:', maskEmail(credentials.email));

        // Return user object (signIn callback will handle DynamoDB sync)
        return {
          id: user.id,
          email: user.email,
          name: `${user.firstName || ''} ${user.lastName || ''}`.trim() || user.email,
          firstName: user.firstName,
          lastName: user.lastName,
        };
      } catch (error) {
        console.error('[Credentials] Error during authorization:', error);
        return null;
      }
    },
  })
);

// Development-only credentials provider for local testing
if (enableDevLogin) {
  providers.push(
    CredentialsProvider({
      id: "dev-credentials",
      name: "Dev Login",
      credentials: {
        email: { label: "Email", type: "email", placeholder: "test@example.com" },
      },
      async authorize(credentials) {
        if (!credentials?.email) {
          return null;
        }

        const email = credentials.email;
        const firstName = "Test";
        const lastName = "User";
        const fixedDevUserId = process.env.DEV_LOGIN_USER_ID || "893f3213-a410-4250-8c8e-ed86dcc3a4da";

        // Check if user already exists in DynamoDB (to keep consistent ID across logins)
        let existingUser = null;
        try {
          existingUser = await dynamoDBUsers.getByEmail(email);
          if (!existingUser) {
            console.warn(
              `[Dev Login] No existing user found for ${email}. Creating new user with fixed ID: ${fixedDevUserId}. ` +
              `If you expected an existing user, check DynamoDB GSI (EmailIndex), AWS credentials, and region.`
            );
          }
        } catch (error) {
          console.error("Failed to check existing user:", error);
        }

        // Use existing ID or fixed dev ID (prevents new UUIDs during dev)
        const userId = existingUser?.id || fixedDevUserId;

        // Create/update user in DynamoDB
        try {
          await dynamoDBUsers.upsert({
            id: userId,
            email,
            firstName: existingUser?.firstName || firstName,
            lastName: existingUser?.lastName || lastName,
            emailVerified: existingUser?.emailVerified || new Date().toISOString(),
            isBeta: existingUser?.isBeta,
            isDisabled: existingUser?.isDisabled,
            disabledAt: existingUser?.disabledAt ?? null,
            disabledBy: existingUser?.disabledBy ?? null,
            disabledReason: existingUser?.disabledReason ?? null,
          });
        } catch (error) {
          console.error("Failed to create/update dev user in DynamoDB:", error);
        }

        return {
          id: userId,
          email,
          name: `${existingUser?.firstName || firstName} ${existingUser?.lastName || lastName}`,
          firstName: existingUser?.firstName || firstName,
          lastName: existingUser?.lastName || lastName,
        };
      },
    })
  );
}

export const authOptions: NextAuthOptions = {
  // NOTE: We don't use PrismaAdapter - DynamoDB is our single source of truth
  // The signIn callback below handles user lookup/creation in DynamoDB
  providers,
  secret: AUTH_SECRET,
  session: {
    strategy: "jwt",
    maxAge: 30 * 24 * 60 * 60, // 30 days
    updateAge: 5 * 60, // Refresh token every 5 minutes of activity (ensures subscription updates are reflected quickly)
  },
  cookies: {
    sessionToken: {
      name: isProduction ? "__Secure-next-auth.session-token" : "next-auth.session-token",
      options: {
        httpOnly: true,
        sameSite: "lax",
        path: "/",
        secure: isProduction,
        maxAge: 30 * 24 * 60 * 60, // Must match session.maxAge - fixes incognito mode issues
        domain: isProduction
          ? ".kinexfit.com"  // Allows kinexfit.com and future subdomains
          : undefined,  // localhost doesn't need domain
      },
    },
    csrfToken: {
      // Note: Cannot use __Host- prefix when using domain attribute (cookies don't match on sign-out)
      name: isProduction ? "__Secure-next-auth.csrf-token" : "next-auth.csrf-token",
      options: {
        httpOnly: true,
        sameSite: "lax",
        path: "/",
        secure: isProduction,
        domain: isProduction
          ? ".kinexfit.com"  // Must match session token domain
          : undefined,
      },
    },
    callbackUrl: {
      name: isProduction ? "__Secure-next-auth.callback-url" : "next-auth.callback-url",
      options: {
        sameSite: "lax",
        path: "/",
        secure: isProduction,
        domain: isProduction
          ? ".kinexfit.com"
          : undefined,
      },
    },
  },
  pages: { signIn: "/auth/login" },
  debug: process.env.AUTH_DEBUG === "true", // Only enable debug logs when AUTH_DEBUG=true
  callbacks: {
    /**
     * signIn callback - runs BEFORE jwt callback
     * This is where we prevent duplicate user creation by checking DynamoDB first
     */
    async signIn({ user, account, profile }) {
      try {
        // Skip for credentials provider (dev login handles its own logic)
        if (account?.provider === 'dev-credentials' || account?.provider === 'credentials') {
          return true;
        }

        if (!user.email) {
          console.error('[Auth:SignIn] No email provided - denying sign-in');
          return false;
        }

        const provider = account?.provider;
        const providerEmailVerified =
          provider === "google"
            ? (profile as GoogleProfile | undefined)?.email_verified
            : provider === "facebook"
              ? (profile as FacebookProfile | undefined)?.verified
              : undefined;

        if (providerEmailVerified === false) {
          console.warn(`[Auth:SignIn] Provider email not verified for ${provider} - denying sign-in`);
          return false;
        }

        const emailVerifiedAt = providerEmailVerified ? new Date().toISOString() : null;

        // Check if user already exists in DynamoDB by email
        // CRITICAL: This uses the email-index GSI which may have eventual consistency
        const existingUser = await dynamoDBUsers.getByEmail(user.email);

        if (existingUser) {
          // User exists! Use their existing ID
          user.id = existingUser.id;
          const normalizedTier = normalizeSubscriptionTier(existingUser.subscriptionTier);
          console.log(`[Auth:SignIn] ✓ Existing user found for ${maskEmail(user.email)} - ID: ${existingUser.id} (provider: ${account?.provider})`);
          console.log(`[Auth:SignIn] User created at: ${existingUser.createdAt}, last updated: ${existingUser.updatedAt}`);

          // Update with latest profile info from OAuth provider
          // CRITICAL: Preserve subscription data to prevent wiping out paid tier!
          const oauthUser = user as OAuthUser;
          await dynamoDBUsers.upsert({
            id: existingUser.id,
            email: user.email,
            firstName: oauthUser.firstName || existingUser.firstName || null,
            lastName: oauthUser.lastName || existingUser.lastName || null,
            emailVerified: existingUser.emailVerified || emailVerifiedAt || null,
            // Preserve existing subscription data
            subscriptionTier: normalizedTier,
            subscriptionStatus: existingUser.subscriptionStatus,
            subscriptionStartDate: existingUser.subscriptionStartDate,
            subscriptionEndDate: existingUser.subscriptionEndDate,
            trialEndsAt: existingUser.trialEndsAt,
            stripeCustomerId: existingUser.stripeCustomerId,
            stripeSubscriptionId: existingUser.stripeSubscriptionId,
            // Preserve usage tracking
            ocrQuotaUsed: existingUser.ocrQuotaUsed,
            ocrQuotaLimit: existingUser.ocrQuotaLimit,
            ocrQuotaResetDate: existingUser.ocrQuotaResetDate,
            workoutsSaved: existingUser.workoutsSaved,
            aiRequestsUsed: existingUser.aiRequestsUsed,
            aiRequestsLimit: existingUser.aiRequestsLimit,
            lastAiRequestReset: existingUser.lastAiRequestReset,
            trainingProfile: existingUser.trainingProfile,
            // Preserve onboarding status
            onboardingCompleted: existingUser.onboardingCompleted,
            onboardingSkipped: existingUser.onboardingSkipped,
            onboardingCompletedAt: existingUser.onboardingCompletedAt,
            // Preserve beta/disabled flags
            isBeta: existingUser.isBeta,
            isDisabled: existingUser.isDisabled,
            disabledAt: existingUser.disabledAt ?? null,
            disabledBy: existingUser.disabledBy ?? null,
            disabledReason: existingUser.disabledReason ?? null,
          });
        } else {
          // New user - create with new UUID
          const newUserId = randomUUID();
          user.id = newUserId;

          console.log(`[Auth:SignIn] ✓ Creating NEW user for ${maskEmail(user.email)} - ID: ${newUserId} (provider: ${account?.provider})`);
          console.log(`[Auth:SignIn] WARNING: About to create new user. If this email already exists, this indicates a race condition or GSI inconsistency!`);

          // Create user in DynamoDB with race condition protection
          // ConditionExpression ensures we don't overwrite if another request created this user concurrently
          const oauthUser = user as OAuthUser;
          try {
            await dynamoDBUsers.upsert({
              id: newUserId,
              email: user.email,
              firstName: oauthUser.firstName || null,
              lastName: oauthUser.lastName || null,
              emailVerified: emailVerifiedAt || null,
              onboardingCompleted: false,
            }, {
              ConditionExpression: 'attribute_not_exists(#id)',
              ExpressionAttributeNames: { '#id': 'id' },
            });
          } catch (error: any) {
            // If condition fails, another concurrent request created the user - fetch and use it
            if (error.name === 'ConditionalCheckFailedException') {
              console.log(`[Auth:SignIn] ⚠️  Concurrent user creation detected for ${maskEmail(user.email)}, fetching existing user`);
              const concurrentUser = await dynamoDBUsers.getByEmail(user.email);
              if (concurrentUser) {
                user.id = concurrentUser.id;
                console.log(`[Auth:SignIn] ✓ Using concurrent user ID: ${concurrentUser.id}`);
              } else {
                throw new Error('Race condition: User creation failed but cannot find existing user');
              }
            } else {
              throw error; // Re-throw other errors
            }
          }

          // DUPLICATE DETECTION: Check if multiple users exist with this email after creation
          try {
            const allUsersWithEmail = await dynamoDBUsers.getAllByEmail(user.email);
            if (allUsersWithEmail && allUsersWithEmail.length > 1) {
              console.error(`[Auth:SignIn] 🚨 DUPLICATE USER DETECTED! Email ${maskEmail(user.email)} has ${allUsersWithEmail.length} users:`);
              allUsersWithEmail.forEach((u, i) => {
                console.error(`  ${i + 1}. ID: ${u.id}, created: ${u.createdAt}`);
              });
              console.error(`[Auth:SignIn] Using user ID: ${user.id}. Other duplicate(s) should be manually deleted!`);
            }
          } catch (error) {
            console.error('[Auth:SignIn] Failed to check for duplicates:', error);
          }

          // Send signup alert email (async, non-blocking)
          // Skip dev login signups
          if (account?.provider !== 'dev-credentials') {
            sendSignupAlert({
              email: user.email,
              firstName: oauthUser.firstName || null,
              lastName: oauthUser.lastName || null,
              id: newUserId,
              provider: account?.provider || 'unknown',
              createdAt: new Date().toISOString()
            }).catch(error => {
              console.error('[Auth:SignIn] Failed to send signup alert:', error);
              // Don't throw - email failure shouldn't block signin
            });
          }
        }

        return true;
      } catch (error) {
        console.error('[Auth:SignIn] Error during sign-in:', error);
        // Allow sign-in to proceed even if DynamoDB fails (will retry in JWT callback)
        return true;
      }
    },

    async jwt({ token, account, profile, user, trigger }) {
      const isInitialSignIn = !!user;
      const provider = account?.provider || (token.provider as string | undefined) || 'unknown';

      if (isInitialSignIn) {
        console.log(`[Auth:JWT] Initial sign-in via ${provider} for user ${user.id}`);
      }

      // Handle profile update trigger from updateSession() call
      if (trigger === 'update') {
        console.log('[Auth:JWT] Profile update triggered - forcing JWT refresh from DynamoDB');
        // Force a fresh read from DynamoDB below (will happen in the existing code at line ~603)
      }

      // Persist provider info for auditing
      if (account?.provider) {
        token.provider = account.provider;
      }

      // Track email changes for debugging
      const previousEmail = token.email as string | undefined;

      // On initial sign-in, user will be defined (from signIn callback above). Capture base identity.
      if (user) {
        token.id = user.id;
        // Only update email if we have a real value from the provider (not null/empty)
        if (user.email && user.email.trim()) {
          token.email = user.email;
          if (previousEmail && previousEmail !== user.email) {
            console.warn(`[Auth:JWT] Email changed for user ${user.id}: ${maskEmail(previousEmail)} → ${maskEmail(user.email)}`);
          }
        }
        token.firstName = (user as { firstName?: string | null }).firstName ?? token.firstName ?? null;
        token.lastName = (user as { lastName?: string | null }).lastName ?? token.lastName ?? null;
      }

      // Supplement names from OAuth profile if available
      if (account && profile) {
        if (account.provider === "google") {
          const googleProfile = profile as GoogleProfile;
          token.firstName = googleProfile.given_name ?? token.firstName ?? null;
          token.lastName = googleProfile.family_name ?? token.lastName ?? null;
          // Only update email if Google provides a real value (never overwrite with placeholder)
          if (googleProfile.email && googleProfile.email.trim()) {
            if (previousEmail && previousEmail !== googleProfile.email) {
              console.warn(`[Auth:JWT] Google email differs from token: ${maskEmail(previousEmail)} → ${maskEmail(googleProfile.email)}`);
            }
            token.email = googleProfile.email;
          } else if (googleProfile.email === null || googleProfile.email === "") {
            console.warn(`[Auth:JWT] Google returned empty email - keeping existing: ${maskEmail(previousEmail)}`);
          }
          token.name = googleProfile.name ?? token.name;
          token.image = googleProfile.picture ?? token.image;
        } else if (account.provider === "facebook") {
          const fbProfile = profile as FacebookProfile;
          token.firstName = fbProfile.first_name ?? token.firstName ?? null;
          token.lastName = fbProfile.last_name ?? token.lastName ?? null;
          // Only update email if Facebook provides a real value (never overwrite with placeholder)
          if (fbProfile.email && fbProfile.email.trim()) {
            if (previousEmail && previousEmail !== fbProfile.email) {
              console.warn(`[Auth:JWT] Facebook email differs from token: ${maskEmail(previousEmail)} → ${maskEmail(fbProfile.email)}`);
            }
            token.email = fbProfile.email;
          } else if (fbProfile.email === null || fbProfile.email === "") {
            console.warn(`[Auth:JWT] Facebook returned empty email - keeping existing: ${maskEmail(previousEmail)}`);
          }
          token.name = fbProfile.name ?? token.name;
          token.image = fbProfile.picture?.data?.url ?? token.image;
        }
      }

      // Backup sync to DynamoDB (primary sync happens in signIn callback)
      // This ensures user exists even if signIn callback failed
      // CRITICAL: Must preserve subscription data to prevent wiping out paid tiers
      if (token.id && token.email) {
        try {
          // Fetch existing user first to preserve subscription data
          // PERFORMANCE NOTE: Use strong consistency to ensure we get latest subscription status
          const existingUserForJWT = await dynamoDBUsers.get(token.id as string, true).catch(() => null);

          if (existingUserForJWT) {
            // User exists - preserve ALL subscription and usage data
            const normalizedTier = normalizeSubscriptionTier(existingUserForJWT.subscriptionTier);
            await dynamoDBUsers.upsert({
              id: token.id as string,
              email: token.email as string,
              // Preserve DB name fields to avoid overwriting user edits with stale token data
              firstName: existingUserForJWT.firstName ?? null,
              lastName: existingUserForJWT.lastName ?? null,
              emailVerified: existingUserForJWT.emailVerified ?? null,
              // Preserve existing subscription data
              subscriptionTier: normalizedTier,
              subscriptionStatus: existingUserForJWT.subscriptionStatus,
              subscriptionStartDate: existingUserForJWT.subscriptionStartDate,
              subscriptionEndDate: existingUserForJWT.subscriptionEndDate,
              trialEndsAt: existingUserForJWT.trialEndsAt,
              stripeCustomerId: existingUserForJWT.stripeCustomerId,
              stripeSubscriptionId: existingUserForJWT.stripeSubscriptionId,
              // Preserve usage tracking
              ocrQuotaUsed: existingUserForJWT.ocrQuotaUsed,
              ocrQuotaLimit: existingUserForJWT.ocrQuotaLimit,
              ocrQuotaResetDate: existingUserForJWT.ocrQuotaResetDate,
              workoutsSaved: existingUserForJWT.workoutsSaved,
              aiRequestsUsed: existingUserForJWT.aiRequestsUsed,
              aiRequestsLimit: existingUserForJWT.aiRequestsLimit,
              lastAiRequestReset: existingUserForJWT.lastAiRequestReset,
              trainingProfile: existingUserForJWT.trainingProfile,
              // Preserve onboarding status
              onboardingCompleted: existingUserForJWT.onboardingCompleted,
              onboardingSkipped: existingUserForJWT.onboardingSkipped,
              onboardingCompletedAt: existingUserForJWT.onboardingCompletedAt,
              // Preserve beta/disabled flags
              isBeta: existingUserForJWT.isBeta,
              isDisabled: existingUserForJWT.isDisabled,
              disabledAt: existingUserForJWT.disabledAt ?? null,
              disabledBy: existingUserForJWT.disabledBy ?? null,
              disabledReason: existingUserForJWT.disabledReason ?? null,
            });
          } else {
            // User doesn't exist yet - create with minimal data
            // This should rarely happen since signIn callback should have created the user
            await dynamoDBUsers.upsert({
              id: token.id as string,
              email: token.email as string,
              firstName: (token.firstName as string | null) ?? null,
              lastName: (token.lastName as string | null) ?? null,
            });
          }

          if (isInitialSignIn) {
            console.log(`[Auth:JWT] ✓ User ${token.id} synced to DynamoDB (${maskEmail(token.email as string)})`);
          }
        } catch (error) {
          console.error(`[Auth:JWT] ✗ Failed to sync user ${token.id} to DynamoDB:`, error);
          // Don't fail auth if DynamoDB sync fails
        }
      }

      // Fetch subscription tier and profile data from DynamoDB on every token refresh
      if (token.id) {
        try {
          // PERFORMANCE NOTE: Use strong consistency to ensure we get latest subscription
          // status immediately after webhook updates (e.g., subscription cancellation)
          const dbUser = await dynamoDBUsers.get(token.id as string, true);
          if (dbUser) {
            if (dbUser.isDisabled) {
              throw new Error("Account disabled by administrator");
            }

            token.subscriptionTier = normalizeSubscriptionTier(dbUser.subscriptionTier);
            token.subscriptionStatus = dbUser.subscriptionStatus;
            token.ocrQuotaUsed = dbUser.ocrQuotaUsed;
            token.ocrQuotaLimit = dbUser.ocrQuotaLimit;
            token.aiRequestsUsed = dbUser.aiRequestsUsed ?? 0;
            token.workoutsSaved = dbUser.workoutsSaved ?? 0;
            token.workoutsWeeklyUsed = dbUser.workoutsWeeklyUsed ?? 0;
            token.onboardingCompleted = dbUser.onboardingCompleted ?? false;
            token.onboardingSkipped = dbUser.onboardingSkipped ?? false;
            token.isBeta = dbUser.isBeta ?? false;
            // Refresh profile name fields to reflect any profile updates
            token.firstName = dbUser.firstName ?? null;
            token.lastName = dbUser.lastName ?? null;

            if (process.env.NODE_ENV === "development") {
              console.log(`[Auth:JWT] User ${token.id} tier: ${dbUser.subscriptionTier}/${dbUser.subscriptionStatus}`);
            }
          } else {
            console.warn(
              `[Auth:JWT] Token refresh: user ${token.id} (${token.email}) not found in DynamoDB. ` +
              `This may indicate a sync issue or deleted user. Continuing with cached token data.`
            );
          }

          const systemSettings = await getSystemSettings();
          token.globalBetaMode = systemSettings.globalBetaMode;
        } catch (error) {
          if (error instanceof Error && error.message === "Account disabled by administrator") {
            throw error;
          }
          console.error(`[Auth:JWT] Failed to fetch user ${token.id} from DynamoDB:`, error);
          // Continue with existing token data
        }
      }

      // Monitor JWT cookie size (browser limit is 4096 bytes)
      const tokenSize = JSON.stringify(token).length;
      if (tokenSize > 3500) {  // Warning threshold (leave buffer for encoding overhead)
        console.warn(`[Auth] JWT token size: ${tokenSize} bytes - approaching 4096 limit`);
      }
      // Log size in development for monitoring
      if (process.env.NODE_ENV === "development") {
        console.log(`[Auth] JWT token size: ${tokenSize} bytes`);
      }

      return token;
    },
    async session({ session, token }) {
      return {
        ...session,
        user: {
          ...session.user,
          id: typeof token.id === "string" ? token.id : "",
          email: (token.email as string | undefined) ?? session.user?.email ?? "",
          firstName: (token.firstName as string | undefined) ?? null,
          lastName: (token.lastName as string | undefined) ?? null,
          subscriptionTier: normalizeSubscriptionTier(
            typeof token.subscriptionTier === "string" ? token.subscriptionTier : undefined
          ),
          subscriptionStatus: (token.subscriptionStatus as string | undefined) ?? "active",
          ocrQuotaUsed: (token.ocrQuotaUsed as number | undefined) ?? 0,
          ocrQuotaLimit: (token.ocrQuotaLimit as number | undefined) ?? 2,
          aiRequestsUsed: (token.aiRequestsUsed as number | undefined) ?? 0,
          workoutsSaved: (token.workoutsSaved as number | undefined) ?? 0,
          workoutsWeeklyUsed: (token.workoutsWeeklyUsed as number | undefined) ?? 0,
          provider: (token.provider as string | undefined) ?? undefined,
          onboardingCompleted: (token.onboardingCompleted as boolean | undefined) ?? false,
          onboardingSkipped: (token.onboardingSkipped as boolean | undefined) ?? false,
          isBeta: (token.isBeta as boolean | undefined) ?? false,
          globalBetaMode:
            typeof token.globalBetaMode === "boolean"
              ? (token.globalBetaMode as boolean)
              : process.env.NODE_ENV === "production",
        },
      };
    },
  },
};
