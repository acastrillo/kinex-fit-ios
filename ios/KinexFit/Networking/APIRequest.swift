import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

struct APIRequest {
    var path: String
    var method: HTTPMethod
    var queryItems: [URLQueryItem]
    var headers: [String: String]
    var body: Data?

    init(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
    }

    static func json<T: Encodable>(
        path: String,
        method: HTTPMethod,
        body: T,
        encoder: JSONEncoder = JSONCoding.apiEncoder()
    ) throws -> APIRequest {
        let data = try encoder.encode(body)
        return APIRequest(path: path, method: method, headers: ["Content-Type": "application/json"], body: data)
    }

    /// Create a multipart form data request for file upload
    static func multipartFormData(
        path: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fieldName: String = "file"
    ) -> APIRequest {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return APIRequest(
            path: path,
            method: .post,
            headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"],
            body: body
        )
    }
}

// MARK: - Workout Scheduling API

extension APIRequest {
    /// Fetch scheduled workouts. If `date` is provided, filters by YYYY-MM-DD.
    static func getScheduledWorkouts(date: String? = nil) -> APIRequest {
        let queryItems: [URLQueryItem]
        if let date, !date.isEmpty {
            queryItems = [URLQueryItem(name: "date", value: date)]
        } else {
            queryItems = []
        }
        return APIRequest(path: "/api/workouts/scheduled", method: .get, queryItems: queryItems)
    }

    /// Schedule a workout on a specific date using the web scheduling route.
    static func scheduleWorkout(
        workoutId: String,
        scheduledDate: String,
        status: WorkoutScheduleStatus = .scheduled
    ) throws -> APIRequest {
        try json(
            path: "/api/workouts/\(workoutId)/schedule",
            method: .patch,
            body: WorkoutScheduleRequest(scheduledDate: scheduledDate, status: status)
        )
    }

    /// Remove scheduling metadata for a workout.
    static func unscheduleWorkout(workoutId: String) -> APIRequest {
        APIRequest(path: "/api/workouts/\(workoutId)/schedule", method: .delete)
    }

    /// Mark a workout as completed.
    static func completeWorkout(
        workoutId: String,
        completedDate: String? = nil,
        completedAt: String? = nil,
        durationSeconds: Int? = nil
    ) throws -> APIRequest {
        try json(
            path: "/api/workouts/\(workoutId)/complete",
            method: .post,
            body: WorkoutCompletionRequest(
                completedDate: completedDate,
                completedAt: completedAt,
                durationSeconds: durationSeconds
            )
        )
    }
}

struct WorkoutScheduleRequest: Encodable {
    let scheduledDate: String
    let status: WorkoutScheduleStatus?
}

struct WorkoutCompletionRequest: Encodable {
    let completedDate: String?
    let completedAt: String?
    let durationSeconds: Int?
}

struct WorkoutScheduleActionResponse: Decodable {
    let success: Bool?
    let workoutId: String?
    let scheduledDate: String?
    let scheduledTime: String?
    let status: WorkoutScheduleStatus?
    let completedDate: String?
    let completedAt: String?
    let durationSeconds: Int?
    let completionCount: Int?
    let isCompleted: Bool?

    private enum CodingKeys: String, CodingKey {
        case success
        case workoutId
        case workout_id
        case scheduledDate
        case scheduled_date
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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = Self.decodeFirstBool(in: container, keys: [.success])
        workoutId = Self.decodeFirstString(in: container, keys: [.workoutId, .workout_id])
        scheduledDate = Self.decodeFirstString(in: container, keys: [.scheduledDate, .scheduled_date])
        scheduledTime = Self.decodeFirstString(in: container, keys: [.scheduledTime, .scheduled_time])
        if let rawStatus = Self.decodeFirstString(in: container, keys: [.status])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() {
            status = WorkoutScheduleStatus(rawValue: rawStatus)
        } else {
            status = nil
        }
        completedDate = Self.decodeFirstString(in: container, keys: [.completedDate, .completed_date])
        completedAt = Self.decodeFirstString(in: container, keys: [.completedAt, .completed_at])
        durationSeconds = Self.decodeFirstInt(in: container, keys: [.durationSeconds, .duration_seconds])
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
        isCompleted = Self.decodeFirstBool(in: container, keys: [.isCompleted, .is_completed])
    }

    private static func decodeFirstString(
        in container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> String? {
        for key in keys {
            if let value: String = try? container.decodeIfPresent(String.self, forKey: key) {
                return value
            }
            if let value: Int = try? container.decodeIfPresent(Int.self, forKey: key) {
                return String(value)
            }
        }
        return nil
    }

    private static func decodeFirstInt(
        in container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Int? {
        for key in keys {
            if let value: Int = try? container.decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value: String = try? container.decodeIfPresent(String.self, forKey: key),
               let parsed = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return parsed
            }
        }
        return nil
    }

    private static func decodeFirstBool(
        in container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Bool? {
        for key in keys {
            if let value: Bool = try? container.decodeIfPresent(Bool.self, forKey: key) {
                return value
            }
            if let value: Int = try? container.decodeIfPresent(Int.self, forKey: key) {
                return value != 0
            }
            if let value: String = try? container.decodeIfPresent(String.self, forKey: key) {
                switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "1", "true", "yes", "y":
                    return true
                case "0", "false", "no", "n":
                    return false
                default:
                    continue
                }
            }
        }
        return nil
    }
}
