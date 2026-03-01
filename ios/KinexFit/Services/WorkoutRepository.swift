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

    /// Fetch scheduled workouts from backend and upsert into local storage.
    /// If `date` is provided, backend filters scheduled workouts by YYYY-MM-DD.
    @discardableResult
    func fetchScheduled(date: String? = nil) async throws -> [Workout] {
        let request = APIRequest.getScheduledWorkouts(date: date)
        let response: MobileWorkoutListResponse = try await apiClient.send(request)
        let mappedWorkouts = response.workouts.compactMap(Self.mapRemoteWorkout)
        guard !mappedWorkouts.isEmpty else { return [] }

        try await database.dbQueue.write { db in
            for var workout in mappedWorkouts {
                if workout.completionCount == nil,
                   let existing = try Workout.fetchOne(db, key: workout.id) {
                    workout.completionCount = existing.completionCount
                }
                try workout.save(db)
            }
        }

        return mappedWorkouts.sorted { lhs, rhs in
            lhs.updatedAt > rhs.updatedAt
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

    /// Schedule a workout for a specific date via web scheduling endpoint.
    @discardableResult
    func scheduleWorkout(
        id workoutId: String,
        scheduledDate: String,
        status: WorkoutScheduleStatus = .scheduled
    ) async throws -> Workout? {
        let request = try APIRequest.scheduleWorkout(
            workoutId: workoutId,
            scheduledDate: scheduledDate,
            status: status
        )
        let response: WorkoutScheduleActionResponse = try await apiClient.send(request)

        return try await database.dbQueue.write { db in
            guard var workout = try Workout.fetchOne(db, key: workoutId) else {
                return nil
            }
            workout.scheduledDate = Self.normalizedScheduleDate(response.scheduledDate) ?? scheduledDate
            workout.scheduledTime = Self.normalizedScheduledTime(response.scheduledTime)
                ?? workout.scheduledTime

            let resolvedStatus = response.status
                ?? (response.isCompleted == true ? .completed : status)
            workout.status = resolvedStatus
            if let completionCount = Self.normalizedCompletionCount(response.completionCount) {
                workout.completionCount = completionCount
            } else if resolvedStatus == .completed {
                workout.completionCount = max(workout.completionCount ?? 0, 1)
            }

            if resolvedStatus == .completed {
                workout.completedDate = Self.normalizedScheduleDate(response.completedDate)
                    ?? workout.completedDate
                workout.completedAt = Self.normalizedCompletionTimestamp(response.completedAt)
                    ?? workout.completedAt
                workout.durationSeconds = response.durationSeconds
                    ?? workout.durationSeconds
            } else {
                workout.completedDate = nil
                workout.completedAt = nil
                workout.durationSeconds = nil
            }
            workout.updatedAt = Date()
            try workout.update(db)
            return workout
        }
    }

    /// Unschedule a workout and clear local scheduling metadata.
    @discardableResult
    func unscheduleWorkout(id workoutId: String) async throws -> Workout? {
        let request = APIRequest.unscheduleWorkout(workoutId: workoutId)
        let _: WorkoutScheduleActionResponse = try await apiClient.send(request)

        return try await database.dbQueue.write { db in
            guard var workout = try Workout.fetchOne(db, key: workoutId) else {
                return nil
            }
            workout.scheduledDate = nil
            workout.scheduledTime = nil
            workout.status = nil
            workout.completedDate = nil
            workout.completedAt = nil
            workout.durationSeconds = nil
            workout.updatedAt = Date()
            try workout.update(db)
            return workout
        }
    }

    /// Mark a workout completed via backend completion endpoint and update local scheduling state.
    @discardableResult
    func completeWorkout(
        id workoutId: String,
        completedDate: String? = nil,
        completedAt: String? = nil,
        durationSeconds: Int? = nil
    ) async throws -> Workout? {
        let request = try APIRequest.completeWorkout(
            workoutId: workoutId,
            completedDate: completedDate,
            completedAt: completedAt,
            durationSeconds: durationSeconds
        )
        let response: WorkoutScheduleActionResponse = try await apiClient.send(request)

        return try await database.dbQueue.write { db in
            guard var workout = try Workout.fetchOne(db, key: workoutId) else {
                return nil
            }
            workout.status = response.status ?? .completed
            workout.completedDate = Self.normalizedScheduleDate(response.completedDate)
                ?? Self.normalizedScheduleDate(completedDate)
                ?? workout.completedDate
            workout.completedAt = Self.normalizedCompletionTimestamp(response.completedAt)
                ?? Self.normalizedCompletionTimestamp(completedAt)
                ?? workout.completedAt
            workout.durationSeconds = response.durationSeconds
                ?? durationSeconds
                ?? workout.durationSeconds
            if let completionCount = Self.normalizedCompletionCount(response.completionCount) {
                workout.completionCount = completionCount
            } else {
                workout.completionCount = max(workout.completionCount ?? 0, 1)
            }
            workout.updatedAt = Date()
            try workout.update(db)
            return workout
        }
    }

    // MARK: - Sync Operations

    /// Import workouts from backend and merge into local storage.
    /// Existing local rows with matching IDs are updated in place.
    @discardableResult
    func importFromServer(limit: Int = 100, maxPages: Int = 20) async throws -> Int {
        let cappedLimit = max(1, min(limit, 200))
        let cappedPages = max(1, maxPages)
        var cursor: String?
        var page = 0
        var mergedByID: [String: Workout] = [:]

        repeat {
            let response = try await fetchWorkoutPage(limit: cappedLimit, cursor: cursor)

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
            for var workout in workoutsToUpsert {
                if workout.completionCount == nil,
                   let existing = try Workout.fetchOne(db, key: workout.id) {
                    workout.completionCount = existing.completionCount
                }
                try workout.save(db)
            }
        }

        logger.info("Imported \(workoutsToUpsert.count) workouts from backend")
        return workoutsToUpsert.count
    }

    private func fetchWorkoutPage(limit: Int, cursor: String?) async throws -> MobileWorkoutListResponse {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        let mobileRequest = APIRequest(path: "/api/mobile/workouts", queryItems: queryItems)
        do {
            return try await apiClient.send(mobileRequest)
        } catch let error as APIError {
            guard case .httpStatus(let code, _) = error, (500...599).contains(code) else {
                throw error
            }
            logger.warning("Mobile workouts endpoint failed with \(code); falling back to legacy workouts endpoint")
            let fallbackRequest = APIRequest(path: "/api/workouts")
            return try await apiClient.send(fallbackRequest)
        }
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
                let decoded: [MobileWorkout]? = try? container.decodeIfPresent([MobileWorkout].self, forKey: key)
                if let decoded {
                    return decoded
                }
            }
            return nil
        }

        private static func decodeFirstString(
            in container: KeyedDecodingContainer<CodingKeys>,
            keys: [CodingKeys]
        ) -> String? {
            for key in keys {
                let decoded: String? = try? container.decodeIfPresent(String.self, forKey: key)
                if let decoded {
                    return decoded
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
        let scheduledDate: String?
        let scheduledTime: String?
        let status: String?
        let completedDate: String?
        let completedAt: String?
        let durationSeconds: Int?
        let completionCount: Int?
        let isCompleted: Bool?
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
            case scheduledDate
            case scheduled_date
            case scheduledFor
            case scheduled_for
            case scheduledTime
            case scheduled_time
            case status
            case completedDate
            case completed_date
            case completedAt
            case completed_at
            case durationSeconds
            case duration_seconds
            case completionCount
            case completion_count
            case completionsCount
            case completions_count
            case totalCompletions
            case total_completions
            case timesCompleted
            case times_completed
            case isCompleted
            case is_completed
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
            scheduledDate = Self.decodeFirstString(
                in: container,
                keys: [.scheduledDate, .scheduled_date, .scheduledFor, .scheduled_for]
            )
            scheduledTime = Self.decodeFirstString(
                in: container,
                keys: [.scheduledTime, .scheduled_time]
            )
            status = Self.decodeFirstString(in: container, keys: [.status])
            completedDate = Self.decodeFirstString(
                in: container,
                keys: [.completedDate, .completed_date]
            )
            completedAt = Self.decodeFirstString(
                in: container,
                keys: [.completedAt, .completed_at]
            )
            durationSeconds = Self.decodeFirstInt(
                in: container,
                keys: [.durationSeconds, .duration_seconds]
            )
            completionCount = Self.decodeFirstInt(
                in: container,
                keys: [
                    .completionCount,
                    .completion_count,
                    .completionsCount,
                    .completions_count,
                    .totalCompletions,
                    .total_completions,
                    .timesCompleted,
                    .times_completed
                ]
            )
            isCompleted = Self.decodeFirstBool(
                in: container,
                keys: [.isCompleted, .is_completed]
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
            let stringValue: String? = try? container.decodeIfPresent(String.self, forKey: key)
            if let stringValue {
                return stringValue
            }

            let intValue: Int? = try? container.decodeIfPresent(Int.self, forKey: key)
            if let intValue {
                return String(intValue)
            }

            let doubleValue: Double? = try? container.decodeIfPresent(Double.self, forKey: key)
            if let doubleValue {
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
            let intValue: Int? = try? container.decodeIfPresent(Int.self, forKey: key)
            if let intValue {
                return intValue
            }

            let doubleValue: Double? = try? container.decodeIfPresent(Double.self, forKey: key)
            if let doubleValue {
                return Int(doubleValue.rounded())
            }

            let stringValue: String? = try? container.decodeIfPresent(String.self, forKey: key)
            if let stringValue,
               let parsed = Int(stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return parsed
            }

            return nil
        }

        private static func decodeFirstBool(
            in container: KeyedDecodingContainer<CodingKeys>,
            keys: [CodingKeys]
        ) -> Bool? {
            for key in keys {
                if let value = decodeLossyBool(in: container, key: key) {
                    return value
                }
            }
            return nil
        }

        private static func decodeLossyBool(
            in container: KeyedDecodingContainer<CodingKeys>,
            key: CodingKeys
        ) -> Bool? {
            let boolValue: Bool? = try? container.decodeIfPresent(Bool.self, forKey: key)
            if let boolValue {
                return boolValue
            }

            let intValue: Int? = try? container.decodeIfPresent(Int.self, forKey: key)
            if let intValue {
                return intValue != 0
            }

            let stringValue: String? = try? container.decodeIfPresent(String.self, forKey: key)
            guard let normalized = stringValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                  !normalized.isEmpty else {
                return nil
            }
            switch normalized {
            case "1", "true", "yes", "y":
                return true
            case "0", "false", "no", "n":
                return false
            default:
                return nil
            }
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
        let scheduledDate = normalizedScheduleDate(remote.scheduledDate)
        let scheduledTime = normalizedScheduledTime(remote.scheduledTime)
        let completedAt = normalizedCompletionTimestamp(remote.completedAt)
        let completedDate = normalizedScheduleDate(remote.completedDate) ?? normalizedScheduleDate(completedAt)
        let status = mapRemoteStatus(
            rawStatus: remote.status,
            isCompleted: remote.isCompleted,
            completedDate: completedDate
        )
        let remoteCompletionCount = normalizedCompletionCount(remote.completionCount)
        let hasCompletionMetadata = status == .completed || completedDate != nil || completedAt != nil
        let completionCount = remoteCompletionCount
            ?? (hasCompletionMetadata ? 1 : nil)

        let createdAt = parseISO8601(remote.createdAt) ?? Date()
        let updatedAt = parseISO8601(remote.updatedAt) ?? createdAt

        return Workout(
            id: rawID,
            title: title,
            content: content,
            enhancementSourceText: content,
            source: mapRemoteSource(remote.source),
            durationMinutes: remote.durationMinutes,
            exerciseCount: remote.exerciseCount,
            difficulty: normalizedDifficulty(remote.difficulty),
            imageURL: normalizedImageURL(remote.imageURL),
            scheduledDate: scheduledDate,
            scheduledTime: scheduledTime,
            status: status,
            completedDate: completedDate,
            completedAt: completedAt,
            durationSeconds: remote.durationSeconds,
            completionCount: completionCount,
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
        case WorkoutSource.tiktok.rawValue:
            return .tiktok
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

    private static func normalizedScheduleDate(_ rawDate: String?) -> String? {
        guard let rawDate = rawDate?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawDate.isEmpty else {
            return nil
        }

        if rawDate.count >= 10 {
            let candidate = String(rawDate.prefix(10))
            if isISODateOnly(candidate) {
                return candidate
            }
        }

        if let parsedDate = parseISO8601(rawDate) {
            return isoDateOnlyFormatter.string(from: parsedDate)
        }

        return nil
    }

    private static func normalizedScheduledTime(_ rawTime: String?) -> String? {
        guard let rawTime = rawTime?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawTime.isEmpty else {
            return nil
        }
        return rawTime
    }

    private static func normalizedCompletionTimestamp(_ rawTimestamp: String?) -> String? {
        guard let rawTimestamp = rawTimestamp?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawTimestamp.isEmpty else {
            return nil
        }
        return rawTimestamp
    }

    private static func normalizedCompletionCount(_ rawCount: Int?) -> Int? {
        guard let rawCount, rawCount > 0 else { return nil }
        return rawCount
    }

    private static func mapRemoteStatus(
        rawStatus: String?,
        isCompleted: Bool?,
        completedDate: String?
    ) -> WorkoutScheduleStatus? {
        if let normalized = rawStatus?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           let status = WorkoutScheduleStatus(rawValue: normalized) {
            return status
        }

        if isCompleted == true || completedDate != nil {
            return .completed
        }

        return nil
    }

    private static func isISODateOnly(_ value: String) -> Bool {
        guard value.count == 10 else { return false }
        let scalars = Array(value.unicodeScalars)
        guard scalars.count == 10 else { return false }
        let hyphen = UnicodeScalar(45)!
        return scalars[4] == hyphen
            && scalars[7] == hyphen
            && scalars[0...3].allSatisfy(CharacterSet.decimalDigits.contains)
            && scalars[5...6].allSatisfy(CharacterSet.decimalDigits.contains)
            && scalars[8...9].allSatisfy(CharacterSet.decimalDigits.contains)
    }

    private static let isoDateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
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
