import Foundation

// MARK: - Body Metrics API

extension APIRequest {
    /// Fetch all body metrics for the current user
    static func getBodyMetrics(limit: Int = 100) -> APIRequest {
        APIRequest(
            path: "/api/body-metrics",
            method: .get,
            queryItems: [URLQueryItem(name: "limit", value: "\(limit)")]
        )
    }

    /// Fetch the latest body metric entry
    static func getLatestBodyMetric() -> APIRequest {
        APIRequest(path: "/api/body-metrics/latest", method: .get)
    }

    /// Create or upsert a body metric entry
    static func createBodyMetric(_ metric: BodyMetricPayload) throws -> APIRequest {
        try json(path: "/api/body-metrics", method: .post, body: metric)
    }

    /// Delete a body metric by date
    static func deleteBodyMetric(date: String) -> APIRequest {
        APIRequest(path: "/api/body-metrics/\(date)", method: .delete)
    }
}

// MARK: - Personal Records API

extension APIRequest {
    /// Fetch user training profile (includes personal records)
    static func getTrainingProfile() -> APIRequest {
        APIRequest(path: "/api/user/profile", method: .get)
    }

    /// Replace the user training profile with a full payload.
    static func updateTrainingProfile(_ profile: TrainingProfile) throws -> APIRequest {
        try json(
            path: "/api/user/profile",
            method: .put,
            body: profile
        )
    }

    /// Add or update a personal record
    static func upsertPersonalRecord(exercise: String, pr: PersonalRecordPayload) throws -> APIRequest {
        try json(
            path: "/api/user/profile/pr",
            method: .post,
            body: UpsertPRRequest(exercise: exercise, pr: pr)
        )
    }

    /// Delete a personal record
    static func deletePersonalRecord(exercise: String) -> APIRequest {
        APIRequest(
            path: "/api/user/profile/pr",
            method: .delete,
            queryItems: [URLQueryItem(name: "exercise", value: exercise)]
        )
    }
}

// MARK: - User Settings API

extension APIRequest {
    /// Update user settings/profile fields.
    static func updateUserSettings(_ payload: UserSettingsPayload) throws -> APIRequest {
        try json(
            path: "/api/user/settings",
            method: .patch,
            body: payload
        )
    }
}

// MARK: - Payloads

struct BodyMetricPayload: Encodable {
    var date: String // YYYY-MM-DD
    var weight: Double?
    var bodyFatPercentage: Double?
    var muscleMass: Double?
    var chest: Double?
    var waist: Double?
    var hips: Double?
    var thighs: Double?
    var arms: Double?
    var calves: Double?
    var shoulders: Double?
    var neck: Double?
    var unit: String // "metric" or "imperial"
    var notes: String?

    init(
        date: String,
        weight: Double? = nil,
        bodyFatPercentage: Double? = nil,
        muscleMass: Double? = nil,
        chest: Double? = nil,
        waist: Double? = nil,
        hips: Double? = nil,
        thighs: Double? = nil,
        arms: Double? = nil,
        calves: Double? = nil,
        shoulders: Double? = nil,
        neck: Double? = nil,
        unit: String = "imperial",
        notes: String? = nil
    ) {
        self.date = date
        self.weight = weight
        self.bodyFatPercentage = bodyFatPercentage
        self.muscleMass = muscleMass
        self.chest = chest
        self.waist = waist
        self.hips = hips
        self.thighs = thighs
        self.arms = arms
        self.calves = calves
        self.shoulders = shoulders
        self.neck = neck
        self.unit = unit
        self.notes = notes
    }
}

struct UserSettingsPayload: Encodable {
    let firstName: String?
    let lastName: String?

    let experience: String?
    let preferredSplit: String?
    let trainingDays: Int?
    let sessionDuration: Int?
    let equipment: [String]?
    let trainingLocation: String?
    let goals: [String]?
    let primaryGoal: String?
    let constraints: [TrainingConstraint]?
    let preferences: TrainingPreferences?

    // Legacy aliases retained for compatibility with older backend handling.
    let experienceLevel: String?
    let trainingDaysPerWeek: Int?

