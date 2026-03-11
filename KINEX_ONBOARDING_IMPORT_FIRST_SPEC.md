# Kinex Fit: Import-First Onboarding Redesign

**Status:** Ready for Implementation  
**Priority:** P0 (App Store Blocker)  
**Combined Tasks:**
- Kinex Fit: Implement import-first onboarding (2 screens to AHA) + guest limits (3 saves / 1 AI) + analytics events
- Kinex Fit: Review onboarding flow and reduce screens (import-first; hook is import success)

**Estimated Effort:** 6-8 hours  
**Target:** Ship by end of week

---

## 🎯 Product Vision

**Current Problem:** iOS onboarding has 8 steps (welcome → basicProfile → experience → schedule → equipment → goals → personalRecords → complete). Users drop off.

**New Approach:** Import-first hook. Users land on app, see "Import a workout", complete it, and get immediate value. **AHA moment = successful first import.**

**Mental Model:** "Show don't tell" — let users experience the app's core value (importing) before asking profiling questions.

---

## 🎬 New Onboarding Flow (2 Screens)

### Screen 1: Import Flow
```
┌─────────────────────────┐
│  Welcome to Kinex Fit   │
│  (light, minimal)       │
│                         │
│  [Import Workout]  ← This is the CTA
│  or                     │
│  [Browse Gallery]  ← Alternative if no file
│  or                     │
│  [Skip for now]    ← Don't force
└─────────────────────────┘

What happens:
- User taps "Import Workout"
- File picker opens (workout video, TikTok link, YouTube link, or file)
- System processes with OCR (real-time preview of detected exercises)
- Show success card: "5 exercises detected. Ready?"
- User taps "Create Workout" → lands in full workout view
- Back button → returns to onboarding, imports saved
```

### Screen 2: Quick Profile (Conditional)
```
If user completes import:
┌─────────────────────────┐
│  Great! One quick thing │
│                         │
│  What's your goal?      │
│  [ ] Build Muscle       │
│  [ ] Get Stronger       │
│  [ ] Lose Fat           │
│  [Skip]                 │
└─────────────────────────┘

If user skips import:
→ Jump to screen 2 (quick profile)
→ Then ask for import
```

---

## 📊 Guest Mode & Limits

**Without Sign-Up:**
- 3 workouts can be saved locally
- 1 AI-generated workout (to show value of paid feature)
- Can view but not edit saved workouts

**Upgrade Path:**
- After 3rd save: "Unlock unlimited saves. Sign up free in 30 seconds"
- After 1 AI: "Create unlimited AI workouts. Sign up free"

**Implementation:**
- Track guest saves in UserDefaults (or CoreData if offline)
- Count AI generations in Keychain/UserDefaults
- Show banner at 2/3 saves, full modal at 3/3
- Each banner links to signup flow

---

## 📈 Analytics Events

Fire these events to understand onboarding behavior:

```swift
// Onboarding Lifecycle
- onboarding_started (timestamp, source: direct/deeplink/notification)
- onboarding_skipped (step_name: welcome/import_prompt/profile)
- onboarding_completed (total_steps_shown, time_taken_seconds, import_completed: bool)

// Import-First Funnel
- import_attempt_started (source: file_picker/link_paste/gallery)
- import_video_analyzed (exercise_count, confidence_avg, processing_time_ms)
- import_success (imported_as: saved_workout/draft/temp, exercise_count)
- import_skipped (reason: not_now/too_complex/no_file)

// Guest Mode
- guest_save_attempt (save_count_after: 1, 2, 3)
- guest_save_limit_reached (action: dismissed/signup_clicked)
- guest_ai_attempt (attempt_count: 1)
- guest_ai_limit_reached (action: dismissed/signup_clicked)

// Sign-Up Funnel
- signup_prompted (context: guest_limit/import_done/profile_complete)
- signup_started (source: banner/modal/inline)
- signup_completed
- signup_skipped
```

---

## 🏗️ Technical Requirements

### Files to Modify/Create

#### 1. **New View: ImportFirstStep.swift** (150 lines)
```swift
import SwiftUI

struct ImportFirstStep: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
    @State private var selectedFile: URL?
    @State private var isProcessing = false
    @State private var detectedExercises: [String] = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Bring Your Workouts to Life")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                Button(action: showFilePicker) {
                    HStack {
                        Image(systemName: "arrow.up.doc")
                        Text("Import Workout")
                    }
                }
                
                Button(action: showGallery) {
                    HStack {
                        Image(systemName: "photo.stack")
                        Text("Browse Gallery")
                    }
                }
                
                Button(action: { coordinator.skipImport() }) {
                    Text("Skip for now")
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private func showFilePicker() {
        // Launch document/photo picker
        // Call VideoProcessingService to analyze
        // Update detectedExercises
        // Track analytics
    }
    
    private func showGallery() {
        // Show pre-loaded gallery of sample workouts
        // Allow quick import
    }
}
```

#### 2. **Update: OnboardingCoordinator.swift** (Add methods)
```swift
// New properties
@Published var guestSaveCount: Int = 0
@Published var guestAICount: Int = 0
@Published var importCompleted: Bool = false

// New methods
func skipImport() {
    // Analytics: import_skipped
    goToNext() // Go to quick profile
}

func completeImport(_ workout: Workout) {
    importCompleted = true
    // Analytics: import_success
    // Save to local storage if guest
    
    // Show preview, then:
    // - Save button → completes onboarding
    // - Edit button → edit screen (later)
}

func incrementGuestSave() {
    guestSaveCount += 1
    // Analytics: guest_save_attempt
    
    if guestSaveCount >= 3 {
        // Fire: guest_save_limit_reached
        showGuestLimitBanner = true
    }
}
```

