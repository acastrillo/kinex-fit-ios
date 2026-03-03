# Ticket #24 - Onboarding Skip Feature Implementation

**Status:** Ready for Implementation  
**Complexity:** Medium  
**Files to Modify:**
- `ios/KinexFit/Models/User.swift` - Add skip tracking
- `ios/KinexFit/Views/Onboarding/OnboardingCoordinator.swift` - Add skip button
- `ios/KinexFit/Views/Profile/SettingsView.swift` - Add "Resume Onboarding" option

---

## Feature Requirements

### What It Does:
1. Users can skip onboarding ("Skip for Now" button on welcome screen)
2. Skip state is persisted to User model (skip_onboarding_at timestamp)
3. Users can resume/complete onboarding later from Settings
4. Resume shows the next uncompleted step (not from beginning)

### User Experience:
```
Welcome Screen → [Skip for Now] [Get Started]
   ↓ (skip)
Main App
   ↓ (user goes to Settings)
Settings → "Complete Your Profile" button
   ↓ (click)
Resume Onboarding from step they left off
```

---

## Implementation Steps

### 1. Add Skip State to User Model
```swift
struct User {
    ...
    var skipOnboardingAt: Date?  // When user skipped
    var onboardingCompletedStep: Int?  // Track last completed step
    ...
}
```

### 2. Add Skip Button to Welcome Screen
```swift
HStack {
    Button("Skip for Now") {
        viewModel.skipOnboarding()
    }
    .foregroundStyle(.secondary)
    
    Button("Get Started") {
        viewModel.goToNext()
    }
    .foregroundStyle(.white)
    .background(AppTheme.accent)
}
```

### 3. Enhance OnboardingViewModel
```swift
func skipOnboarding() async {
    // Save skip state
    var user = try await userRepository.getCurrentUser()
    user.skipOnboardingAt = Date()
    user.onboardingCompletedStep = currentStep.rawValue
    try await userRepository.updateUser(user)
    
    // Trigger completion
    onComplete()
}
```

### 4. Add Resume in Settings
```swift
SettingsRow(
    icon: "checkmark.circle",
    title: "Complete Your Profile",
    subtitle: "Finish setting up your training profile",
    action: {
        showOnboarding = true
    }
)
```

### 5. Load Skipped State on App Launch
```swift
if user.skipOnboardingAt != nil {
    // Load last completed step
    let lastStep = user.onboardingCompletedStep ?? 0
    coordinator.jumpToStep(lastStep + 1)
}
```

---

## Code Changes Summary

**User.swift additions:**
- `skipOnboardingAt: Date?`
- `onboardingCompletedStep: Int?`

**OnboardingCoordinator.swift additions:**
- `skipOnboarding()` async method
- `jumpToStep(_ step: Int)` navigation method
- Check skip state on init

**SettingsView.swift additions:**
- Show "Complete Your Profile" row if `user.skipOnboardingAt != nil`
- Navigation to onboarding modal

---

## Testing Checklist
- [ ] Skip button appears on welcome screen
- [ ] Skip saves skip state to backend
- [ ] App doesn't show onboarding after skip
- [ ] "Complete Your Profile" appears in Settings
- [ ] Resuming starts from skipped step
- [ ] Completing onboarding clears skip state
- [ ] Uninstall/reinstall shows onboarding (fresh start)

---

## Notes
- Skip state is user-specific (persisted to backend)
- Allow unlimited re-entry to onboarding
- Clear skip_onboarding_at when user completes
- Support partial completion (user goes to step 3, skips, resume at step 4)

---

**Implementation Pattern:** Read → Validate → Persist → Complete

Generated: 2026-03-02 21:35 EST
