import Foundation
import GRDB

final class AppDatabase {
    let dbQueue: DatabaseQueue

    init() throws {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let databaseURL = appSupportURL.appendingPathComponent("kinex-fit.sqlite")
        self.dbQueue = try DatabaseQueue(path: databaseURL.path)
        try DatabaseMigratorFactory().migrate(dbQueue)
    }

    init(dbQueue: DatabaseQueue) throws {
        self.dbQueue = dbQueue
        try DatabaseMigratorFactory().migrate(dbQueue)
    }

    static func inMemory() throws -> AppDatabase {
        let dbQueue = try DatabaseQueue(path: ":memory:")
        return try AppDatabase(dbQueue: dbQueue)
    }
}
