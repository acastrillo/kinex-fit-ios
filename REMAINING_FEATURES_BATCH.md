# Remaining Features Batch - Quick Specs

## #30 - Apple Watch Companion App
**Status:** Specification
**Pattern:** Extend NotificationManager for watchOS

```swift
// WatchKit extension target
struct WorkoutSessionView: WKInterfaceController {
    @IBAction func startWorkoutTapped() {
        WKExtensionDelegate.workoutSession.start()
    }
    
    func updateTimer(_ elapsed: TimeInterval) {
        timerLabel.setText(String(format: "%02d:%02d", Int(elapsed/60), Int(elapsed) % 60))
    }
}
```

---

## #31 - Siri Integration for Timer
**Status:** Specification  
**Pattern:** NSUserActivity + Intents

```swift
let activity = NSUserActivity(activityType: "com.kinexfit.starttimer")
activity.title = "Start workout timer"
activity.isEligibleForSearch = true
activity.isEligibleForHandoff = true
userActivity = activity
```

---

## #32 - Haptic Feedback
**Status:** Specification  
**Pattern:** UIImpactFeedbackGenerator + haptic property in User

```swift
let impact = UIImpactFeedbackGenerator(style: .medium)
impact.impactOccurred()

// For timer completion
let success = UINotificationFeedbackGenerator()
success.notificationOccurred(.success)
```

---

## #33 - Background Sync
**Status:** Specification  
**Pattern:** BGProcessingTaskRequest

```swift
func scheduleBackgroundSync() {
    let request = BGProcessingTaskRequest(identifier: "com.kinexfit.sync")
    request.requiresNetworkConnectivity = true
    try? BGTaskScheduler.shared.submit(request)
}
```

---

## #34 - Offline Mode Support
**Status:** Specification  
**Pattern:** Extend VideoCacheManager to all services

```swift
protocol CacheableService {
    func getCachedData() -> [LocalModel]
    func syncWhenOnline() async throws
}
```

---

## #35 - Apple HealthKit Integration
**Status:** Specification  
**Complexity:** Medium (requires capabilities)

```swift
import HealthKit

class HealthKitManager {
    let store = HKHealthStore()
    
    func requestHealthKitAuthorization() async throws {
        let types = Set([
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ])
        try await store.requestAuthorization(toShare: types, read: types)
    }
}
```

---

## #44 - Keyboard Shortcuts
**Status:** Specification  
**Pattern:** ViewModifier

```swift
.keyboardShortcut("space", modifiers: .command) {
    viewModel.toggleTimer()
}
.keyboardShortcut("p") {
    viewModel.pauseTimer()
}
```

---

## #45 - StoreKit 2 Integration
**Status:** Specification  
**Pattern:** StoreKit 2 framework

```swift
import StoreKit

@Observable
class StoreManager {
    @MainActor
    func fetchProducts() async throws -> [Product] {
        return try await Product.products(for: ["com.kinex.monthly", "com.kinex.annual"])
    }
    
    @MainActor
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        // Handle transaction
    }
}
```

---

## #51 - Dark Mode Optimization
**Status:** Specification  
**Pattern:** Already implemented via AppTheme in #43

Uses `AppTheme` + `preferredTheme` user setting from ticket #43.

---

## #53 - Milestone Notifications
**Status:** Specification  
**Pattern:** Extend #50 ReminderImportance

```swift
func checkMilestones(_ workoutCount: Int) {
    if workoutCount == 50 {
        Task {
            try? await notificationManager.scheduleReminder(
                title: "🎉 50 Workouts!",
                body: "You're halfway to 100!",
                date: Date(),
                importance: .high
            )
        }
    }
}
```

---

## #54 - Weekly Summary Email
**Status:** Specification  
**Pattern:** Backend API + formatting

```
POST /api/notifications/weekly-summary

Response:
{
    "period": "2026-02-26 to 2026-03-04",
    "workouts": 5,
    "volume": 12500,
    "topExercise": "Kettlebell Swing",
    "newPRs": 2,
    "bodyMetricsChange": { "weight": -1.5, "unit": "lbs" }
}
```

---

## Summary

- **#30**: WatchKit extension (medium complexity)
- **#31**: Siri Intents (medium)
- **#32**: Haptic feedback (low - one-liner additions)
- **#33**: BGTaskScheduler (medium)
- **#34**: Cache extension pattern (low)
- **#35**: HealthKit (medium-high, requires capabilities)
- **#44**: Keyboard shortcuts (low)
- **#45**: StoreKit 2 (medium-high, payment handling)
- **#51**: Dark mode (done via #43)
- **#53**: Milestone notifications (low - extend #50)
- **#54**: Email specs (API documentation)

**All specs ready for implementation. Total: 11 features.**

---
Generated: 2026-03-02 22:25 EST
