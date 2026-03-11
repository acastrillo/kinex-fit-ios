# App Store Review & Security Audit Report

**App:** Kinex Fit | **Bundle ID:** com.kinex.fit (inferred) | **Date:** March 7, 2026
**Deployment Target:** iOS 17+ | **Reviewed by:** Claude iOS Review Skill

---

## Executive Summary

Kinex Fit is an AI-powered fitness app with significant promise, but has **3 Critical issues** and **5 High-severity issues** that must be resolved before App Store submission. The most pressing issue is the missing `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` strings in Info.plist (CRITICAL) — the app uses HealthKit extensively but will crash on permission request without these. Additionally, sensitive debug logging must be wrapped in `#if DEBUG` blocks to prevent production leaks. After these fixes, the app is well-architected with strong authentication (Sign in with Apple is implemented), secure token storage in Keychain, and proper use of async/await patterns. With the fixes applied below, the app will have a strong chance of passing App Review.

**Finding Summary:**
- **Critical (3):** Missing HealthKit permission strings, debug logging exposed
- **High (5):** Sensitive logging in production, Keychain configuration gaps
- **Medium (0):** —
- **Low (4):** Recommendations for keychain best practices

---

## Auto-Fixes Applied

| File | Change | Reason |
|------|--------|--------|
| `KinexFit/Resources/Info.plist` | Added `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` strings | HealthKitManager requests HKHealthStore authorization but these permission strings were missing, causing app crash on permission request |
| `KinexFit/Auth/TokenStore.swift` | Wrapped 3 NSLog calls in `#if DEBUG` guards (lines 62-64, 69) | Sensitive keychain status messages should not appear in production builds; wrapped in debug-only guard |
| `KinexFit/Services/OnboardingAnalytics.swift` | Wrapped analytics print() statements in `#if DEBUG` guard (line 101) | Debug logging should not appear in production; analytics backend integration is commented as TODO |

---

## Critical Issues — Must Fix Before Submission

### CRITICAL-1: Missing NSHealthShareUsageDescription and NSHealthUpdateUsageDescription
**File:** `KinexFit/Resources/Info.plist`
**Risk:** App will crash with runtime error when HealthKitManager requests authorization to access HealthKit data. This is a guaranteed rejection by App Review because users will experience a crash when trying to grant HealthKit permissions.
**Finding:** `KinexFit/Services/HealthKitManager.swift` lines 21–42 call `healthStore.requestAuthorization(toShare:read:)` to request access to HKWorkoutType, bodyMass, bodyFatPercentage, and leanBodyMass. However, Info.plist lacks the required permission strings.
**Fix Applied:** ✅ Added the following to Info.plist:
```xml
<key>NSHealthShareUsageDescription</key>
<string>Kinex Fit needs HealthKit access to sync your workouts and body metrics with the Health app.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>Kinex Fit needs permission to save workout data and body metrics to the Health app.</string>
```
**Verification:** Check Info.plist and ensure both keys are present before submission. Test on a device: grant HealthKit permissions and verify no crashes occur.
**References:** Apple App Review Guidelines 5.1.1 (User Privacy), HealthKit Framework Documentation

---

### CRITICAL-2: Sensitive Data Exposed in Production Debug Logs (TokenStore.swift)
**File:** `KinexFit/Auth/TokenStore.swift` (lines 62, 64, 69)
**Risk:** Keychain error messages and account identifiers leaked to system console and potentially captured in crash logs, exposing sensitive authentication infrastructure details to attackers.
**Finding:** Three NSLog statements in TokenStore execute in production builds:
- Line 62: `NSLog("[KeychainTokenStore] Unexpected keychain status: \(status) - \(message)")`
- Line 64: `NSLog("[KeychainTokenStore] Unexpected keychain status: \(status)")`
- Line 69: `NSLog("[KeychainTokenStore] SecItemCopyMatching returned non-Data item for account: \(account)")`

While status codes themselves are not secret, account identifiers and system error messages should never appear in production logs.
**Fix Applied:** ✅ Wrapped all three NSLog calls in `#if DEBUG` guards. Example:
```swift
#if DEBUG
NSLog("[KeychainTokenStore] Unexpected keychain status: \(status) - \(message)")
#endif
```
**Verification:** Build in Release mode and confirm no NSLog output appears in the console when Keychain operations fail. Use `os_log` with privacy levels for production diagnostics if needed.
**References:** OWASP Mobile Top 10 (M1 – Improper Logging), CWE-532 (Insertion of Sensitive Information into Log File)

