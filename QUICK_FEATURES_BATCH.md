# Batch Quick Features - Tickets #40-55

All documentation-first specifications for duplicate/variant features. Ready for quick implementation.

---

## #40 - Trending Exercises
**Pattern:** Cache extension
```
StatsRepository method: getTrendingExercises(timeframe: .week | .month)
Returns: [Exercise] sorted by usage frequency in period
Use case: HomeTab carousel "Popular this week"
```

---

## #41 - Strength Curve Analysis
**Pattern:** Reuse PR progression
```
PRRepository.getStrengthCurve(exercise: String) -> [PRData]
Fit exponential curve to PR progression
Show predicted 1RM growth trajectory
```

---

## #42 - Compare Progress Over Time
**Pattern:** Date filtering (like #26)
```
StatsRepository method: compareProgress(
    metric: BodyMetric,
    startDate: Date,
    endDate: Date
) -> ProgressComparison
Returns: percentage change, absolute change, trend direction
```

---

## #43 - Custom Themes
**Pattern:** Settings row + UserPreferences
```
enum AppTheme: String, Codable {
    case light, dark, highContrast
}
Add to User model: preferredTheme: AppTheme
Toggle in Settings, persist, apply on app launch
```

---

## #44 - Keyboard Shortcuts
**Pattern:** View modifier
```
.keyboardShortcut("space") { startTimer() }
.keyboardShortcut("p") { pauseTimer() }
.keyboardShortcut("r") { resumeTimer() }
```

---

## #46 - Workout History Filtering
**Pattern:** Date range (like #26)
```
WorkoutRepository.getWorkouts(
    startDate: Date?,
    endDate: Date?,
    status: WorkoutStatus?
) -> [Workout]
Add filter UI to History tab
```

---

## #48 - Search Exercises
**Pattern:** SearchBar + filter
```
@State var searchText = ""
var filteredExercises: [Exercise] {
    if searchText.isEmpty { return allExercises }
    return allExercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
}
Add SearchBar to ExerciseLibrary
```

---

## #49 - Sort Exercises
**Pattern:** Picker + sorted collection
```
enum SortOption: String, CaseIterable {
    case nameAZ, nameZA, mostUsed, recentlyUsed
}
@State var sortOption = SortOption.nameAZ
Computed property: sortedExercises (apply sort logic)
```

---

## #50 - Workout Reminders
**Pattern:** Extend #66 NotificationManager
```
scheduleWorkoutReminder(
    date: Date,
    title: String = "Time for your workout!",
    importance: RemindLevel = .normal
)
```

---

## #52 - Achievement Badges
**Pattern:** Reuse #25 completion count
```
enum Badge: String, CaseIterable {
    case tenWorkouts, fiftyWorkouts, hundredWorkouts
    case newPR, consistentWeek
}
Add Badge[] to User model
Show badge row in HomeTab
```

---

## #53 - Milestone Notifications
**Pattern:** Extend #50 reminders
```
if totalWorkouts == 50 {
    notificationManager.showMilestone(
        title: "50 Workouts!",
        body: "You've completed 50 workouts! 🎉"
    )
}
```

---

## #54 - Weekly Summary Email
**Pattern:** API specs (like #47 App Store Guide)
```
POST /api/user/email/weekly-summary

Response includes:
- Total workouts
- Volume
- Top exercise
- New PRs
- Body metrics change
```

---

## #55 - Custom Alerts
**Pattern:** Settings + UserPreferences
```
struct AlertPreference: Codable {
    var enabled: Bool
    var sound: Bool
    var haptic: Bool
    var timing: TimeInterval
}
Add SettingsRow for alert customization
```

---

## Batch Implementation Order (fastest to slowest)
1. **Documentation specs** (#54): 5 min
2. **Settings toggles** (#43, #55): 10 min each
3. **Sort/Search** (#48, #49): 15 min each
4. **Repository extensions** (#40-42, #46, #50): 20 min each
5. **UI components** (#39, #41): 30 min each

**Total estimate: 3-4 hours for all 20 tickets at 10-30 min/ticket**

---
Generated: 2026-03-02 22:20 EST
