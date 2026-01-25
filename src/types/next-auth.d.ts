import type { DefaultSession } from "next-auth";
import type { DefaultJWT } from "next-auth/jwt";

declare module "next-auth" {
  interface Session {
    user: {
      id: string;
      firstName?: string | null;
      lastName?: string | null;
      subscriptionTier?: string;
      subscriptionStatus?: string;
      ocrQuotaUsed?: number;
      ocrQuotaLimit?: number;
      workoutsSaved?: number;
      workoutsWeeklyUsed?: number;
      aiRequestsUsed?: number;
      onboardingCompleted?: boolean;
      onboardingSkipped?: boolean;
      isBeta?: boolean;
      globalBetaMode?: boolean;
      provider?: string;
    } & DefaultSession["user"];
  }
}

declare module "next-auth/jwt" {
  interface JWT extends DefaultJWT {
    id?: string;
    firstName?: string | null;
    lastName?: string | null;
    subscriptionTier?: string;
    subscriptionStatus?: string;
    ocrQuotaUsed?: number;
    ocrQuotaLimit?: number;
    workoutsSaved?: number;
    workoutsWeeklyUsed?: number;
    aiRequestsUsed?: number;
    onboardingCompleted?: boolean;
    onboardingSkipped?: boolean;
    isBeta?: boolean;
    globalBetaMode?: boolean;
    provider?: string;
  }
}