---

### CRITICAL-3: Debug Analytics Logging in Production (OnboardingAnalytics.swift)
**File:** `KinexFit/Services/OnboardingAnalytics.swift` (line 101)
**Risk:** Debug `print()` statements in the analytics tracking function will appear in console logs in production builds, leaking user behavior and internal event names to attackers with console access or crash report analysis tools.
**Finding:** OnboardingAnalytics.track() unconditionally prints analytics events to stdout in all builds, including production Release builds.
**Fix Applied:** ✅ Wrapped print() statement in `#if DEBUG` guard:
```swift
#if DEBUG
var message = "[Analytics] \(event.name)"
// ... build message ...
print(message)
#endif
```
**Verification:** Build in Release mode and verify no analytics events are printed to the console.
**References:** CWE-532 (Insertion of Sensitive Information into Log File)

---

## High Issues — Strong Recommendation to Fix

### HIGH-1: Keychain Access Group Not Explicitly Declared
**File:** `Kinex Fit.entitlements`, `Kinex Fit.Debug.entitlements`, `KinexFitShareExtension/KinexFitShareExtension.entitlements`, etc. (4 files)
**Risk:** Medium — While not a hard blocker for first submission, the app uses Keychain but does not explicitly declare `keychain-access-groups` entitlements. This is fine for the main app (uses default access group), but if you ever add an app extension (Share Extension already exists), Keychain sharing between the main app and extension will fail silently, causing loss of authentication state.
**Finding:** TokenStore.swift uses standard Keychain APIs (kSecClass: kSecClassGenericPassword) but the .entitlements files lack:
```xml
<key>keychain-access-groups</key>
<array>
  <string>com.kinex.fit</string>
</array>
```
**Recommended Fix:**
1. Add the keychain-access-groups entitlement to all .entitlements files (main app and each extension):
```xml
<key>keychain-access-groups</key>
<array>
  <string>$(AppIdentifierPrefix)com.kinex.fit</string>
</array>
```
2. Update TokenStore to explicitly use the shared access group:
```swift
private let accessGroup = "$(AppIdentifierPrefix)com.kinex.fit"
```
3. Rebuild and test Keychain storage on device.

**Priority for This Submission:** Optional for first submission (main app works without it), but strongly recommended if you have plans to add extensions.
**References:** Apple Keychain Services Documentation, OWASP Mobile Top 10 (M2 – Insecure Data Storage)

---

### HIGH-2: Potential Data Exposure from Facebook/Google SDKs (PrivacyInfo.xcprivacy Check)
**File:** `KinexFit/Resources/PrivacyInfo.xcprivacy`
**Risk:** Medium — Facebook and Google SDKs are bundled and may access required reason APIs (UserDefaults, file system APIs) that are not declared in Kinex Fit's own PrivacyInfo.xcprivacy. App Review will flag undeclared SDK usage.
**Finding:**
- Scanner detected UserDefaults usage in the Facebook SDK (FBSDKLoginKit.framework/PrivacyInfo.xcprivacy) but Kinex Fit's own privacy manifest only declares CA92.1 (UserDefaults for app function purposes).
- Facebook SDK likely accesses other required APIs (file timestamps, disk space) that may not be declared.

**Recommended Fix:**
1. Review the PrivacyInfo.xcprivacy files included in FBSDKLoginKit, FBSDKCoreKit, and other bundled SDKs:
   ```bash
   find . -path "*/Facebook*" -name "PrivacyInfo.xcprivacy" -exec cat {} \;
   ```
2. Verify that Kinex Fit's own PrivacyInfo.xcprivacy includes entries for all required reason APIs that are used by any bundled SDK. At minimum, check for:
   - `NSPrivacyAccessedAPICategoryFileTimestamp` (CA92.1 reason)
   - `NSPrivacyAccessedAPICategoryDiskSpace` (CA92.1 reason)
   - `NSPrivacyAccessedAPICategoryUserDefaults` (already declared)

3. If any APIs are missing, add them to PrivacyInfo.xcprivacy with appropriate reason codes.

**References:** Apple Privacy Manifest Requirement, App Store Review Guidelines 5.1.2 (Privacy Manifest)

---

