import Foundation

// MARK: - Instagram Fetch Response

/// Response from `/api/instagram-fetch` endpoint
struct InstagramFetchResponse: Decodable {
    let url: String
    let title: String
    let content: String
    let author: AuthorInfo?
    let stats: PostStats?
    let image: String?
    let timestamp: String
    let mediaType: String?
    let parsedWorkout: ParsedWorkoutData?
    let scanQuotaUsed: Int?
    let scanQuotaLimit: Int?
    let quotaUsed: Int?
    let quotaLimit: Int?

    init(
        url: String,
        title: String,
        content: String,
        author: AuthorInfo?,
        stats: PostStats?,
        image: String?,
        timestamp: String,
        mediaType: String?,
        parsedWorkout: ParsedWorkoutData?,
        scanQuotaUsed: Int?,
        scanQuotaLimit: Int?,
        quotaUsed: Int?,
        quotaLimit: Int?
    ) {
        self.url = url
        self.title = title
        self.content = content
        self.author = author
        self.stats = stats
        self.image = image
        self.timestamp = timestamp
        self.mediaType = mediaType
        self.parsedWorkout = parsedWorkout
        self.scanQuotaUsed = scanQuotaUsed
        self.scanQuotaLimit = scanQuotaLimit
        self.quotaUsed = quotaUsed
        self.quotaLimit = quotaLimit
    }

    fileprivate enum CodingKeys: String, CodingKey {
        case url
        case sourceURL
        case sourceUrl
        case source_url
        case title
        case content
        case caption
        case description
        case text
        case author
        case username
        case authorUsername
        case author_username
        case authorName
        case author_name
        case fullName
        case full_name
        case stats
        case likes
        case likesCount
        case comments
        case commentsCount
        case image
        case imageUrl
        case image_url
        case imageURL
        case thumbnail
        case thumbnailUrl
        case thumbnail_url
        case coverImage
        case cover_image
        case timestamp
        case createdAt
        case created_at
        case mediaType
        case media_type
        case type
        case parsedWorkout
        case parsed_workout
        case workout
        case scanQuotaUsed
        case scan_quota_used
        case scanQuotaLimit
        case scan_quota_limit
        case quotaUsed
        case quota_used
        case quotaLimit
        case quota_limit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        url = container.decodeFirstString(forKeys: [.url, .sourceURL, .sourceUrl, .source_url]) ?? ""
        title = container.decodeFirstString(forKeys: [.title]) ?? ""
        content = container.decodeFirstString(forKeys: [.content, .caption, .description, .text]) ?? ""

        let topLevelAuthorUsername = container.decodeFirstString(
            forKeys: [.authorUsername, .author_username, .username]
        )
        let topLevelAuthorName = container.decodeFirstString(
            forKeys: [.authorName, .author_name, .fullName, .full_name]
        )
        author =
            container.decodeFirstDecodable(AuthorInfo.self, forKeys: [.author])
            ?? AuthorInfo.makeFallback(username: topLevelAuthorUsername, fullName: topLevelAuthorName)

        let topLevelLikes = container.decodeFirstInt(forKeys: [.likes, .likesCount])
        let topLevelComments = container.decodeFirstInt(forKeys: [.comments, .commentsCount])
        stats =
            container.decodeFirstDecodable(PostStats.self, forKeys: [.stats])
            ?? PostStats.makeFallback(likes: topLevelLikes, comments: topLevelComments)

        image = container.decodeFirstString(
            forKeys: [
                .image,
                .imageURL,
                .imageUrl,
                .image_url,
                .thumbnail,
                .thumbnailUrl,
                .thumbnail_url,
                .coverImage,
                .cover_image
            ]
        )
        timestamp = container.decodeFirstString(forKeys: [.timestamp, .createdAt, .created_at])
            ?? ISO8601DateFormatter().string(from: Date())
        mediaType = container.decodeFirstString(forKeys: [.mediaType, .media_type, .type])
        parsedWorkout = container.decodeFirstDecodable(
            ParsedWorkoutData.self,
            forKeys: [.parsedWorkout, .parsed_workout, .workout]
        )
        scanQuotaUsed = container.decodeFirstInt(forKeys: [.scanQuotaUsed, .scan_quota_used])
        scanQuotaLimit = container.decodeFirstInt(forKeys: [.scanQuotaLimit, .scan_quota_limit])
        quotaUsed = container.decodeFirstInt(forKeys: [.quotaUsed, .quota_used])
        quotaLimit = container.decodeFirstInt(forKeys: [.quotaLimit, .quota_limit])
    }
}

