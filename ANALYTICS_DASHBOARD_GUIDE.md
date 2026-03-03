# Ticket #39 - Analytics Dashboard Guide

**Status:** Specification Ready  
**Pattern:** Extend StatsRepository (reuse #26 logic)

## Overview
Create comprehensive stats dashboard in Stats tab showing:
- Total workouts (all-time + this month)
- Average intensity (RPE tracking)
- Most trained exercises
- Weekly volume trend
- Body metrics progress

## Implementation
```swift
struct AnalyticsDashboard: View {
    @StateObject var viewModel: AnalyticsViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Workout count card
                StatsCard(
                    title: "Total Workouts",
                    value: "\(viewModel.totalWorkouts)",
                    subtitle: "\(viewModel.thisMonthWorkouts) this month"
                )
                
                // Intensity card
                StatsCard(
                    title: "Avg Intensity",
                    value: "\(viewModel.avgIntensity, specifier: "%.1f")",
                    subtitle: "RPE Score"
                )
                
                // Top exercises
                TopExercisesView(exercises: viewModel.topExercises)
                
                // Volume trend chart
                VolumeChartView(data: viewModel.volumeTrend)
                
                // Body metrics progress
                BodyMetricsProgressView(metrics: viewModel.metricsProgress)
            }
        }
    }
}
```

## Data Sources
- Use StatsRepository methods from #26
- Cache with 24h invalidation
- Group by week for trends

## Files
- `StatsRepository+Analytics.swift` - Extension with dashboard queries
- `Views/Stats/AnalyticsDashboard.swift` - UI component
- `ViewModels/AnalyticsViewModel.swift` - Data binding

---
Generated: 2026-03-02
