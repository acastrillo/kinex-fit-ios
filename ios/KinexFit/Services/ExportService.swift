import Foundation
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "Export")

/// Export workout data in multiple formats
@MainActor
final class ExportService {
    static let shared = ExportService()

    private let workoutRepository: WorkoutRepository
    private let statsRepository: StatsRepository

    init(
        workoutRepository: WorkoutRepository? = nil,
        statsRepository: StatsRepository? = nil
    ) {
        self.workoutRepository = workoutRepository ?? AppState.shared?.environment.workoutRepository ?? AppEnvironment.preview.workoutRepository
        self.statsRepository = statsRepository ?? .shared
    }

    // MARK: - Export Formats

    enum ExportFormat: String, CaseIterable {
        case json
        case csv
        case pdf

        var fileExtension: String {
            self.rawValue
        }

        var mimeType: String {
            switch self {
            case .json: return "application/json"
            case .csv: return "text/csv"
            case .pdf: return "application/pdf"
            }
        }
    }

    // MARK: - Export Data

    struct ExportPayload: Codable {
        struct DateRange: Codable {
            let start: Date
            let end: Date
        }

        let exportedAt: Date
        let workouts: [Workout]
        let metrics: [BodyMetric]
        let personalRecords: [PersonalRecord]
        let dateRange: DateRange

        enum CodingKeys: String, CodingKey {
            case exportedAt = "exported_at"
            case workouts, metrics
            case personalRecords = "personal_records"
            case dateRange = "date_range"
        }
    }

    // MARK: - Export Methods

    func exportWorkouts(
        format: ExportFormat = .json,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> Data {
        let allWorkouts = try await workoutRepository.fetchAll()
        let workouts = allWorkouts.filter { workout in
            guard workout.isCompleted else { return false }

            if let startDate,
               let completedDate = workout.completedDate,
               let parsed = Self.parseCompletedDate(completedDate),
               parsed < startDate {
                return false
            }

            if let endDate,
               let completedDate = workout.completedDate,
               let parsed = Self.parseCompletedDate(completedDate),
               parsed > endDate {
                return false
            }

            return true
        }

        let metrics = try await statsRepository.getBodyMetrics(
            startDate: startDate,
            endDate: endDate
        )

        let payload = ExportPayload(
            exportedAt: Date(),
            workouts: workouts,
            metrics: metrics,
            personalRecords: [],
            dateRange: .init(start: startDate ?? Date.distantPast, end: endDate ?? Date())
        )

        switch format {
        case .json:
            return try JSONEncoder().encode(payload)
        case .csv:
            return try exportToCSV(payload).data(using: .utf8) ?? Data()
        case .pdf:
            return Data()  // PDF generation would require external library
        }
    }

    private func exportToCSV(_ payload: ExportPayload) -> String {
        var csv = "Date,Exercise,Weight,Reps,Duration,Type\n"

        for workout in payload.workouts {
            let dateStr = workout.completedDate ?? "N/A"
            csv += "\(dateStr),Workout Summary,,,\(workout.durationMinutes ?? 0),completed\n"
        }

        return csv
    }

    private static func parseCompletedDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    // MARK: - Share Export

    func shareExport(format: ExportFormat) async throws {
        let data = try await exportWorkouts(format: format)
        let filename = "kinex-fit-export-\(Date().ISO8601Format()).\(format.fileExtension)"

        logger.info("Export ready: \(filename) (\(data.count) bytes)")
    }
}