/// Author information from Instagram post
struct AuthorInfo: Decodable {
    let username: String
    let fullName: String?

    init(username: String, fullName: String?) {
        self.username = username
        self.fullName = fullName
    }

    private enum CodingKeys: String, CodingKey {
        case username
        case userName
        case user_name
        case fullName
        case full_name
        case name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedFullName = container.decodeFirstString(forKeys: [.fullName, .full_name, .name])
        let decodedUsername = container.decodeFirstString(forKeys: [.username, .userName, .user_name])
            ?? Self.usernameFallback(from: decodedFullName)

        username = decodedUsername?.trimmedNonEmpty ?? "unknown"
        fullName = decodedFullName?.trimmedNonEmpty
    }

    fileprivate static func makeFallback(username: String?, fullName: String?) -> AuthorInfo? {
        let resolvedFullName = fullName?.trimmedNonEmpty
        let resolvedUsername = username?.trimmedNonEmpty ?? usernameFallback(from: resolvedFullName)
        guard let resolvedUsername else { return nil }
        return AuthorInfo(username: resolvedUsername, fullName: resolvedFullName)
    }

    private static func usernameFallback(from fullName: String?) -> String? {
        fullName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
            .trimmedNonEmpty
    }
}

/// Post statistics
struct PostStats: Decodable {
    let likes: Int?
    let comments: Int?

    init(likes: Int?, comments: Int?) {
        self.likes = likes
        self.comments = comments
    }

    private enum CodingKeys: String, CodingKey {
        case likes
        case likesCount
        case comments
        case commentsCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        likes = container.decodeFirstInt(forKeys: [.likes, .likesCount])
        comments = container.decodeFirstInt(forKeys: [.comments, .commentsCount])
    }

    fileprivate static func makeFallback(likes: Int?, comments: Int?) -> PostStats? {
        guard likes != nil || comments != nil else { return nil }
        return PostStats(likes: likes, comments: comments)
    }
}

/// Parsed workout data from Instagram caption
struct ParsedWorkoutData: Decodable {
    let title: String?
    let workoutType: String?
    let exercises: [ExerciseData]?
    let summary: String?
    let breakdown: [String]?
    let structure: WorkoutStructure?
    let usedLLM: Bool?

    init(
        title: String?,
        workoutType: String?,
        exercises: [ExerciseData]?,
        summary: String?,
        breakdown: [String]?,
        structure: WorkoutStructure?,
        usedLLM: Bool?
    ) {
        self.title = title
        self.workoutType = workoutType
        self.exercises = exercises
        self.summary = summary
        self.breakdown = breakdown
        self.structure = structure
        self.usedLLM = usedLLM
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case workoutType
        case workout_type
        case exercises
        case rows
        case summary
        case breakdown
        case structure
        case usedLLM
        case used_llm
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedRows = container.decodeFirstDecodable([WorkoutRow].self, forKeys: [.rows])

        title = container.decodeFirstString(forKeys: [.title])?.trimmedNonEmpty
        workoutType = container.decodeFirstString(forKeys: [.workoutType, .workout_type])?.trimmedNonEmpty
        exercises =
            container.decodeFirstDecodable([ExerciseData].self, forKeys: [.exercises])
            ?? decodedRows?.map(\.asExerciseData)
        summary = container.decodeFirstString(forKeys: [.summary])?.trimmedNonEmpty
        breakdown = container.decodeFirstStringArray(forKeys: [.breakdown])
        structure = container.decodeFirstDecodable(WorkoutStructure.self, forKeys: [.structure])
        usedLLM = container.decodeFirstBool(forKeys: [.usedLLM, .used_llm])
    }
}