    init(user: User, trainingProfile: TrainingProfile? = nil) {
        firstName = user.firstName
        lastName = user.lastName

        experience = trainingProfile?.experience?.rawValue
        preferredSplit = trainingProfile?.preferredSplit?.rawValue
        trainingDays = trainingProfile?.trainingDays
        sessionDuration = trainingProfile?.sessionDuration
        equipment = trainingProfile.map { profile in
            Array(profile.equipment).map(\.rawValue).sorted()
        }
        trainingLocation = trainingProfile?.trainingLocation?.rawValue
        goals = trainingProfile.map { profile in
            Array(profile.goals).map(\.rawValue).sorted()
        }
        primaryGoal = trainingProfile?.primaryGoal?.rawValue
        constraints = trainingProfile?.constraints
        preferences = trainingProfile?.preferences

        experienceLevel = trainingProfile?.experience?.rawValue
        trainingDaysPerWeek = trainingProfile?.trainingDays
    }

    private enum CodingKeys: String, CodingKey {
        case firstName
        case lastName
        case experience
        case preferredSplit
        case trainingDays
        case sessionDuration
        case equipment
        case trainingLocation
        case goals
        case primaryGoal
        case constraints
        case preferences
        case experienceLevel
        case trainingDaysPerWeek
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Always include name keys so clearing a name syncs as explicit null.
        try container.encode(firstName, forKey: .firstName)
        try container.encode(lastName, forKey: .lastName)
        try container.encodeIfPresent(experience, forKey: .experience)
        try container.encodeIfPresent(preferredSplit, forKey: .preferredSplit)
        try container.encodeIfPresent(trainingDays, forKey: .trainingDays)
        try container.encodeIfPresent(sessionDuration, forKey: .sessionDuration)
        try container.encodeIfPresent(equipment, forKey: .equipment)
        try container.encodeIfPresent(trainingLocation, forKey: .trainingLocation)
        try container.encodeIfPresent(goals, forKey: .goals)
        try container.encodeIfPresent(primaryGoal, forKey: .primaryGoal)
        try container.encodeIfPresent(constraints, forKey: .constraints)
        try container.encodeIfPresent(preferences, forKey: .preferences)
        try container.encodeIfPresent(experienceLevel, forKey: .experienceLevel)
        try container.encodeIfPresent(trainingDaysPerWeek, forKey: .trainingDaysPerWeek)
    }
}

struct PersonalRecordPayload: Encodable {
    let weight: Double
    let reps: Int
    let unit: String
    let date: String // YYYY-MM-DD
    var notes: String?
}

private struct UpsertPRRequest: Encodable {
    let exercise: String
    let pr: PersonalRecordPayload
}

// MARK: - Response Models

struct BodyMetricsListResponse: Decodable {
    let metrics: [APIBodyMetric]
}

struct APIBodyMetric: Decodable, Identifiable {
    var id: String { date }
    let date: String
    let weight: Double?
    let bodyFatPercentage: Double?
    let muscleMass: Double?
    let chest: Double?
    let waist: Double?
    let hips: Double?
    let thighs: Double?
    let arms: Double?
    let calves: Double?
    let shoulders: Double?
    let neck: Double?
    let unit: String?
    let notes: String?
    let createdAt: String?
    let updatedAt: String?

    var parsedDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: date)
    }

    var formattedWeight: String? {
        guard let weight else { return nil }
        let unitLabel = (unit == "metric") ? "kg" : "lbs"
        return String(format: "%.1f %@", weight, unitLabel)
    }

    var formattedBodyFat: String? {
        guard let bodyFatPercentage else { return nil }
        return String(format: "%.1f%%", bodyFatPercentage)
    }
}

struct TrainingProfileResponse: Decodable {
    let success: Bool?
    let profile: APITrainingProfile?
}

struct APITrainingProfile: Decodable {
    let personalRecords: [String: APIPersonalRecord]?
    let experience: String?
    let trainingDays: Int?
    let sessionDuration: Int?
    let equipment: [String]?
    let goals: [String]?
}

struct APIPersonalRecord: Decodable {
    let weight: Double
    let reps: Int?
    let unit: String
    let date: String?
    let notes: String?

    var estimated1RM: Double? {
        guard let reps, reps > 1 else { return weight }
        // Epley formula
        return weight * (1.0 + Double(reps) / 30.0)
    }
}