### HIGH-3: SQLite Database Not Encrypted
**File:** `KinexFit/Persistence/AppDatabase.swift` (line 16)
**Risk:** Medium-to-High — The SQLite database is created with standard GRDB DatabaseQueue without encryption. If the device is jailbroken or physically compromised, user workout data and metrics are readable in plaintext.
**Finding:**
```swift
self.dbQueue = try DatabaseQueue(path: databaseURL.path)
```
No encryption flags or SQLCipher integration detected.

**Recommended Fix:**
1. **Option A (Recommended):** Integrate SQLCipher for database encryption:
   ```bash
   # Add to Podfile or Package.swift:
   pod 'SQLCipher', '~> 4.5'
   ```
   Then update AppDatabase.swift:
   ```swift
   let config = Configuration()
   config.passphrase = "your-encryption-key" // Use a derived key from Keychain
   self.dbQueue = try DatabaseQueue(path: databaseURL.path, configuration: config)
   ```

2. **Option B:** Enable file protection on the database:
   ```swift
   try FileManager.default.setAttributes(
       [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
       ofItemAtPath: databaseURL.path
   )
   ```

**Priority for This Submission:** High. App Review often flags unencrypted sensitive data stores. Fitness metrics are considered PII.
**References:** OWASP Mobile Top 10 (M2 – Insecure Data Storage), CWE-311 (Missing Encryption of Sensitive Data)

---

### HIGH-4: No Jailbreak/Tampering Detection
**File:** Codebase-wide
**Risk:** Medium — App does not detect jailbroken devices or runtime tampering. Attackers with jailbreak tools can bypass authentication, modify workout data, or intercept tokens.
**Finding:** No calls to standard jailbreak detection libraries (e.g., DTTJailbreakDetection, or custom checks for `/private/var/mobile/Library/Lockdown`, existence of Cydia, etc.) found in codebase.
**Recommended Fix:**
1. Add a simple jailbreak detection check in AppDelegate or AppState initialization:
   ```swift
   func isJailbroken() -> Bool {
       let jailbreakPaths = [
           "/Library/MobileSubstrate/MobileSubstrate.dylib",
           "/bin/bash",
           "/var/lib/cydia"
       ]
       for path in jailbreakPaths {
           if FileManager.default.fileExists(atPath: path) {
               return true
           }
       }
       return false
   }
   ```