// MARK: - Workout Ingest Response

/// Response from `/api/ingest` endpoint
struct WorkoutIngestResponse: Decodable {
    let title: String?
    let workoutType: String?
    let exercises: [ExerciseData]
    let rows: [WorkoutRow]?  // Backward compatibility
    let summary: String?
    let breakdown: [String]?
    let structure: WorkoutStructure?
    let amrapBlocks: [AMRAPBlock]?
    let emomBlocks: [EMOMBlock]?
    let usedLLM: Bool?
    let workoutV1: WorkoutV1?

    init(
        title: String?,
        workoutType: String?,
        exercises: [ExerciseData],
        rows: [WorkoutRow]?,
        summary: String?,
        breakdown: [String]?,
        structure: WorkoutStructure?,
        amrapBlocks: [AMRAPBlock]?,
        emomBlocks: [EMOMBlock]?,
        usedLLM: Bool?,
        workoutV1: WorkoutV1?
    ) {
        self.title = title
        self.workoutType = workoutType
        self.exercises = exercises
        self.rows = rows
        self.summary = summary
        self.breakdown = breakdown
        self.structure = structure
        self.amrapBlocks = amrapBlocks
        self.emomBlocks = emomBlocks
        self.usedLLM = usedLLM
        self.workoutV1 = workoutV1
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case workoutType
        case workout_type
        case exercises
        case rows
        case summary
        case breakdown
        case structure
        case amrapBlocks
        case amrap_blocks
        case emomBlocks
        case emom_blocks
        case usedLLM
        case used_llm
        case workoutV1
        case workout_v1
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedRows = container.decodeFirstDecodable([WorkoutRow].self, forKeys: [.rows])

        title = container.decodeFirstString(forKeys: [.title])?.trimmedNonEmpty
        workoutType = container.decodeFirstString(forKeys: [.workoutType, .workout_type])?.trimmedNonEmpty
        exercises =
            container.decodeFirstDecodable([ExerciseData].self, forKeys: [.exercises])
            ?? decodedRows?.map(\.asExerciseData)
            ?? []
        rows = decodedRows
        summary = container.decodeFirstString(forKeys: [.summary])?.trimmedNonEmpty
        breakdown = container.decodeFirstStringArray(forKeys: [.breakdown])
        structure = container.decodeFirstDecodable(WorkoutStructure.self, forKeys: [.structure])
        amrapBlocks = container.decodeFirstDecodable([AMRAPBlock].self, forKeys: [.amrapBlocks, .amrap_blocks])
        emomBlocks = container.decodeFirstDecodable([EMOMBlock].self, forKeys: [.emomBlocks, .emom_blocks])
        usedLLM = container.decodeFirstBool(forKeys: [.usedLLM, .used_llm])
        workoutV1 = container.decodeFirstDecodable(WorkoutV1.self, forKeys: [.workoutV1, .workout_v1])
    }
}

/// Exercise data
struct ExerciseData: Decodable, Identifiable {
    let id: String?
    let name: String
    let sets: Int?
    let reps: String?
    let weight: String?
    let unit: String?
    let notes: String?
    let restSeconds: Int?

