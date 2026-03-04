import Foundation
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "ProgressComparison")

/// Compare progress over time periods
@MainActor
final class ProgressComparisonService {
    static let shared = ProgressComparisonService()

    private let statsRepository: StatsRepository

    init(statsRepository: StatsRepository? = nil) {
        self.statsRepository = statsRepository ?? .shared
    }

    // MARK: - Comparisons

    func compareMetric(
        metric: MetricType,
        period1Start: Date,
        period1End: Date,
        period2Start: Date,
        period2End: Date
    ) async throws -> MetricComparison {
        let value1 = try await getAverageMetric(metric, startDate: period1Start, endDate: period1End)
        let value2 = try await getAverageMetric(metric, startDate: period2Start, endDate: period2End)

        let change = value2 - value1
        let percentChange = value1 > 0 ? (change / value1) * 100 : 0
        let direction: ProgressDirection = change > 0 ? .up : (change < 0 ? .down : .stable)

        return MetricComparison(
            metric: metric,
            period1Value: value1,
            period2Value: value2,
            absoluteChange: change,
            percentChange: percentChange,
            direction: direction
        )
    }

    func compareWeekOverWeek(metric: MetricType) async throws -> MetricComparison {
        let lastWeekEnd = Date()
        let lastWeekStart = Date(timeIntervalSinceNow: -7 * 24 * 3600)

        let twoWeeksStart = Date(timeIntervalSinceNow: -14 * 24 * 3600)
        let twoWeeksEnd = lastWeekStart

        return try await compareMetric(
            metric: metric,
            period1Start: twoWeeksStart,
            period1End: twoWeeksEnd,
            period2Start: lastWeekStart,
            period2End: lastWeekEnd
        )
    }

    func compareMonthOverMonth(metric: MetricType) async throws -> MetricComparison {
        let today = Date()
        let thisMonthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: today))!

        var lastMonthCalendar = Calendar.current
        let lastMonthStart = lastMonthCalendar.date(byAdding: .month, value: -1, to: thisMonthStart)!
        let lastMonthEnd = Calendar.current.date(byAdding: .day, value: -1, to: thisMonthStart)!

        return try await compareMetric(
            metric: metric,
            period1Start: lastMonthStart,
            period1End: lastMonthEnd,
            period2Start: thisMonthStart,
            period2End: today
        )
    }

    // MARK: - Private Methods

    private func getAverageMetric(_ metric: MetricType, startDate: Date, endDate: Date) async throws -> Double {
        // Fetch metrics in range and calculate average
        switch metric {
        case .weight:
            return 185.0  // Example
        case .bodyFat:
            return 18.5
        case .workouts:
            return 5.0
        case .volume:
            return 5000.0
        }
    }

    // MARK: - Models

    enum MetricType: String, CaseIterable {
        case weight, bodyFat, workouts, volume
    }

    enum ProgressDirection: String, CaseIterable {
        case up, down, stable
    }

    struct MetricComparison {
        let metric: MetricType
        let period1Value: Double
        let period2Value: Double
        let absoluteChange: Double
        let percentChange: Double
        let direction: ProgressDirection

        var formattedChange: String {
            let sign = absoluteChange > 0 ? "+" : ""
            return String(format: "%@%.1f (%.1f%%)", sign, absoluteChange, percentChange)
        }
    }
}
