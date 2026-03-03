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
        workoutRepository: WorkoutRepository = AppState.shared?.environment.workoutRepository ?? .preview,
        statsRepository: StatsRepository = .shared
    ) {
        self.workoutRepository = workoutRepository
        self.statsRepository = statsRepository
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
        let exportedAt: Date
        let workouts: [Workout]
        let metrics: [BodyMetric]
        let personalRecords: [PersonalRecord]
        let dateRange: (start: Date, end: Date)

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
        let workouts = try await workoutRepository.getCompletedWorkouts(
            startDate: startDate,
            endDate: endDate
        )

        let metrics = try await statsRepository.getBodyMetrics(
            startDate: startDate,
            endDate: endDate
        )

        let payload = ExportPayload(
            exportedAt: Date(),
            workouts: workouts,
            metrics: metrics,
            personalRecords: [],
            dateRange: (startDate ?? Date.distantPast, endDate ?? Date())
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

    // MARK: - Share Export

    func shareExport(format: ExportFormat) async throws {
        let data = try await exportWorkouts(format: format)
        let filename = "kinex-fit-export-\(Date().ISO8601Format()).\(format.fileExtension)"

        logger.info("Export ready: \(filename) (\(data.count) bytes)")
    }
}
