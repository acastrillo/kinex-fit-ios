# App Store Review Remediation Report

**App:** Kinex Fit  
**Bundle ID:** `com.kinex.fit`  
**Date:** 2026-03-07  
**Scope:** App Store readiness pass after Stripe web checkout removal

## Executive Summary

This pass implemented the agreed App Store readiness fixes in the iOS repo. The external Stripe purchase path is no longer exposed in the app, HealthKit entitlements were added, the share extension now ships its own privacy manifest, the paywall no longer advertises a coming-soon API feature, and the local SQLite database now uses iOS file protection instead of remaining completely unprotected at rest.

The remaining work is mostly outside this repo-level change set: enable HealthKit on the Apple Developer App ID for production signing, complete real-device verification, rerun sandbox purchase validation, and plan the later StoreKit JWS migration.

## Implemented In This Pass

| Area | Status | Notes |
|---|---|---|
| External payment bypass via Stripe web checkout | Resolved | iOS paywall no longer exposes `/api/stripe/checkout`; only the web-subscriber management portal remains |
| HealthKit entitlement mismatch | Resolved in repo | Added `com.apple.developer.healthkit` to both app entitlements files |
| Share extension privacy manifest | Resolved | Added `ios/KinexFitShareExtension/PrivacyInfo.xcprivacy` with `NSPrivacyAccessedAPICategoryUserDefaults` / `CA92.1` |
| Paywall "API access (coming soon)" copy | Resolved | Removed from Elite tier feature list |
| Local database storage hardening | Mitigated | Added `FileProtectionType.completeUntilFirstUserAuthentication` to the SQLite file and sidecars; SQLCipher intentionally deferred |
| Xcode project source of truth | Updated | Regenerated from `ios/project.yml` with XcodeGen so the new extension manifest and tests are included |

## Files Changed

- `ios/Kinex Fit.entitlements`
- `ios/Kinex Fit.Debug.entitlements`
- `ios/KinexFit/Views/Store/PaywallView.swift`
- `ios/KinexFit/Persistence/AppDatabase.swift`
- `ios/KinexFit/Services/OnboardingAnalytics.swift`
- `ios/KinexFit/Services/Parsing/ExerciseLibraryMatcher.swift`
- `ios/KinexFit/Models/User.swift`
- `ios/KinexFit/Models/AuthModels.swift`
- `ios/KinexFitShareExtension/PrivacyInfo.xcprivacy`
- `ios/KinexFitTests/AppDatabaseTests.swift`
- `ios/KinexFitTests/AuthSmokeTests.swift`
- `ios/project.yml`
- `ios/Kinex Fit.xcodeproj/project.pbxproj`

## Validation

| Check | Result | Details |
|---|---|---|
| `xcodegen generate` | Pass | Regenerated `ios/Kinex Fit.xcodeproj` successfully |
| Focused simulator tests | Pass | `AppDatabaseTests` and `ExerciseLibraryMatcherTests` both passed |
| Release device build | Pass | `xcodebuild -project 'ios/Kinex Fit.xcodeproj' -scheme 'Kinex Fit' -configuration Release -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO` |
| Full simulator suite | Pass | `xcodebuild -project 'ios/Kinex Fit.xcodeproj' -scheme 'Kinex Fit' -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' test` |
| Release archive | Pass | `xcodebuild -project 'ios/Kinex Fit.xcodeproj' -scheme 'Kinex Fit' -configuration Release -destination 'generic/platform=iOS' archive -archivePath /tmp/KinexFit-AppStore-Readiness-20260307-2251.xcarchive CODE_SIGNING_ALLOWED=NO` |

## Remaining Manual Checks Before Submission

1. Enable HealthKit for the production App ID in Apple Developer and confirm archive signing picks up the entitlement.
2. Verify on a physical iPhone that HealthKit permissions, workout save, and body-metric save all work without entitlement/runtime issues.
3. Verify the share extension import flow on device for image/video/URL share sources.
4. Verify the paywall never shows any web purchase or upgrade path when StoreKit products fail to load.
5. Verify a Stripe-sourced subscriber only sees management UI and that `/api/stripe/portal` remains management-only.
6. Rerun sandbox/TestFlight purchase validation. If receipt-based validation misbehaves, pull the JWS migration into the active submission scope.

## Deferred Follow-Up

These were intentionally not implemented in this pass:

- Migrate `PurchaseValidator` and the backend subscription validation route from legacy `receiptData` to StoreKit 2 signed transaction data (`Transaction.jwsRepresentation`).
- Move database encryption from file protection to full SQLCipher-backed encrypted storage.

## Submission Readiness Assessment

Repo-level App Store blockers covered by this plan are addressed and local validation is green. Submission should still wait on the manual/device checks above, HealthKit capability confirmation in Apple Developer, and end-to-end sandbox/TestFlight purchase verification.