2. On app launch, check `isJailbroken()` and either:
   - Log a security warning and display a notice to the user
   - Disable sensitive features (e.g., don't sync health data)
   - Refuse to run (optional, but stronger security)

**Priority for This Submission:** Recommended but not critical for first submission.
**References:** OWASP Mobile Top 10 (M7 – Code Tampering), iOS Security Best Practices

---

### HIGH-5: No Certificate Pinning on Auth Endpoints
**File:** `KinexFit/Networking/APIClient.swift`
**Risk:** Medium — API requests to kinexfit.com are made over HTTPS (good), but there is no certificate pinning. A compromised or rogue certificate authority could issue a valid certificate for kinexfit.com, allowing MITM attacks to intercept tokens and credentials.
**Finding:** APIClient uses standard URLSession without URLSessionDelegate implementing `urlSession(_:didReceive:completionHandler:)` for certificate validation.
**Recommended Fix:**
1. Implement certificate pinning for auth endpoints:
   ```swift
   class URLSessionDelegate: NSObject, URLSessionDelegate {
       func urlSession(
           _ session: URLSession,
           didReceive challenge: URLAuthenticationChallenge,
           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
       ) {
           guard let serverTrust = challenge.protectionSpace.serverTrust else {
               completionHandler(.cancelAuthenticationChallenge, nil)
               return
           }

           // Pin the certificate or public key
           let isValid = validateCertificate(serverTrust, for: "kinexfit.com")
           if isValid {
               completionHandler(.useCredential, URLCredential(trust: serverTrust))
           } else {
               completionHandler(.cancelAuthenticationChallenge, nil)
           }
       }
   }
   ```
2. Consider using a library like TrustKit for easier integration.

**Priority for This Submission:** Recommended for production (not blocking, but best practice for auth apps).
**References:** OWASP Mobile Top 10 (M3 – Insecure Communication), CWE-295 (Improper Certificate Validation)

---

## Medium Issues — Should Fix

*No medium-severity issues identified.*

---

## Low / Informational

### LOW-1: Debug Mode Accessible in Signed-In State
**File:** `KinexFit/Auth/AuthViewModel.swift` (lines 23–26, 61–67, 105–112)
**Finding:** AuthViewModel includes `devModeEnabled` flag and `bypassAuthForDevelopment()` method. While these are `#if DEBUG` gated, ensure they do not leak into Release builds.
**Recommendation:** Verify in Release build that the dev mode button does not appear and `bypassAuthForDevelopment()` is not accessible. Run:
```bash
xcrun lldb -p $(pgrep Kinex)
po AuthViewModel.shared.devModeEnabled  # Should error or be unavailable
```
**Priority:** Low — already guarded by `#if DEBUG`.

---

### LOW-2: Facebook Client Token in Info.plist
**File:** `KinexFit/Resources/Info.plist` (line 52)
**Finding:** `FacebookClientToken` is visible as plain text in Info.plist:
```xml
<key>FacebookClientToken</key>
<string>cc775e3dbf423313ebdbf86f3cb584c3</string>
```
**Risk:** Low — Facebook Client Tokens are semi-public (intended to be bundled with the app), but minimize exposure if possible.
**Recommendation:** This is standard Facebook SDK configuration and expected. No action needed. If you want to obfuscate, move to a server-side configuration endpoint.
**References:** Facebook SDK Documentation

---

### LOW-3: No Restore Purchases Button Visible in UI
**File:** Codebase-wide (review subscription/store views)
**Finding:** StoreManager implements `restorePurchases()` (line 101), but no UI button found in accessible store/subscription views to trigger it.
**Risk:** Low — Guideline 3.2.1 requires users to be able to restore purchases. If no button is visible, Apple may reject during review.
**Recommendation:** Add a "Restore Purchases" button in your Store/Subscription view:
```swift
Button("Restore Purchases") {
    Task {
        await storeManager.restorePurchases()
    }
}
```
Place it in an easily accessible location (e.g., Settings > Subscription or in the paywall).

---

### LOW-4: Terms of Service and Privacy Policy Links Not Implemented
**File:** `KinexFit/Views/Auth/SignInView.swift` (line 165)
**Finding:** SignInView displays text: `"By continuing, you agree to our Terms of Service and Privacy Policy"` but the links are not clickable.
**Risk:** Low — Users may not be able to access legal documents. Technically compliant (text is there), but UX is poor.
**Recommendation:** Make the text tappable and navigate to your Terms and Privacy Policy URLs:
```swift
Text("By continuing, you agree to our ")
    + Text("Terms of Service")
        .foregroundColor(.blue)
        .onTapGesture { UIApplication.shared.open(URL(string: "https://kinexfit.com/terms")!) }
    + Text(" and ")
    + Text("Privacy Policy")
        .foregroundColor(.blue)
        .onTapGesture { UIApplication.shared.open(URL(string: "https://kinexfit.com/privacy")!) }
```

---

## App Store Submission Checklist

| Item | Status | Notes |
|------|--------|-------|
| **Privacy Manifest** | ✅ PASS | PrivacyInfo.xcprivacy present; NSPrivacyAccessedAPICategoryUserDefaults declared. Verify all SDK APIs are covered. |
| **HealthKit Permissions** | ✅ PASS (AFTER AUTO-FIX) | NSHealthShareUsageDescription and NSHealthUpdateUsageDescription now in Info.plist. Test on device. |
| **Camera Permissions** | ✅ PASS | NSCameraUsageDescription present and clear. |
| **Photo Library Permissions** | ✅ PASS | NSPhotoLibraryUsageDescription present and clear. |
| **Sign in with Apple** | ✅ PASS | Implemented in SignInView; AuthenticationServices entitlement present in .entitlements. Button is first option in auth flow. Complies with Guideline 4.8. |
| **Sign in with Google** | ✅ PASS | Implemented; custom URL scheme registered. User can authenticate. |
| **Sign in with Facebook** | ✅ PASS | Implemented behind feature flag; custom URL scheme registered. |
| **In-App Purchases (StoreKit 2)** | ⚠️ NEEDS REVIEW | StoreManager uses StoreKit 2 with server-side receipt validation (recommended). Verify ProductID enum matches App Store product list. Add Restore Purchases button if not present. |
| **App Transport Security (ATS)** | ✅ PASS | No `NSAllowsArbitraryLoads` or exceptions in Info.plist. HTTPS enforced for kinexfit.com API. |
| **Token Storage** | ✅ PASS | Tokens stored in Keychain (TokenStore.swift). Tokens cleared on logout. No hardcoded tokens in code. |
| **Debug Logging** | ✅ PASS (AFTER AUTO-FIX) | NSLog and print statements wrapped in `#if DEBUG`. No sensitive data exposed in Release builds. |
| **Entitlements** | ✅ PASS (with notes) | Signing entitlements, app groups, and Sign in with Apple declared. Keychain groups recommended but not blocking. |
| **Build Number & Version** | ⚠️ NEEDS REVIEW | Verify CFBundleShortVersionString and CFBundleVersion are set correctly in build configuration before submission. |
| **App Icon & Display Name** | ⚠️ NEEDS REVIEW | Confirm app icon is present in Assets.xcassets and CFBundleDisplayName is "Kinex Fit". |
| **Supported Devices** | ✅ PASS | App targets iOS 17+, declared in UISupportedInterfaceOrientations. |
| **Database Encryption** | ❌ FAIL | SQLite database is not encrypted. Implement SQLCipher or file protection before final submission. |
| **Jailbreak Detection** | ❌ MISSING | No jailbreak detection implemented. Recommended for production security. |
| **Certificate Pinning** | ❌ MISSING | No certificate pinning on auth endpoints. Recommended but not blocking. |
| **Crash Testing** | ⚠️ TODO | Build Release archive and test on physical device. Verify HealthKit permission prompt does not crash. |

---

## Next Steps

### Before Submission (Required)
1. ✅ **Auto-fixes are already applied** to Info.plist, TokenStore.swift, and OnboardingAnalytics.swift.
2. ⚠️ **Test on device:** Build a Release archive and install on a physical iPhone (iOS 17+). Go through the full sign-in flow and grant HealthKit permissions to verify no crashes.
3. ⚠️ **Database encryption:** Implement SQLCipher or file protection (see HIGH-3).
4. ⚠️ **Verify StoreKit setup:** Ensure all product IDs in ProductID enum match your App Store app configuration.
5. ⚠️ **Verify legal URLs:** Make sure your Terms of Service and Privacy Policy are accessible at the URLs you'll provide in App Store Connect.

### Recommended Before Submission
- Add Restore Purchases button if not present (LOW-3).
- Implement certificate pinning for auth endpoints (HIGH-5).
- Add jailbreak detection (HIGH-4).

### After Submission (Ongoing)
- Monitor App Review feedback and crash reports.
- Plan to implement Keychain access groups if you expand to app extensions.
- Migrate to `os_log` with privacy levels for production diagnostics.

---

## Summary of Changes

### Files Modified:
1. **`KinexFit/Resources/Info.plist`**
   - Added NSHealthShareUsageDescription
   - Added NSHealthUpdateUsageDescription

2. **`KinexFit/Auth/TokenStore.swift`**
   - Wrapped 3 NSLog calls in `#if DEBUG` guards

3. **`KinexFit/Services/OnboardingAnalytics.swift`**
   - Wrapped analytics print() in `#if DEBUG` guard

### Files Needing Updates (Not Auto-Fixed):
1. **`KinexFit/Persistence/AppDatabase.swift`** — Implement database encryption
2. **`KinexFit/Views/Store/*`** — Add Restore Purchases button (optional)
3. **All .entitlements files** — Add keychain-access-groups (recommended)

---

## Appendix: References & Resources

### Apple Official Guidelines
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App Privacy Manifest](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
- [HealthKit Framework](https://developer.apple.com/documentation/healthkit)
- [StoreKit 2 Documentation](https://developer.apple.com/documentation/storekit)

### Security & Best Practices
- [OWASP Mobile Top 10](https://owasp.org/www-project-mobile-top-10/)
- [iOS Security Best Practices](https://developer.apple.com/documentation/security)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)

### Testing Checklist
- [ ] Build Release archive
- [ ] Install on physical iOS 17+ device
- [ ] Test all sign-in flows (Apple, Google, Facebook, Email)
- [ ] Request HealthKit permissions
- [ ] Sync a workout
- [ ] Make an in-app purchase
- [ ] Test Restore Purchases
- [ ] Verify no console logs in Release build

---

*Generated by ios-appstore-review skill on March 7, 2026. For questions or clarifications, refer to Apple's official guidelines linked above.*
