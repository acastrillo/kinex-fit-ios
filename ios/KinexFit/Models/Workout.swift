import Foundation
import GRDB

/// Workout model representing a saved workout
/// Maps to the `workouts` table in local database
struct Workout: Codable, Equatable, Identifiable, Hashable {
    var id: String
    var title: String
    var content: String?
    var source: WorkoutSource
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        content: String? = nil,
        source: WorkoutSource = .manual,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Workout Source

enum WorkoutSource: String, Codable, CaseIterable {
    case manual
    case ocr
    case instagram
    case imported

    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .ocr: return "Scanned"
        case .instagram: return "Instagram"
        case .imported: return "Imported"
        }
    }

    var iconName: String {
        switch self {
        case .manual: return "pencil"
        case .ocr: return "doc.text.viewfinder"
        case .instagram: return "camera"
        case .imported: return "square.and.arrow.down"
        }
    }
}

// MARK: - GRDB Conformance

extension Workout: FetchableRecord, PersistableRecord {
    static let databaseTableName = "workouts"

    enum Columns: String, ColumnExpression {
        case id, title, content, source, createdAt, updatedAt
    }

    init(row: Row) {
        id = row[Columns.id]
        title = row[Columns.title]
        content = row[Columns.content]
        source = WorkoutSource(rawValue: row[Columns.source] ?? "manual") ?? .manual
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
    }

    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.title] = title
        container[Columns.content] = content
        container[Columns.source] = source.rawValue
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
    }
}