    init(
        id: String?,
        name: String,
        sets: Int?,
        reps: String?,
        weight: String?,
        unit: String?,
        notes: String?,
        restSeconds: Int?
    ) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.unit = unit
        self.notes = notes
        self.restSeconds = restSeconds
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case exerciseId
        case exercise_id
        case name
        case exercise
        case title
        case exerciseName
        case exercise_name
        case sets
        case reps
        case weight
        case unit
        case notes
        case restSeconds
        case rest_seconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFirstString(forKeys: [.id, .exerciseId, .exercise_id])?.trimmedNonEmpty
        name = container.decodeFirstString(
            forKeys: [.name, .exercise, .title, .exerciseName, .exercise_name]
        )?.trimmedNonEmpty ?? ""
        sets = container.decodeFirstInt(forKeys: [.sets])
        reps = container.decodeFirstString(forKeys: [.reps])?.trimmedNonEmpty
        weight = container.decodeFirstString(forKeys: [.weight])?.trimmedNonEmpty
        unit = container.decodeFirstString(forKeys: [.unit])?.trimmedNonEmpty
        notes = container.decodeFirstString(forKeys: [.notes])?.trimmedNonEmpty
        restSeconds = container.decodeFirstInt(forKeys: [.restSeconds, .rest_seconds])
    }

    // Computed ID for SwiftUI compatibility
    var exerciseId: String {
        id ?? UUID().uuidString
    }
}

/// Workout row (legacy format)
struct WorkoutRow: Decodable {
    let exercise: String
    let sets: Int?
    let reps: String?
    let weight: String?
    let notes: String?

    init(exercise: String, sets: Int?, reps: String?, weight: String?, notes: String?) {
        self.exercise = exercise
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case exercise
        case name
        case title
        case sets
        case reps
        case weight
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exercise = container.decodeFirstString(forKeys: [.exercise, .name, .title])?.trimmedNonEmpty ?? ""
        sets = container.decodeFirstInt(forKeys: [.sets])
        reps = container.decodeFirstString(forKeys: [.reps])?.trimmedNonEmpty
        weight = container.decodeFirstString(forKeys: [.weight])?.trimmedNonEmpty
        notes = container.decodeFirstString(forKeys: [.notes])?.trimmedNonEmpty
    }
}

/// Workout structure information
struct WorkoutStructure: Decodable {
    let type: String?  // "standard", "amrap", "emom", "rounds", "ladder", "tabata"
    let timeLimit: String?
    let rounds: Int?
    let interval: String?
    let work: String?
    let rest: String?

    init(type: String?, timeLimit: String?, rounds: Int?, interval: String?, work: String?, rest: String?) {
        self.type = type
        self.timeLimit = timeLimit
        self.rounds = rounds
        self.interval = interval
        self.work = work
        self.rest = rest
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case timeLimit
        case time_limit
        case rounds
        case interval
        case work
        case rest
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = container.decodeFirstString(forKeys: [.type])?.trimmedNonEmpty
        timeLimit = container.decodeFirstString(forKeys: [.timeLimit, .time_limit])?.trimmedNonEmpty
        rounds = container.decodeFirstInt(forKeys: [.rounds])
        interval = container.decodeFirstString(forKeys: [.interval])?.trimmedNonEmpty
        work = container.decodeFirstString(forKeys: [.work])?.trimmedNonEmpty
        rest = container.decodeFirstString(forKeys: [.rest])?.trimmedNonEmpty
    }
}

/// AMRAP block
struct AMRAPBlock: Decodable, Identifiable {
    let id: String?
    let timeLimit: String?
    let exercises: [ExerciseData]

    init(id: String?, timeLimit: String?, exercises: [ExerciseData]) {
        self.id = id
        self.timeLimit = timeLimit
        self.exercises = exercises
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case blockId
        case block_id
        case timeLimit
        case time_limit
        case exercises
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFirstString(forKeys: [.id, .blockId, .block_id])?.trimmedNonEmpty
        timeLimit = container.decodeFirstString(forKeys: [.timeLimit, .time_limit])?.trimmedNonEmpty
        exercises = container.decodeFirstDecodable([ExerciseData].self, forKeys: [.exercises]) ?? []
    }

