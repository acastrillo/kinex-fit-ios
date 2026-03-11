# App Store Submission Checklist - Kinex Fit iOS

**Status:** In progress  
**Last Updated:** 2026-03-07

## Repo Changes

- [x] Remove any iOS-exposed Stripe web checkout / external digital purchase path
- [x] Keep web subscription management limited to existing Stripe subscribers
- [x] Add `com.apple.developer.healthkit` to release entitlements
- [x] Add `com.apple.developer.healthkit` to debug entitlements
- [x] Add share extension `PrivacyInfo.xcprivacy`
- [x] Declare extension UserDefaults access reason `CA92.1`
- [x] Remove `"API access (coming soon)"` from the paywall
- [x] Apply iOS file protection to local SQLite database files
- [x] Regenerate Xcode project from `ios/project.yml`

## Build And Test

- [x] `xcodegen generate`
- [x] Focused simulator tests for changed areas
- [x] Release iOS build with `CODE_SIGNING_ALLOWED=NO`
- [x] Full simulator suite green
- [x] Unsigned release archive with `CODE_SIGNING_ALLOWED=NO`
- [ ] Signed archive from Xcode with production signing

## Manual Device Verification

- [ ] Confirm HealthKit capability is enabled on the Apple Developer App ID
- [ ] Test HealthKit permission prompt on physical iPhone
- [ ] Save a workout to HealthKit on device
- [ ] Save a body metric to HealthKit on device
- [ ] Verify paywall shows retry/error state only when StoreKit products fail to load
- [ ] Verify no web purchase CTA appears anywhere in iOS
- [ ] Verify Stripe-sourced subscriber only sees "Manage Web Subscription"
- [ ] Verify share extension import works for supported share sources on device
- [ ] Confirm local database files are created and protected on device

## Commerce And Review Readiness

- [ ] Sandbox/TestFlight purchase validation passes end to end
- [ ] Restore purchases flow verified
- [ ] Export compliance answers completed in App Store Connect
- [ ] Review notes updated to mention web subscription management is for existing web subscribers only
- [ ] Privacy Policy URL confirmed
- [ ] Terms of Service URL confirmed

## Deferred Follow-Up

- [ ] StoreKit server validation migration to `Transaction.jwsRepresentation`
- [ ] SQLCipher / encrypted-at-rest database migration
