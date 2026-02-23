# Phase 6 QA, TestFlight, and Submission Runbook

Final validation runbook for Kinex Fit v1 (iPhone-only), aligned to the Mar 9-13, 2026 submission window.

## Scope

- App target: `ios/KinexFit`
- Share extension target: `ios/KinexFitShareExtension`
- Backend environment: production only (test accounts)
- Submission scope: iPhone only

## Exit Criteria (Hard Gates)

- No open P0 or P1 defects.
- All 10 launch scenarios pass in a release-candidate build.
- Kill switches validated and documented for fallback.
- TestFlight smoke completed with release candidate.
- App Store metadata, links, and reviewer notes complete.

## Execution Order

1. Run static smoke checks:
   - `./scripts/phase6_smoke.sh`
2. Run optional local build check:
   - `RUN_XCODEBUILD=1 ./scripts/phase6_smoke.sh`
3. Execute manual regression scenarios in this document.
4. Upload candidate build to TestFlight.
5. Perform internal TestFlight smoke.
6. Final pre-submission review and App Store submission.

## Test Accounts and Devices

Track exact accounts and devices used for evidence and reproducibility.

- Account A (Free tier): `________________`
- Account B (Paid tier): `________________`
- Account C (Expired/invalid refresh): `________________`
- Device 1: `________________`
- Device 2: `________________`
- iOS versions covered: `________________`

## Manual Regression Matrix

### 1) Sync correctness (offline to online)

- Precondition: signed-in user with valid token.
- Steps:
  1. Enable airplane mode.
  2. Create workout.
  3. Update workout.
  4. Delete workout.
  5. Disable airplane mode.
  6. Trigger sync from workouts tab.
- Expected:
  - Queue drains to zero.
  - No permanent failed sync items.
  - Server state matches local state.
- Evidence:
  - `SyncStatusIndicator` screenshots and backend record check.

### 2) Date serialization consistency

- Steps:
  1. Create workout with known timestamp.
  2. Force offline queue.
  3. Reconnect and sync.
  4. Fetch workout from backend.
- Expected:
  - Date remains unchanged semantically across queue, request, and server response.

### 3) Auth resilience (401 + refresh)

- Steps:
  1. Use expired access token + valid refresh token.
  2. Trigger authenticated API call.
  3. Repeat with invalid refresh token.
- Expected:
  - Valid refresh path recovers and request succeeds.
  - Invalid refresh path clears session and routes to signed-out UI.

### 4) Account deletion flow

- Steps:
  1. Open Settings -> Delete Account.
  2. Type `DELETE` and confirm.
- Expected:
  - Backend deletion request succeeds.
  - Local DB and tokens are cleared.
  - Current session transitions to signed-out UI immediately.

### 5) IAP and subscription state

- Steps:
  1. Purchase tier.
  2. Restore purchases.
  3. Validate backend subscription state sync.
- Expected:
  - Tier/status update reflected in local user state and paywall state.

### 6) Paywall routing coverage

- Steps:
  1. Trigger quota-exceeded path from OCR/import.
  2. Trigger paywall from each configured entry point.
- Expected:
  - Paywall opens from each required state with no dead ends.

### 7) Push actions and routing

- Steps:
  1. Deliver local notification.
  2. Tap default action.
  3. Tap complete action.
  4. Tap snooze action.
  5. Tap view streak action.
- Expected:
  - Routing and side-effects match expected tab/action behavior.

### 8) Share extension image/video import

- Steps:
  1. Share image from Photos/Instagram to extension.
  2. Share video from Photos/Instagram to extension.
  3. Open app and process pending imports.
- Expected:
  - Media persisted to App Group storage.
  - Import appears in app.
  - Text extraction path works and can convert to workout.

### 9) Release compliance assets and links

- Steps:
  1. Validate icon set completeness.
  2. Validate launch asset reference.
  3. Open privacy/terms/support links in app.
- Expected:
  - No missing asset references.
  - All legal URLs return HTTP 200.

### 10) Submission build integrity

- Steps:
  1. Archive Release build for app and share extension.
  2. Validate no missing packages or target linkage.
- Expected:
  - Archive succeeds.
  - No unresolved imports or missing resources.

## Kill Switch Validation

Validate backend app config toggles from `/api/mobile/app-config`.

- `facebookAuthEnabled`
- `shareExtensionImportEnabled`
- `pushActionRoutingEnabled`

### Steps

1. Set one flag to `false` on backend.
2. Relaunch app and confirm behavior is disabled.
3. Set back to `true` and confirm behavior returns.
4. Record backend payload snapshot and in-app result.

## TestFlight Smoke Checklist

- Build uploaded with matching version/build metadata.
- Install from TestFlight on at least two devices.
- Complete sign-in, create workout, sync, and sign-out flow.
- Validate paywall open, restore purchases, and settings links.
- Validate account deletion path on test account.
- Attach concise App Review notes covering auth providers, IAP, and deletion path.

## Submission Package Checklist

- App Store description and keywords finalized.
- iPhone screenshot set complete and current.
- Privacy Policy URL set and live.
- Terms URL set and live.
- Support URL set and live.
- App Review notes included.

## Evidence Log Template

Use this section while executing.

- Build: `________________`
- Date: `________________`
- Tester: `________________`
- Devices: `________________`
- Passed scenarios: `________________`
- Failed scenarios: `________________`
- Open defects: `________________`
- Kill-switch validation result: `________________`
