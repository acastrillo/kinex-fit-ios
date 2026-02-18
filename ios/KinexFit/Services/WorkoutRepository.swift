import Foundation
import GRDB
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "WorkoutRepository")

/// Repository for workout operations
/// Handles local GRDB storage and queues sync operations for the backend
final class WorkoutRepository {
    private let database: AppDatabase
    private let syncEngine: SyncEngine

    init(database: AppDatabase, syncEngine: SyncEngine) {
        self.database = database
        self.syncEngine = syncEngine
    }

    // MARK: - Read Operations

    /// Fetch all workouts, sorted by most recent first
    func fetchAll() async throws -> [Workout] {
        try await database.dbQueue.read { db in
            try Workout
                .order(Workout.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }

    /// Fetch a single workout by ID
    func fetch(id: String) async throws -> Workout? {
        try await database.dbQueue.read { db in
            try Workout.fetchOne(db, key: id)
        }
    }

    /// Fetch workouts matching a search query
    func search(query: String) async throws -> [Workout] {
        let pattern = "%\(query)%"
        return try await database.dbQueue.read { db in
            try Workout
                .filter(
                    Workout.Columns.title.like(pattern) ||
                    Workout.Columns.content.like(pattern)
                )
                .order(Workout.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }

    /// Count total workouts
    func count() async throws -> Int {
        try await database.dbQueue.read { db in
            try Workout.fetchCount(db)
        }
    }

    /// Count workouts since a specific date
    func countWorkouts(since date: Date) async throws -> Int {
        try await database.dbQueue.read { db in
            try Workout
                .filter(Workout.Columns.createdAt >= date)
                .fetchCount(db)
        }
    }

    /// Get all workout dates (for streak calculation)
    func getWorkoutDates() async throws -> [Date] {
        try await database.dbQueue.read { db in
            try Workout
                .select(Workout.Columns.createdAt)
                .order(Workout.Columns.createdAt.desc)
                .fetchAll(db)
                .map { $0.createdAt }
        }
    }

    // MARK: - Write Operations

    /// Create a new workout
    @discardableResult
    func create(_ workout: Workout) async throws -> Workout {
        var workoutToSave = workout
        workoutToSave.createdAt = Date()
        workoutToSave.updatedAt = Date()

        // Capture final value before concurrent closure to avoid data race
        let finalWorkout = workoutToSave

        try await database.dbQueue.write { db in
            try finalWorkout.insert(db)
        }

        // Queue for sync
        try queueSync(workout: finalWorkout, operation: .create)

        logger.info("Created workout: \(finalWorkout.id)")
        return finalWorkout
    }

    /// Update an existing workout
    @discardableResult
    func update(_ workout: Workout) async throws -> Workout {
        var workoutToSave = workout
        workoutToSave.updatedAt = Date()

        // Capture final value before concurrent closure to avoid data race
        let finalWorkout = workoutToSave

        try await database.dbQueue.write { db in
            try finalWorkout.update(db)
        }

        // Queue for sync
        try queueSync(workout: finalWorkout, operation: .update)

        logger.info("Updated workout: \(finalWorkout.id)")
        return finalWorkout
    }

    /// Delete a workout
    func delete(id: String) async throws {
        let deleted = try await database.dbQueue.write { db in
            try Workout.deleteOne(db, key: id)
        }

        if deleted {
            // Queue for sync
            try queueSync(workoutId: id, operation: .delete)
            logger.info("Deleted workout: \(id)")
        }
    }

    /// Delete multiple workouts
    func delete(ids: [String]) async throws {
        for id in ids {
            try await delete(id: id)
        }
    }

    // MARK: - Sync Operations

    private enum SyncOperation: String {
        case create
        case update
        case delete
    }

    private func queueSync(workout: Workout, operation: SyncOperation) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = try String(data: encoder.encode(workout), encoding: .utf8)
        try syncEngine.enqueueChange(entity: "workout", operation: operation.rawValue, payload: payload)
    }

    private func queueSync(workoutId: String, operation: SyncOperation) throws {
        let payload = "{\"id\":\"\(workoutId)\"}"
        try syncEngine.enqueueChange(entity: "workout", operation: operation.rawValue, payload: payload)
    }
}

// MARK: - Observation Support

extension WorkoutRepository {
    /// Observe all workouts for changes
    /// Returns an AsyncThrowingStream that emits whenever workouts change
    func observeAll() -> AsyncThrowingStream<[Workout], Error> {
        AsyncThrowingStream { continuation in
            let observation = ValueObservation.tracking { db in
                try Workout
                    .order(Workout.Columns.createdAt.desc)
                    .fetchAll(db)
            }

            let cancellable = observation.start(
                in: database.dbQueue,
                scheduling: .immediate,
                onError: { error in
                    continuation.finish(throwing: error)
                },
                onChange: { workouts in
                    continuation.yield(workouts)
                }
            )

            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }

    /// Observe a single workout for changes
    func observe(id: String) -> AsyncThrowingStream<Workout?, Error> {
        AsyncThrowingStream { continuation in
            let observation = ValueObservation.tracking { db in
                try Workout.fetchOne(db, key: id)
            }

            let cancellable = observation.start(
                in: database.dbQueue,
                scheduling: .immediate,
                onError: { error in
                    continuation.finish(throwing: error)
                },
                onChange: { workout in
                    continuation.yield(workout)
                }
            )

            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }
}
