import Foundation
import GRDB

/// Body metric model for tracking weight and other measurements
/// Maps to the `body_metrics` table in local database
struct BodyMetric: Codable, Equatable, Identifiable {
    var id: Int64?
    var date: Date
    var weight: Double?
    var notes: String?
    var updatedAt: Date

    init(
        id: Int64? = nil,
        date: Date = Date(),
        weight: Double? = nil,
        notes: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.weight = weight
        self.notes = notes
        self.updatedAt = updatedAt
    }

    /// Formatted weight string with unit
    var formattedWeight: String? {
        guard let weight else { return nil }
        return String(format: "%.1f lbs", weight)
    }
}

// MARK: - GRDB Conformance

extension BodyMetric: FetchableRecord, PersistableRecord {
    static let databaseTableName = "body_metrics"

    enum Columns: String, ColumnExpression {
        case id, date, weight, notes, updatedAt
    }

    init(row: Row) {
        id = row[Columns.id]
        date = row[Columns.date]
        weight = row[Columns.weight]
        notes = row[Columns.notes]
        updatedAt = row[Columns.updatedAt]
    }

    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.date] = date
        container[Columns.weight] = weight
        container[Columns.notes] = notes
        container[Columns.updatedAt] = updatedAt
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
