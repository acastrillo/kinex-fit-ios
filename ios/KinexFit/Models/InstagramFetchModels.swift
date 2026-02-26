import Foundation

// MARK: - Instagram Fetch Response

/// Response from `/api/instagram-fetch` endpoint
struct InstagramFetchResponse: Codable {
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
}

/// Author information from Instagram post
struct AuthorInfo: Codable {
    let username: String
    let fullName: String?
}

/// Post statistics
struct PostStats: Codable {
    let likes: Int?
    let comments: Int?

    enum CodingKeys: String, CodingKey {
        case likes = "likesCount"
        case comments = "commentsCount"
    }
}

/// Parsed workout data from Instagram caption
struct ParsedWorkoutData: Codable {
    let title: String?
    let workoutType: String?
    let exercises: [ExerciseData]?
    let summary: String?
    let breakdown: [String]?
    let structure: WorkoutStructure?
    let usedLLM: Bool?
}

// MARK: - Workout Ingest Response

/// Response from `/api/ingest` endpoint
struct WorkoutIngestResponse: Codable {
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
}

/// Exercise data
struct ExerciseData: Codable, Identifiable {
    let id: String?
    let name: String
    let sets: Int?
    let reps: String?
    let weight: String?
    let unit: String?
    let notes: String?
    let restSeconds: Int?

    // Computed ID for SwiftUI compatibility
    var exerciseId: String {
        id ?? UUID().uuidString
    }
}

/// Workout row (legacy format)
struct WorkoutRow: Codable {
    let exercise: String
    let sets: Int?
    let reps: String?
    let weight: String?
    let notes: String?
}

/// Workout structure information
struct WorkoutStructure: Codable {
    let type: String?  // "standard", "amrap", "emom", "rounds", "ladder", "tabata"
    let timeLimit: String?
    let rounds: Int?
    let interval: String?
    let work: String?
    let rest: String?
}

/// AMRAP block
struct AMRAPBlock: Codable, Identifiable {
    let id: String?
    let timeLimit: String?
    let exercises: [ExerciseData]

    var blockId: String {
        id ?? UUID().uuidString
    }
}

/// EMOM block
struct EMOMBlock: Codable, Identifiable {
    let id: String?
    let interval: String?
    let exercises: [ExerciseData]

    var blockId: String {
        id ?? UUID().uuidString
    }
}

/// Workout V1 metadata (legacy)
struct WorkoutV1: Codable {
    let name: String?
    let totalDuration: Int?
    let difficulty: String?
    let tags: [String]?
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

        // Parse timestamp
        let formatter = ISO8601DateFormatter()
        self.timestamp = formatter.date(from: fetchResponse.timestamp) ?? Date()
    }

    /// Convenience computed properties
    var exerciseCount: Int {
        parsedData.exercises.count
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
