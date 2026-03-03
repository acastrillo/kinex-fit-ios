# Ticket #37 - Export Workout Data Guide

**Status:** Specification Ready  
**Complexity:** Low (documentation + simple API method)  
**Files to Create:**
- `ios/KinexFit/Services/WorkoutExportManager.swift` - Export service  
- Documentation for API endpoint

---

## Feature Requirements

### What It Does:
1. Users can export their workout history as JSON
2. Export includes: all completed workouts, PRs, metrics over date range
3. Formats: JSON (default), CSV (future)
4. Covers date range selection (last 30 days, 90 days, all-time)

### User Experience:
```
Settings → Export Data
  ↓ (select date range)
Choose Format: JSON | CSV
  ↓ (download/share)
File appears in Files app or shares to email
```

---

## Implementation

### WorkoutExportManager.swift
```swift
@MainActor
final class WorkoutExportManager {
    private let workoutRepository: WorkoutRepository
    private let statsRepository: StatsRepository
    
    func exportWorkouts(
        startDate: Date? = nil,
        endDate: Date? = nil,
        format: ExportFormat = .json
    ) async throws -> Data {
        let workouts = try await workoutRepository.getCompletedWorkouts(
            startDate: startDate,
            endDate: endDate
        )
        let metrics = try await statsRepository.getMetrics(
            startDate: startDate,
            endDate: endDate
        )
        
        let export = ExportPayload(
            exportedAt: Date(),
            workouts: workouts,
            metrics: metrics,
            dateRange: (startDate, endDate)
        )
        
        switch format {
        case .json:
            return try JSONEncoder().encode(export)
        case .csv:
            return try export.toCSV().data(using: .utf8) ?? Data()
        }
    }
    
    enum ExportFormat: String {
        case json, csv
    }
}
```

### ExportPayload Structure
```swift
struct ExportPayload: Codable {
    let exportedAt: Date
    let workouts: [Workout]
    let metrics: BodyMetricsSnapshot
    let dateRange: (Date?, Date?)
    
    func toCSV() -> String {
        // Convert to CSV format
        var csv = "Date,Exercise,Weight,Reps,Duration\n"
        for workout in workouts {
            for block in workout.blocks {
                csv += "\(workout.date),\(block.name),\(block.weight),\(block.reps),\(block.duration)\n"
            }
        }
        return csv
    }
}
```

### Settings UI Integration
```swift
SettingsRow(
    icon: "arrow.up.doc",
    title: "Export Data",
    subtitle: "Download your workout history",
    action: { showExportPicker = true }
)
```

---

## Testing
- [ ] Export with all-time range
- [ ] Export with 30-day range
- [ ] Export with custom range
- [ ] JSON format is valid
- [ ] CSV format is valid
- [ ] Can share via Files/Email
- [ ] Exported file is readable

---

**Pattern:** Read repos → Aggregate → Encode → Return

Generated: 2026-03-02
