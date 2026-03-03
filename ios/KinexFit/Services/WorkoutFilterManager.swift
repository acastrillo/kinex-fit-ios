import Foundation
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "WorkoutFilter")

/// Manages workout filtering and search
@MainActor
final class WorkoutFilterManager {
    static let shared = WorkoutFilterManager()

    // MARK: - Filter Types

    struct WorkoutFilter {
        var dateRange: DateRange?
        var status: WorkoutStatus?
        var difficulty: String?
        var minDuration: Int?
        var maxDuration: Int?
        var searchText: String = ""

        enum DateRange {
            case lastWeek, lastMonth, last3Months, custom(Date, Date)
        }

        enum WorkoutStatus: String, CaseIterable {
            case completed, scheduled, skipped
        }
    }

    // MARK: - Filtering

    func filter(_ workouts: [Workout], with filter: WorkoutFilter) -> [Workout] {
        var result = workouts

        // Date range filter
        if let dateRange = filter.dateRange {
            result = filterByDateRange(result, dateRange)
        }

        // Status filter
        if let status = filter.status {
            result = result.filter { $0.status?.rawValue == status.rawValue }
        }

        // Duration filter
        if let minDuration = filter.minDuration {
            result = result.filter { ($0.durationMinutes ?? 0) >= minDuration }
        }
        if let maxDuration = filter.maxDuration {
            result = result.filter { ($0.durationMinutes ?? 0) <= maxDuration }
        }

        // Search filter
        if !filter.searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(filter.searchText) }
        }

        return result
    }

    private func filterByDateRange(_ workouts: [Workout], _ range: WorkoutFilter.DateRange) -> [Workout] {
        let now = Date()
        let calendar = Calendar.current

        let (startDate, endDate) = switch range {
        case .lastWeek:
            (calendar.date(byAdding: .day, value: -7, to: now) ?? now, now)
        case .lastMonth:
            (calendar.date(byAdding: .month, value: -1, to: now) ?? now, now)
        case .last3Months:
            (calendar.date(byAdding: .month, value: -3, to: now) ?? now, now)
        case .custom(let start, let end):
            (start, end)
        }

        return workouts.filter { workout in
            guard let dateStr = workout.completedDate else { return false }
            // Parse date and compare
            return true
        }
    }

    // MARK: - Sorting

    enum SortOption: String, CaseIterable {
        case recent = "Most Recent"
        case oldest = "Oldest"
        case longestDuration = "Longest Duration"
        case shortestDuration = "Shortest Duration"
        case difficulty = "Difficulty"

        func sort(_ workouts: [Workout]) -> [Workout] {
            switch self {
            case .recent:
                return workouts.sorted { ($0.updatedAt) > ($1.updatedAt) }
            case .oldest:
                return workouts.sorted { ($0.updatedAt) < ($1.updatedAt) }
            case .longestDuration:
                return workouts.sorted { ($0.durationMinutes ?? 0) > ($1.durationMinutes ?? 0) }
            case .shortestDuration:
                return workouts.sorted { ($0.durationMinutes ?? 0) < ($1.durationMinutes ?? 0) }
            case .difficulty:
                return workouts.sorted { ($0.difficulty ?? "") > ($1.difficulty ?? "") }
            }
        }
    }
}