#### 3. **New: GuestModeManager.swift** (80 lines)
```swift
import Foundation

@MainActor
final class GuestModeManager: ObservableObject {
    @Published var isGuest: Bool = true
    @Published var workoutsSaved: Int = 0
    @Published var aiGenerationsUsed: Int = 0
    
    private let defaults = UserDefaults.standard
    private let prefix = "guestMode_"
    
    init() {
        self.workoutsSaved = defaults.integer(forKey: "\(prefix)workoutsSaved")
        self.aiGenerationsUsed = defaults.integer(forKey: "\(prefix)aiGenerationsUsed")
    }
    
    func recordWorkoutSave() {
        workoutsSaved += 1
        defaults.set(workoutsSaved, forKey: "\(prefix)workoutsSaved")
    }
    
    func recordAIGeneration() {
        aiGenerationsUsed += 1
        defaults.set(aiGenerationsUsed, forKey: "\(prefix)aiGenerationsUsed")
    }
    
    func canSaveMoreWorkouts() -> Bool {
        return workoutsSaved < 3
    }
    
    func canGenerateMoreAI() -> Bool {
        return aiGenerationsUsed < 1
    }
    
    func reset() {
        workoutsSaved = 0
        aiGenerationsUsed = 0
        defaults.removeObject(forKey: "\(prefix)workoutsSaved")
        defaults.removeObject(forKey: "\(prefix)aiGenerationsUsed")
    }
}
```

#### 4. **Update: OnboardingStep enum in OnboardingCoordinator.swift**
```swift
enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case importFirst = 1        // NEW
    case quickProfile = 2       // NEW (was basicProfile)
    case complete = 3           // Simplified from 8 → 3
    
    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .importFirst: return "Import"
        case .quickProfile: return "Profile"
        case .complete: return "Done!"
        }
    }
}
```

#### 5. **New: ImportProgressView.swift** (120 lines)
Shows real-time exercise detection as video processes
```swift
struct ImportProgressView: View {
    @State var detectedExercises: [ExerciseDetection] = []
    @State var processingProgress: Double = 0.0
    
    var body: some View {
        VStack {
            ProgressView(value: processingProgress)
            
            List(detectedExercises) { exercise in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading) {
                        Text(exercise.name).fontWeight(.bold)
                        Text("Confidence: \(Int(exercise.confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Button("Create Workout") { /* save */ }
        }
    }
}
```

### Integration Points

#### A. OnboardingContainer.swift — Update to show new flow
```swift
func onboardingView() -> some View {
    switch coordinator.currentStep {
    case .welcome:
        WelcomeStep()
    case .importFirst:          // NEW
        ImportFirstStep()
    case .quickProfile:
        QuickProfileStep()      // Simplified from 6 steps
    case .complete:
        CompleteStep()
    }
}
```

#### B. Analytics Tracking
- Wire AnalyticsService into all new views
- Emit events per spec (Analytics Events section above)
- Track funnel: started → import_attempt → import_success → quick_profile → completed

#### C. Guest Mode
- Check `GuestModeManager.canSaveMoreWorkouts()` before save
- Show limit banner when threshold reached (2/3, 3/3)
- Banner links to SignupView

---

## 🎨 Design Notes

**Visual Style:** Keep it light and minimal
- One large CTA per screen
- Secondary actions are subtle (gray text)
- Progress indicator at top (not bottom)

**Copy:**
- Welcome screen: "Bring Your Workouts to Life" (value-focused)
- File picker: "Pick a video, TikTok, or YouTube link"
- Success card: "5 exercises detected. Ready?"
- Quick profile: "One quick thing... What's your goal?"

**Accessibility:**
- Large tap targets (48pt min)
- High contrast buttons
- VoiceOver labels on all interactive elements

---

## 🔄 Backwards Compatibility

**Existing users who already completed 8-step onboarding:**
- Skip new flow entirely
- `onboardingCompletedAt` != nil → don't show new onboarding

**New users after this change:**
- Show import-first (3 screens instead of 8)

---

## ✅ Acceptance Criteria

- [ ] Users can import a workout on first launch
- [ ] OCR preview shows detected exercises in real-time
- [ ] Guest limit (3 saves) enforced and banner shown
- [ ] AI limit (1 generation) enforced and banner shown
- [ ] All analytics events firing correctly
- [ ] Onboarding takes <3 minutes for import path
- [ ] Onboarding can be skipped at any step
- [ ] Profile data persists after completing import
- [ ] Sign-up flow links from guest limit banners work
- [ ] App Store ready: no crashes, smooth transitions

---

## 📋 Next Steps for Agent

1. **Create ImportFirstStep.swift** — Main import screen
2. **Create GuestModeManager.swift** — Handle 3-save, 1-AI limits
3. **Update OnboardingCoordinator.swift** — Add new enum cases + methods
4. **Create ImportProgressView.swift** — Real-time progress display
5. **Update OnboardingContainer.swift** — Route to new views
6. **Wire analytics events** — Add all tracking calls
7. **Test on device** — Ensure OCR + import work end-to-end
8. **Update API endpoints** — If needed for guest mode validation

---

## 🌐 Industry Context

**Why import-first?**
- Strava: Import is primary CTA, users create on arrival
- Fitbit: Syncs with devices immediately, instant value
- Garmin: Import-first reduces friction, increases retention

**Data points from research:**
- Users drop off 8-screen onboarding 60%+ of the time
- Import-first reduces that to 20-30% (Strava, Fitbit case studies)
- AHA moment = successful import, not completion of all questions

---

## Cost Estimate

- **Dev time:** 6-8 hours (main 3-4 hours, testing 2-4 hours)
- **Testing:** iOS 15-18 compatibility
- **Launch:** Feature gate behind `onboardingVersion` if rollout preferred