    var blockId: String {
        id ?? UUID().uuidString
    }
}

/// EMOM block
struct EMOMBlock: Decodable, Identifiable {
    let id: String?
    let interval: String?
    let exercises: [ExerciseData]

    init(id: String?, interval: String?, exercises: [ExerciseData]) {
        self.id = id
        self.interval = interval
        self.exercises = exercises
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case blockId
        case block_id
        case interval
        case exercises
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFirstString(forKeys: [.id, .blockId, .block_id])?.trimmedNonEmpty
        interval = container.decodeFirstString(forKeys: [.interval])?.trimmedNonEmpty
        exercises = container.decodeFirstDecodable([ExerciseData].self, forKeys: [.exercises]) ?? []
    }

    var blockId: String {
        id ?? UUID().uuidString
    }
}

/// Workout V1 metadata (legacy)
struct WorkoutV1: Decodable {
    let name: String?
    let totalDuration: Int?
    let difficulty: String?
    let tags: [String]?

    init(name: String?, totalDuration: Int?, difficulty: String?, tags: [String]?) {
        self.name = name
        self.totalDuration = totalDuration
        self.difficulty = difficulty
        self.tags = tags
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case totalDuration
        case total_duration
        case difficulty
        case tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decodeFirstString(forKeys: [.name])?.trimmedNonEmpty
        totalDuration = container.decodeFirstInt(forKeys: [.totalDuration, .total_duration])
        difficulty = container.decodeFirstString(forKeys: [.difficulty])?.trimmedNonEmpty
        tags = container.decodeFirstStringArray(forKeys: [.tags])
    }
}

// MARK: - Social Platform Detection

/// Identifies the source social media platform from a URL
enum SocialPlatform: String, Codable {
    case instagram
    case tiktok
    case unknown

    var displayName: String {
        switch self {
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        case .unknown: return "Social Media"
        }
    }

    var iconName: String {
        switch self {
        case .instagram: return "camera.on.rectangle"
        case .tiktok: return "play.rectangle"
        case .unknown: return "link"
        }
    }

    var iconColor: String {
        switch self {
        case .instagram: return "pink"
        case .tiktok: return "cyan"
        case .unknown: return "blue"
        }
    }

    var workoutSource: WorkoutSource {
        switch self {
        case .instagram: return .instagram
        case .tiktok: return .tiktok
        case .unknown: return .imported
        }
    }

    /// Detect platform from a URL string
    static func detect(from url: String) -> SocialPlatform {
        let lowered = url.lowercased()
        if lowered.contains("instagram.com") || lowered.contains("instagr.am") {
            return .instagram
        }
        if lowered.contains("tiktok.com") {
            return .tiktok
        }
        return .unknown
    }
}

// MARK: - Fetched Workout (UI Model)

/// Combined model for UI consumption
struct FetchedWorkout: Identifiable {
    let id: String = UUID().uuidString
    let title: String
    let content: String
    let author: AuthorInfo?
    let imageURL: String?
    let parsedData: WorkoutIngestResponse
    let sourceURL: String
    let sourcePlatform: SocialPlatform
    let quotaUsed: Int?
    let quotaLimit: Int?
    let timestamp: Date

    /// Create from fetch response
    init(from fetchResponse: InstagramFetchResponse, ingestResponse: WorkoutIngestResponse) {
        self.title = ingestResponse.title ?? fetchResponse.title
        self.content = fetchResponse.content
        self.author = fetchResponse.author
        self.imageURL = fetchResponse.image
        self.parsedData = ingestResponse
        self.sourceURL = fetchResponse.url
        self.sourcePlatform = SocialPlatform.detect(from: fetchResponse.url)
        self.quotaUsed = fetchResponse.scanQuotaUsed ?? fetchResponse.quotaUsed
        self.quotaLimit = fetchResponse.scanQuotaLimit ?? fetchResponse.quotaLimit
        self.timestamp = Self.parseTimestamp(fetchResponse.timestamp)
    }

