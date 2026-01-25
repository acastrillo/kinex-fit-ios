import React from "react"
import { useAuthStore } from "@/store"
import {
  SUBSCRIPTION_TIERS,
  hasFeatureAccess,
  getQuotaLimit,
  normalizeSubscriptionTier,
  type SubscriptionTier,
  type LimitKey,
} from "./subscription-tiers"

export interface FeatureGateResult {
  allowed: boolean
  reason?: string
  tier?: SubscriptionTier
}

/**
 * Hook to check if user has access to a specific feature
 */
export function useFeatureAccess(feature: LimitKey): FeatureGateResult {
  const { user } = useAuthStore()
  const tier = normalizeSubscriptionTier(user?.subscriptionTier)

  const allowed = hasFeatureAccess(tier, feature)

  if (!allowed) {
    return {
      allowed: false,
      reason: `This feature requires ${getMinimumTierForFeature(feature)} or higher`,
      tier,
    }
  }

  return { allowed: true, tier }
}

/**
 * Hook to check if user has quota remaining
 */
export function useQuotaCheck(quotaType: 'ocrQuotaWeekly' | 'workoutsWeekly' | 'workoutsMax' | 'aiRequestsMonthly'): FeatureGateResult {
  const { user } = useAuthStore()
  const tier = normalizeSubscriptionTier(user?.subscriptionTier)

  const limit = getQuotaLimit(tier, quotaType)

  // Unlimited quota
  if (limit === null) {
    return { allowed: true, tier }
  }

  // Check current usage
  const currentUsage = quotaType === 'ocrQuotaWeekly'
    ? user?.ocrQuotaUsed || 0
    : quotaType === 'aiRequestsMonthly'
    ? user?.aiRequestsUsed || 0
    : quotaType === 'workoutsWeekly'
    ? user?.workoutsWeeklyUsed || 0
    : user?.workoutsSaved || 0

  if (currentUsage >= limit) {
    return {
      allowed: false,
      reason: `You've reached your ${
        quotaType === 'ocrQuotaWeekly' ? 'OCR' :
        quotaType === 'aiRequestsMonthly' ? 'AI request' :
        'workout'
      } limit. Upgrade to continue.`,
      tier,
    }
  }

  return { allowed: true, tier }
}

/**
 * Get the minimum tier required for a feature
 */
function getMinimumTierForFeature(feature: LimitKey): string {
  const tiers: SubscriptionTier[] = ['free', 'core', 'pro', 'elite']

  for (const tier of tiers) {
    if (hasFeatureAccess(tier, feature)) {
      return SUBSCRIPTION_TIERS[tier].name
    }
  }

  return 'Pro'
}

/**
 * Feature gate component props
 */
export interface FeatureGateProps {
  feature: LimitKey
  fallback?: React.ReactNode
  children: React.ReactNode
}

/**
 * Component to gate features based on subscription tier
 */
export function FeatureGate({ feature, fallback, children }: FeatureGateProps) {
  const { allowed } = useFeatureAccess(feature)

  if (!allowed) {
    return <>{fallback}</>
  }

  return <>{children}</>
}

/**
 * Get tier color for UI
 */
export function getTierColor(tier: SubscriptionTier): string {
  switch (tier) {
    case 'free':
      return 'text-text-secondary'
    case 'core':
      return 'text-secondary'
    case 'pro':
      return 'text-primary'
    case 'elite':
      return 'text-rest'
    default:
      return 'text-text-secondary'
  }
}

/**
 * Get tier badge styling
 */
export function getTierBadge(tier: SubscriptionTier): {
  label: string
  color: string
  bgColor: string
} {
  const config = SUBSCRIPTION_TIERS[tier]

  return {
    label: config.name,
    color: getTierColor(tier),
    bgColor: tier === 'free' ? 'bg-surface' :
             tier === 'core' ? 'bg-secondary/10' :
             tier === 'pro' ? 'bg-primary/10' : 'bg-rest/10',
  }
}
