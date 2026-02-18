import Foundation
import GRDB
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "SyncEngine")

enum SyncError: Error {
    case unsupportedOperation
    case networkUnavailable
    case authenticationRequired
    case conflict(serverData: String)
    case serverError(String)
    case maxRetriesExceeded
}

final class SyncEngine {
    private let database: AppDatabase
    private let apiClient: APIClient
    private var isSyncing = false

    init(database: AppDatabase, apiClient: APIClient) {
        self.database = database
        self.apiClient = apiClient
    }

    // MARK: - Enqueue Changes

    func enqueueChange(entity: String, operation: String, payload: String?) throws {
        try database.dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO sync_queue (entity, operation, payload, createdAt, retryCount)
                VALUES (?, ?, ?, ?, ?)
                """,
                arguments: [entity, operation, payload, Date(), 0]
            )
        }
        logger.info("Enqueued \(operation) for \(entity)")
    }

    // MARK: - Process Sync Queue

    @MainActor
    func processSyncQueue() async throws {
        guard !isSyncing else {
            logger.info("Sync already in progress, skipping")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        logger.info("Starting sync queue processing")

        let pendingItems = try fetchPendingItems()
        logger.info("Found \(pendingItems.count) pending items to sync")

        for item in pendingItems {
            do {
                try await syncItem(item)
                try markAsProcessed(item.id)
                logger.info("Successfully synced item \(item.id)")
            } catch {
                try handleSyncError(item, error: error)
            }
        }

        logger.info("Sync queue processing complete")
    }

    // MARK: - Sync Individual Item

    private func syncItem(_ item: SyncQueueItem) async throws {
        guard let payloadData = item.payload?.data(using: .utf8),
              let workout = try? JSONDecoder().decode(Workout.self, from: payloadData) else {
            throw SyncError.unsupportedOperation
        }

        let path: String
        let method: HTTPMethod
        let body: Workout

        switch (item.entity, item.operation) {
        case ("workout", "create"):
            path = "/api/mobile/workouts"
            method = .post
            body = workout

        case ("workout", "update"):
            path = "/api/mobile/workouts/\(workout.id)"
            method = .put
            body = workout

        case ("workout", "delete"):
            path = "/api/mobile/workouts/\(workout.id)"
            method = .delete
            body = workout

        default:
            throw SyncError.unsupportedOperation
        }

        // Create request
        let request = try APIRequest.json(path: path, method: method, body: body)

        // Send request
        struct EmptyResponse: Decodable {}
        let _: EmptyResponse = try await apiClient.send(request)
    }

    // MARK: - Error Handling

    private func handleSyncError(_ item: SyncQueueItem, error: Error) throws {
        let retryCount = item.retryCount + 1
        let maxRetries = 5

        // Calculate exponential backoff (1 min, 2 min, 4 min, 8 min, 16 min)
        let backoffSeconds = pow(2.0, Double(retryCount)) * 60.0
        let nextAttempt = Date().addingTimeInterval(backoffSeconds)

        logger.error("Sync error for item \(item.id): \(error.localizedDescription)")

        if retryCount >= maxRetries {
            logger.warning("Max retries exceeded for item \(item.id), marking as failed")
            try markAsFailed(item.id, error: error.localizedDescription)
        } else {
            logger.info("Scheduling retry \(retryCount)/\(maxRetries) for item \(item.id) at \(nextAttempt)")
            try updateRetryInfo(item.id, retryCount: retryCount, nextAttempt: nextAttempt)
        }
    }

    // MARK: - Database Operations

    private func fetchPendingItems() throws -> [SyncQueueItem] {
        try database.dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT id, entity, operation, payload, createdAt, retryCount, lastError, nextAttemptAt
                FROM sync_queue
                WHERE (nextAttemptAt IS NULL OR nextAttemptAt <= ?)
                AND lastError IS NULL
                ORDER BY createdAt ASC
                LIMIT 20
                """,
                arguments: [Date()]
            )

            return rows.compactMap { row in
                guard let id = row["id"] as? Int64,
                      let entity = row["entity"] as? String,
                      let operation = row["operation"] as? String,
                      let createdAt = row["createdAt"] as? Date else {
                    return nil
                }

                return SyncQueueItem(
                    id: id,
                    entity: entity,
                    operation: operation,
                    payload: row["payload"],
                    createdAt: createdAt,
                    retryCount: row["retryCount"] as? Int ?? 0,
                    lastError: row["lastError"],
                    nextAttemptAt: row["nextAttemptAt"] as? Date
                )
            }
        }
    }

    private func markAsProcessed(_ id: Int64) throws {
        try database.dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM sync_queue WHERE id = ?",
                arguments: [id]
            )
        }
    }

    private func markAsFailed(_ id: Int64, error: String) throws {
        try database.dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE sync_queue
                SET lastError = ?, nextAttemptAt = NULL
                WHERE id = ?
                """,
                arguments: [error, id]
            )
        }
    }

    private func updateRetryInfo(_ id: Int64, retryCount: Int, nextAttempt: Date) throws {
        try database.dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE sync_queue
                SET retryCount = ?, nextAttemptAt = ?
                WHERE id = ?
                """,
                arguments: [retryCount, nextAttempt, id]
            )
        }
    }

    // MARK: - Sync Status

    func getPendingCount() throws -> Int {
        try database.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sync_queue WHERE lastError IS NULL") ?? 0
        }
    }

    func getFailedCount() throws -> Int {
        try database.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sync_queue WHERE lastError IS NOT NULL") ?? 0
        }
    }
}

// MARK: - Supporting Types

struct SyncQueueItem {
    let id: Int64
    let entity: String
    let operation: String
    let payload: String?
    let createdAt: Date
    let retryCount: Int
    let lastError: String?
    let nextAttemptAt: Date?
}
