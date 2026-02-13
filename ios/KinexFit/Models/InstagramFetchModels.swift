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
    let quotaUsed: Int?
    let quotaLimit: Int?
    let timestamp: Date

    /// Create from Instagram fetch response
    init(from fetchResponse: InstagramFetchResponse, ingestResponse: WorkoutIngestResponse) {
        self.title = ingestResponse.title ?? fetchResponse.title
        self.content = fetchResponse.content
        self.author = fetchResponse.author
        self.imageURL = fetchResponse.image
        self.parsedData = ingestResponse
        self.sourceURL = fetchResponse.url
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