    /// Convenience computed properties
    var exerciseCount: Int {
        parsedData.previewExercises.count
    }

    var workoutType: String {
        parsedData.workoutType?.capitalized ?? "Standard"
    }

    var hasQuotaInfo: Bool {
        quotaUsed != nil && quotaLimit != nil
    }

    var authorName: String {
        author?.fullName ?? author?.username ?? "Unknown"
    }

    var shortContent: String {
        if content.count > 100 {
            return String(content.prefix(97)) + "..."
        }
        return content
    }

    private static func parseTimestamp(_ rawValue: String) -> Date {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let isoDate = ISO8601DateFormatter().date(from: trimmed) {
            return isoDate
        }
        if let epochValue = Double(trimmed) {
            let seconds = epochValue > 10_000_000_000 ? epochValue / 1000 : epochValue
            return Date(timeIntervalSince1970: seconds)
        }
        return Date()
    }
}

extension FetchedWorkout {
    var onboardingPreview: CaptionParsedWorkout {
        let previewExercises = parsedData.previewExercises.enumerated().map { index, exercise in
            let normalizedName = exercise.name.trimmedNonEmpty ?? "Exercise \(index + 1)"
            let repValue = SocialImportRepValueParser.parse(exercise.reps)

            return CaptionParsedExercise(
                kinexExerciseID: exercise.id?.trimmedNonEmpty,
                exerciseName: normalizedName,
                rawName: normalizedName,
                sets: exercise.sets,
                reps: repValue.reps,
                duration: repValue.duration,
                restAfter: exercise.restSeconds.map { "\($0)s" } ?? parsedData.structure?.rest?.trimmedNonEmpty,
                notes: exercise.notes?.trimmedNonEmpty,
                position: index + 1,
                match: .exact(kinexExerciseID: exercise.id?.trimmedNonEmpty)
            )
        }

        let normalizedSourceURL = sourceURL.trimmedNonEmpty
        let normalizedTitle =
            title.trimmedNonEmpty
            ?? parsedData.title?.trimmedNonEmpty
            ?? "\(sourcePlatform.displayName) Workout"
        let normalizedNotes =
            parsedData.summary?.trimmedNonEmpty
            ?? content.trimmedNonEmpty

        return CaptionParsedWorkout(
            sourceType: sourcePlatform.workoutSource,
            sourceURL: normalizedSourceURL,
            title: normalizedTitle,
            exercises: previewExercises,
            restBetweenSets: parsedData.structure?.rest?.trimmedNonEmpty,
            notes: normalizedNotes,
            parsingConfidence: previewExercises.isEmpty ? 0 : 1,
            unparsedLines: [],
            rounds: parsedData.structure?.rounds
        )
    }
}

// MARK: - Request Models

/// Request body for `/api/instagram-fetch`
struct InstagramFetchRequest: Codable {
    let url: String
}

/// Request body for `/api/ingest`
struct IngestRequest: Codable {
    let caption: String
    let url: String?
}

private extension WorkoutIngestResponse {
    var previewExercises: [ExerciseData] {
        let amrapExercises = amrapBlocks?.flatMap(\.exercises) ?? []
        let emomExercises = emomBlocks?.flatMap(\.exercises) ?? []
        let blockExercises = amrapExercises + emomExercises
        if !blockExercises.isEmpty {
            return blockExercises
        }
        if !exercises.isEmpty {
            return exercises
        }
        return rows?.map(\.asExerciseData) ?? []
    }
}

