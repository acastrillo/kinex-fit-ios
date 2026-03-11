import Foundation
import GRDB

final class AppDatabase {
    let dbQueue: DatabaseQueue
    static let databaseFileProtection: FileProtectionType = .completeUntilFirstUserAuthentication

    convenience init() throws {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let databaseURL = appSupportURL.appendingPathComponent("kinex-fit.sqlite")
        try self.init(databaseURL: databaseURL, fileManager: fileManager)
    }

    init(databaseURL: URL, fileManager: FileManager = .default) throws {
        try Self.prepareDatabaseFile(at: databaseURL, fileManager: fileManager)
        self.dbQueue = try DatabaseQueue(path: databaseURL.path)
        try DatabaseMigratorFactory().migrate(dbQueue)
        try Self.applyFileProtection(toDatabaseFilesAt: databaseURL, fileManager: fileManager)
    }

    init(dbQueue: DatabaseQueue) throws {
        self.dbQueue = dbQueue
        try DatabaseMigratorFactory().migrate(dbQueue)
    }

    static func inMemory() throws -> AppDatabase {
        let dbQueue = try DatabaseQueue(path: ":memory:")
        return try AppDatabase(dbQueue: dbQueue)
    }

    static func databaseFileURLs(for databaseURL: URL) -> [URL] {
        [
            databaseURL,
            URL(fileURLWithPath: databaseURL.path + "-wal"),
            URL(fileURLWithPath: databaseURL.path + "-shm")
        ]
    }

    static func applyFileProtection(
        toDatabaseFilesAt databaseURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let attributes: [FileAttributeKey: Any] = [
            .protectionKey: databaseFileProtection
        ]

        for fileURL in databaseFileURLs(for: databaseURL) where fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.setAttributes(attributes, ofItemAtPath: fileURL.path)
        }
    }

    private static func prepareDatabaseFile(at databaseURL: URL, fileManager: FileManager) throws {
        try fileManager.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        if !fileManager.fileExists(atPath: databaseURL.path) {
            _ = fileManager.createFile(atPath: databaseURL.path, contents: nil)
        }

        try applyFileProtection(toDatabaseFilesAt: databaseURL, fileManager: fileManager)
    }
}
