import Foundation
import GRDB

/// Workout model representing a saved workout
/// Maps to the `workouts` table in local database
struct Workout: Codable, Equatable, Identifiable, Hashable {
    var id: String
    var title: String
    var content: String?
    /// Immutable source text used as the canonical AI enhancement input.
    var enhancementSourceText: String?
    var source: WorkoutSource
    var durationMinutes: Int?
    var exerciseCount: Int?
    var difficulty: String?
    var imageURL: String?
    var sourceURL: String?
    var sourceAuthor: String?
    /// ISO date (YYYY-MM-DD) used by web scheduling schema.
    var scheduledDate: String?
    /// Optional local-facing schedule time string (legacy/future-safe compatibility).
    var scheduledTime: String?
    /// Web scheduling status (`scheduled`, `completed`, `skipped`).
    var status: WorkoutScheduleStatus?
    /// ISO date (YYYY-MM-DD) when workout was completed.
    var completedDate: String?
    /// ISO timestamp when workout was completed.
    var completedAt: String?
    /// Completion duration in seconds, if tracked by backend.
    var durationSeconds: Int?
    /// Total number of times this workout has been completed.
    var completionCount: Int?
    var createdAt: Date
    var updatedAt: Date

    var isCompleted: Bool {
        status == .completed || completedDate != nil || completedAt != nil
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        content: String? = nil,
        enhancementSourceText: String? = nil,
        source: WorkoutSource = .manual,
        durationMinutes: Int? = nil,
        exerciseCount: Int? = nil,
        difficulty: String? = nil,
        imageURL: String? = nil,
        sourceURL: String? = nil,
        sourceAuthor: String? = nil,
        scheduledDate: String? = nil,
        scheduledTime: String? = nil,
        status: WorkoutScheduleStatus? = nil,
        completedDate: String? = nil,
        completedAt: String? = nil,
        durationSeconds: Int? = nil,
        completionCount: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.enhancementSourceText = enhancementSourceText
        self.source = source
        self.durationMinutes = durationMinutes
        self.exerciseCount = exerciseCount
        self.difficulty = difficulty
        self.imageURL = imageURL
        self.sourceURL = sourceURL
        self.sourceAuthor = sourceAuthor
        self.scheduledDate = scheduledDate
        self.scheduledTime = scheduledTime
        self.status = status
        self.completedDate = completedDate
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
        self.completionCount = completionCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum WorkoutScheduleStatus: String, Codable, CaseIterable {
    case scheduled
    case completed
    case skipped
}

// MARK: - Workout Source

enum WorkoutSource: String, Codable, CaseIterable {
    case manual
    case ocr
    case instagram
    case tiktok
    case imported

    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .ocr: return "Scanned"
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        case .imported: return "Imported"
        }
    }

    var iconName: String {
        switch self {
        case .manual: return "pencil"
        case .ocr: return "doc.text.viewfinder"
        case .instagram: return "camera"
        case .tiktok: return "play.rectangle"
        case .imported: return "square.and.arrow.down"
        }
    }
}

// MARK: - GRDB Conformance

extension Workout: FetchableRecord, PersistableRecord {
    static let databaseTableName = "workouts"

    enum Columns: String, ColumnExpression {
        case id
        case title
        case content
        case enhancementSourceText
        case source
        case durationMinutes
        case exerciseCount
        case difficulty
        case imageURL
        case sourceURL
        case sourceAuthor
        case scheduledDate
        case scheduledTime
        case status
        case completedDate
        case completedAt
        case durationSeconds
        case completionCount
        case createdAt
        case updatedAt
    }

    init(row: Row) {
        id = row[Columns.id]
        title = row[Columns.title]
        content = row[Columns.content]
        enhancementSourceText = row[Columns.enhancementSourceText]
        source = WorkoutSource(rawValue: row[Columns.source] ?? "manual") ?? .manual
        durationMinutes = row[Columns.durationMinutes]
        exerciseCount = row[Columns.exerciseCount]
        difficulty = row[Columns.difficulty]
        imageURL = row[Columns.imageURL]
        sourceURL = row[Columns.sourceURL]
        sourceAuthor = row[Columns.sourceAuthor]
        scheduledDate = row[Columns.scheduledDate]
        scheduledTime = row[Columns.scheduledTime]
        let rawStatus: String? = row[Columns.status]
        status = rawStatus.flatMap(WorkoutScheduleStatus.init(rawValue:))
        completedDate = row[Columns.completedDate]
        completedAt = row[Columns.completedAt]
        durationSeconds = row[Columns.durationSeconds]
        completionCount = row[Columns.completionCount]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
    }

    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.title] = title
        container[Columns.content] = content
        container[Columns.enhancementSourceText] = enhancementSourceText
        container[Columns.source] = source.rawValue
        container[Columns.durationMinutes] = durationMinutes
        container[Columns.exerciseCount] = exerciseCount
        container[Columns.difficulty] = difficulty
        container[Columns.imageURL] = imageURL
        container[Columns.sourceURL] = sourceURL
        container[Columns.sourceAuthor] = sourceAuthor
        container[Columns.scheduledDate] = scheduledDate
        container[Columns.scheduledTime] = scheduledTime
        container[Columns.status] = status?.rawValue
        container[Columns.completedDate] = completedDate
        container[Columns.completedAt] = completedAt
        container[Columns.durationSeconds] = durationSeconds
        container[Columns.completionCount] = completionCount
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
    }
}