private extension WorkoutRow {
    var asExerciseData: ExerciseData {
        ExerciseData(
            id: nil,
            name: exercise,
            sets: sets,
            reps: reps,
            weight: weight,
            unit: nil,
            notes: notes,
            restSeconds: nil
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeFirstString(forKeys keys: [Key]) -> String? {
        for key in keys {
            if let value = decodeLossyString(forKey: key)?.trimmedNonEmpty {
                return value
            }
        }
        return nil
    }

    func decodeLossyString(forKey key: Key) -> String? {
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return String(intValue)
        }
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return String(doubleValue)
        }
        if let boolValue = try? decodeIfPresent(Bool.self, forKey: key) {
            return boolValue ? "true" : "false"
        }
        return nil
    }

    func decodeFirstInt(forKeys keys: [Key]) -> Int? {
        for key in keys {
            if let value = decodeLossyInt(forKey: key) {
                return value
            }
        }
        return nil
    }

    func decodeLossyInt(forKey key: Key) -> Int? {
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(doubleValue.rounded())
        }
        if let stringValue = try? decodeIfPresent(String.self, forKey: key),
           let parsed = Int(stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return parsed
        }
        return nil
    }

    func decodeFirstBool(forKeys keys: [Key]) -> Bool? {
        for key in keys {
            if let value = decodeLossyBool(forKey: key) {
                return value
            }
        }
        return nil
    }

    func decodeLossyBool(forKey key: Key) -> Bool? {
        if let boolValue = try? decodeIfPresent(Bool.self, forKey: key) {
            return boolValue
        }
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return intValue != 0
        }
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            switch stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes":
                return true
            case "false", "0", "no":
                return false
            default:
                return nil
            }
        }
        return nil
    }

    func decodeFirstStringArray(forKeys keys: [Key]) -> [String]? {
        for key in keys {
            if let arrayValue = try? decodeIfPresent([String].self, forKey: key) {
                let normalized = arrayValue.compactMap(\.trimmedNonEmpty)
                return normalized.isEmpty ? nil : normalized
            }

            if let singleValue = decodeLossyString(forKey: key)?.trimmedNonEmpty {
                return [singleValue]
            }
        }
        return nil
    }

    func decodeFirstDecodable<T: Decodable>(_ type: T.Type, forKeys keys: [Key]) -> T? {
        for key in keys {
            if let value = try? decodeIfPresent(T.self, forKey: key) {
                return value
            }
        }
        return nil
    }
}

private enum SocialImportRepValueParser {
    static func parse(_ rawValue: String?) -> (reps: Int?, duration: Int?) {
        guard let normalized = rawValue?.trimmedNonEmpty?.lowercased() else {
            return (nil, nil)
        }

        if let reps = Int(normalized) {
            return (reps, nil)
        }

        if let reps = matchInt(in: normalized, pattern: #"^(\d+)\s*(?:rep|reps)?$"#) {
            return (reps, nil)
        }

        if let durationSeconds = durationSeconds(from: normalized) {
            return (nil, durationSeconds)
        }

        return (nil, nil)
    }

    private static func durationSeconds(from normalized: String) -> Int? {
        if let exactSeconds = matchInt(
            in: normalized.replacingOccurrences(of: " ", with: ""),
            pattern: #"^(\d+)(?:s|sec|secs|second|seconds)$"#
        ) {
            return exactSeconds
        }

        if let exactMinutes = matchInt(
            in: normalized.replacingOccurrences(of: " ", with: ""),
            pattern: #"^(\d+)(?:m|min|mins|minute|minutes)$"#
        ) {
            return exactMinutes * 60
        }

        if let range = normalized.range(
            of: #"^(\d+):(\d{2})$"#,
            options: .regularExpression
        ) {
            let value = String(normalized[range])
            let parts = value.split(separator: ":")
            guard parts.count == 2,
                  let minutes = Int(parts[0]),
                  let seconds = Int(parts[1]) else {
                return nil
            }
            return minutes * 60 + seconds
        }

        return nil
    }

    private static func matchInt(in value: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(value.startIndex..., in: value)
        guard let match = regex.firstMatch(in: value, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: value) else {
            return nil
        }
        return Int(value[captureRange])
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
