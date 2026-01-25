"use client"

import { signIn as nextAuthSignIn, signOut as nextAuthSignOut, useSession } from "next-auth/react";
import { normalizeSubscriptionTier } from "@/lib/stripe";

// It's a good practice to define the shape of the user object from your session
interface SessionUser {
  id?: string;
  email?: string;
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
}

interface User {
  id: string;
  email: string;
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
}

type AuthProvider = "google" | "facebook";

interface AuthState {
  isAuthenticated: boolean;
  isLoading: boolean; // Add isLoading state
  user: User | null;
  login: (provider?: AuthProvider) => Promise<void>;
  loginWithEmail: (email: string) => Promise<void>;
  loginWithCredentials: (email: string, password: string) => Promise<void>;
  signup: (email: string, password: string, firstName?: string, lastName?: string) => Promise<{ success: boolean; error?: string; message?: string }>;
  devLogin: (email: string) => Promise<void>; // Dev-only login
  logout: () => Promise<void>;
}

export const useAuthStore = (): AuthState => {
  const { data: session, status } = useSession();

  // Cast the session user once to the defined type for safer access
  const sessionUser = session?.user as SessionUser | null;

  const user: User | null = sessionUser?.email && sessionUser?.id
    ? {
        id: sessionUser.id,
        email: sessionUser.email,
        firstName: sessionUser.firstName ?? null,
        lastName: sessionUser.lastName ?? null,
        subscriptionTier: normalizeSubscriptionTier(sessionUser.subscriptionTier),
        subscriptionStatus: sessionUser.subscriptionStatus ?? "active",
        ocrQuotaUsed: sessionUser.ocrQuotaUsed ?? 0,
        ocrQuotaLimit: sessionUser.ocrQuotaLimit ?? 2,
        workoutsSaved: sessionUser.workoutsSaved ?? 0,
        workoutsWeeklyUsed: sessionUser.workoutsWeeklyUsed ?? 0,
        aiRequestsUsed: sessionUser.aiRequestsUsed ?? 0,
        onboardingCompleted: sessionUser.onboardingCompleted ?? false,
        onboardingSkipped: sessionUser.onboardingSkipped ?? false,
        isBeta: sessionUser.isBeta ?? false,
        globalBetaMode: sessionUser.globalBetaMode ?? false,
      }
    : null;

  return {
    isAuthenticated: status === "authenticated",
    isLoading: status === "loading", // Expose the loading state
    user,
    login: async (provider: AuthProvider = "google") => {
      await nextAuthSignIn(provider, {
        callbackUrl: "/",
        redirect: true
      });
    },
    loginWithEmail: async (email: string) => {
      if (!email) {
        throw new Error("Email is required for magic link sign-in.");
      }
      await nextAuthSignIn("email", {
        email,
        callbackUrl: "/",
        redirect: true
      });
    },
    loginWithCredentials: async (email: string, password: string) => {
      if (!email || !password) {
        throw new Error("Email and password are required.");
      }
      const result = await nextAuthSignIn("credentials", {
        email,
        password,
        callbackUrl: "/",
        redirect: false,
      });

      if (result?.error) {
        throw new Error(result.error === "CredentialsSignin" ? "Invalid email or password" : result.error);
      }

      if (result?.ok) {
        window.location.href = result.url || "/";
      }
    },
    signup: async (email: string, password: string, firstName?: string, lastName?: string) => {
      try {
        const response = await fetch("/api/auth/signup", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ email, password, firstName, lastName }),
        });

        const data = await response.json();

        if (!response.ok) {
          return { success: false, error: data.error || "Signup failed" };
        }

        return { success: true, message: data.message };
      } catch (error) {
        console.error("Signup error:", error);
        return { success: false, error: "Network error. Please try again." };
      }
    },
    devLogin: async (email: string) => {
      if (!email) {
        throw new Error("Email is required for dev login.");
      }
      await nextAuthSignIn("dev-credentials", {
        email,
        callbackUrl: "/",
        redirect: true
      });
    },
    logout: async () => {
      await nextAuthSignOut({ callbackUrl: "/" });
    },
  };
};
