import Foundation
import GRDB
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "WorkoutRepository")

/// Repository for workout operations
/// Handles local GRDB storage and queues sync operations for the backend
final class WorkoutRepository {
    private let database: AppDatabase
    private let apiClient: APIClient
    private let syncEngine: SyncEngine

    init(database: AppDatabase, apiClient: APIClient, syncEngine: SyncEngine) {
        self.database = database
        self.apiClient = apiClient
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
            let workouts = try Workout
                .order(Workout.Columns.createdAt.desc)
                .fetchAll(db)
            return workouts.map(\.createdAt)
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
        guard !ids.isEmpty else { return }

        let deletedCount = try await database.dbQueue.write { db in
            // Use a single transaction to delete all provided IDs
            try ids.reduce(0) { count, id in
                let deleted = try Workout.deleteOne(db, key: id) ? 1 : 0
                return count + deleted
            }
        }

        if deletedCount > 0 {
            // Queue sync operations for deleted IDs
            for id in ids {
                try queueSync(workoutId: id, operation: .delete)
                logger.info("Deleted workout: \(id)")
            }
        }
    }

    // MARK: - Sync Operations

    /// Import workouts from backend and merge into local storage.
    /// Existing local rows with matching IDs are updated in place.
    @discardableResult
    func importFromServer(limit: Int = 1000, maxPages: Int = 5) async throws -> Int {
        let cappedLimit = max(1, min(limit, 1000))
        let cappedPages = max(1, maxPages)
        var cursor: String?
        var page = 0
        var mergedByID: [String: Workout] = [:]

        repeat {
            var queryItems = [URLQueryItem(name: "limit", value: String(cappedLimit))]
            if let cursor {
                queryItems.append(URLQueryItem(name: "cursor", value: cursor))
            }

            let request = APIRequest(path: "/api/mobile/workouts", queryItems: queryItems)
            let response: MobileWorkoutListResponse = try await apiClient.send(request)

            for remoteWorkout in response.workouts {
                guard let mappedWorkout = Self.mapRemoteWorkout(remoteWorkout) else { continue }

                if let existing = mergedByID[mappedWorkout.id] {
                    mergedByID[mappedWorkout.id] = mappedWorkout.updatedAt >= existing.updatedAt ? mappedWorkout : existing
                } else {
                    mergedByID[mappedWorkout.id] = mappedWorkout
                }
            }

            cursor = response.nextCursor
            page += 1
        } while cursor != nil && page < cappedPages

        if cursor != nil {
            logger.warning("Workout import stopped early after \(page) page(s); backend returned additional cursor data")
        }

        let workoutsToUpsert = Array(mergedByID.values)
        guard !workoutsToUpsert.isEmpty else {
            logger.info("No remote workouts to import")
            return 0
        }

        try await database.dbQueue.write { db in
            for workout in workoutsToUpsert {
                try workout.save(db)
            }
        }

        logger.info("Imported \(workoutsToUpsert.count) workouts from backend")
        return workoutsToUpsert.count
    }

    private enum SyncOperation: String {
        case create
        case update
        case delete
    }

    private func queueSync(workout: Workout, operation: SyncOperation) throws {
        let payloadModel = SyncPayloadV1.createOrUpdate(workout: workout)
        let data = try JSONCoding.apiEncoder().encode(payloadModel)
        guard let payload = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "com.kinex.fit.sync", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode workout payload as UTF-8 string"])
        }
        try syncEngine.enqueueChange(entity: "workout", operation: operation.rawValue, payload: payload)
    }

    private func queueSync(workoutId: String, operation: SyncOperation) throws {
        let payloadModel = SyncPayloadV1.delete(workoutId: workoutId)
        let data = try JSONCoding.apiEncoder().encode(payloadModel)
        guard let payload = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "com.kinex.fit.sync", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode id payload as UTF-8 string"])
        }
        try syncEngine.enqueueChange(entity: "workout", operation: operation.rawValue, payload: payload)
    }

    private struct MobileWorkoutListResponse: Decodable {
        let workouts: [MobileWorkout]
        let nextCursor: String?

        private enum CodingKeys: String, CodingKey {
            case workouts
            case items
            case data
            case nextCursor
            case next_cursor
        }

        init(from decoder: Decoder) throws {
            if var arrayContainer = try? decoder.unkeyedContainer() {
                var decodedWorkouts: [MobileWorkout] = []
                while !arrayContainer.isAtEnd {
                    decodedWorkouts.append(try arrayContainer.decode(MobileWorkout.self))
                }
                workouts = decodedWorkouts
                nextCursor = nil
                return
            }

            let container = try decoder.container(keyedBy: CodingKeys.self)
            workouts = Self.decodeWorkoutArray(
                in: container,
                keys: [.workouts, .items, .data]
            ) ?? []
            nextCursor = Self.decodeFirstString(
                in: container,
                keys: [.nextCursor, .next_cursor]
            )
        }

        private static func decodeWorkoutArray(
            in container: KeyedDecodingContainer<CodingKeys>,
            keys: [CodingKeys]
        ) -> [MobileWorkout]? {
            for key in keys {
                if let value = try? container.decodeIfPresent([MobileWorkout].self, forKey: key),
                   let value {
                    return value
                }
            }
            return nil
        }

        private static func decodeFirstString(
            in container: KeyedDecodingContainer<CodingKeys>,
            keys: [CodingKeys]
        ) -> String? {
            for key in keys {
                if let value = try? container.decodeIfPresent(String.self, forKey: key),
                   let value {
                    return value
                }
            }
            return nil
        }
    }

    private struct MobileWorkout: Decodable {
        let workoutId: String?
        let title: String?
        let description: String?
        let content: String?
        let source: String?
        let durationMinutes: Int?
        let exerciseCount: Int?
        let difficulty: String?
        let imageURL: String?
        let createdAt: String?
        let updatedAt: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case workoutId
            case workout_id
            case title
            case description
            case content
            case source
            case duration
            case durationMinutes
            case duration_minutes
            case totalDuration
            case total_duration
            case exercisesCount
            case exerciseCount
            case exercise_count
            case numberOfExercises
            case number_of_exercises
            case difficulty
            case level
            case image
            case imageUrl
            case image_url
            case imageURL
            case thumbnail
            case thumbnailUrl
            case thumbnail_url
            case coverImage
            case cover_image
            case createdAt
            case created_at
            case updatedAt
            case updated_at
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            workoutId = Self.decodeFirstString(
                in: container,
                keys: [.workoutId, .workout_id, .id]
            )
            title = Self.decodeFirstString(in: container, keys: [.title])
            description = Self.decodeFirstString(in: container, keys: [.description])
            content = Self.decodeFirstString(in: container, keys: [.content])
            source = Self.decodeFirstString(in: container, keys: [.source])
            durationMinutes = Self.decodeFirstInt(
                in: container,
                keys: [.durationMinutes, .duration_minutes, .duration, .totalDuration, .total_duration]
            )
            exerciseCount = Self.decodeFirstInt(
                in: container,
                keys: [.exerciseCount, .exercise_count, .exercisesCount, .numberOfExercises, .number_of_exercises]
            )
            difficulty = Self.decodeFirstString(in: container, keys: [.difficulty, .level])
            imageURL = Self.decodeFirstString(
                in: container,
                keys: [.imageURL, .imageUrl, .image_url, .image, .thumbnailUrl, .thumbnail_url, .thumbnail, .coverImage, .cover_image]
            )
            createdAt = Self.decodeFirstString(in: container, keys: [.createdAt, .created_at])
            updatedAt = Self.decodeFirstString(in: container, keys: [.updatedAt, .updated_at])
        }

        private static func decodeFirstString(
            in container: KeyedDecodingContainer<CodingKeys>,
            keys: [CodingKeys]
        ) -> String? {
            for key in keys {
                if let value = decodeLossyString(in: container, key: key) {
                    return value
                }
            }
            return nil
        }

        private static func decodeLossyString(
            in container: KeyedDecodingContainer<CodingKeys>,
            key: CodingKeys
        ) -> String? {
            if let stringValue = try? container.decodeIfPresent(String.self, forKey: key),
               let stringValue {
                return stringValue
            }
            if let intValue = try? container.decodeIfPresent(Int.self, forKey: key),
               let intValue {
                return String(intValue)
            }
            if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key),
               let doubleValue {
                return String(doubleValue)
            }
            return nil
        }

        private static func decodeFirstInt(
            in container: KeyedDecodingContainer<CodingKeys>,
            keys: [CodingKeys]
        ) -> Int? {
            for key in keys {
                if let value = decodeLossyInt(in: container, key: key) {
                    return value
                }
            }
            return nil
        }

        private static func decodeLossyInt(
            in container: KeyedDecodingContainer<CodingKeys>,
            key: CodingKeys
        ) -> Int? {
            if let intValue = try? container.decodeIfPresent(Int.self, forKey: key),
               let intValue {
                return intValue
            }

            if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key),
               let doubleValue {
                return Int(doubleValue.rounded())
            }

            if let stringValue = try? container.decodeIfPresent(String.self, forKey: key),
               let stringValue,
               let parsed = Int(stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return parsed
            }

            return nil
        }
    }

    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601WithoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func mapRemoteWorkout(_ remote: MobileWorkout) -> Workout? {
        guard let rawID = remote.workoutId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawID.isEmpty else {
            return nil
        }

        let normalizedTitle = (remote.title ?? remote.description ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title = normalizedTitle.isEmpty ? "Untitled Workout" : normalizedTitle

        let normalizedContent = remote.content?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDescription = remote.description?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let content = (normalizedContent?.isEmpty == false ? normalizedContent : normalizedDescription)

        let createdAt = parseISO8601(remote.createdAt) ?? Date()
        let updatedAt = parseISO8601(remote.updatedAt) ?? createdAt

        return Workout(
            id: rawID,
            title: title,
            content: content,
            source: mapRemoteSource(remote.source),
            durationMinutes: remote.durationMinutes,
            exerciseCount: remote.exerciseCount,
            difficulty: normalizedDifficulty(remote.difficulty),
            imageURL: normalizedImageURL(remote.imageURL),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func parseISO8601(_ value: String?) -> Date? {
        guard let value else { return nil }
        return iso8601WithFractionalSeconds.date(from: value)
            ?? iso8601WithoutFractionalSeconds.date(from: value)
    }

    private static func mapRemoteSource(_ rawSource: String?) -> WorkoutSource {
        switch rawSource?.lowercased() {
        case WorkoutSource.ocr.rawValue:
            return .ocr
        case WorkoutSource.instagram.rawValue:
            return .instagram
        case WorkoutSource.imported.rawValue, "ai":
            return .imported
        case WorkoutSource.manual.rawValue:
            return .manual
        default:
            return .manual
        }
    }

    private static func normalizedDifficulty(_ rawDifficulty: String?) -> String? {
        guard let rawDifficulty = rawDifficulty?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawDifficulty.isEmpty else {
            return nil
        }
        return rawDifficulty.lowercased()
    }

    private static func normalizedImageURL(_ rawURL: String?) -> String? {
        guard let rawURL = rawURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawURL.isEmpty else {
            return nil
        }
        return rawURL
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
