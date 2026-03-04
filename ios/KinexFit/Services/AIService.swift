import Foundation
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "AIService")

/// Service for AI-powered workout enhancement and generation
final class AIService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Quota

    /// Get current AI quota status
    func getQuota() async throws -> AIQuota {
        let request = APIRequest(path: "/api/mobile/ai/quota")
        return try await apiClient.send(request)
    }

    /// Check if user can use AI features
    func canUseAI() async -> Bool {
        do {
            let quota = try await getQuota()
            return !quota.isExhausted
        } catch {
            return false
        }
    }

    // MARK: - Enhance Workout

    /// Enhance a workout from raw text (OCR, Instagram, manual input)
    func enhanceWorkout(text: String) async throws -> EnhanceWorkoutResponse {
        logger.info("Enhancing workout from text (length: \(text.count))")

        struct EnhanceRequest: Encodable {
            let text: String
        }

        let request = try APIRequest.json(
            path: "/api/mobile/ai/enhance-workout",
            method: .post,
            body: EnhanceRequest(text: text)
        )

        do {
            let response: EnhanceWorkoutResponse = try await apiClient.send(request)
            logger.info("Enhancement successful")
            return response
        } catch let error as APIError {
            throw mapAPIError(error)
        }
    }

    /// Enhance an existing workout by ID
    func enhanceWorkout(workoutId: String) async throws -> EnhanceWorkoutResponse {
        logger.info("Enhancing existing workout: \(workoutId)")

        struct EnhanceRequest: Encodable {
            let workoutId: String
        }

        let request = try APIRequest.json(
            path: "/api/mobile/ai/enhance-workout",
            method: .post,
            body: EnhanceRequest(workoutId: workoutId)
        )

        do {
            let response: EnhanceWorkoutResponse = try await apiClient.send(request)
            logger.info("Enhancement successful")
            return response
        } catch let error as APIError {
            throw mapAPIError(error)
        }
    }

    // MARK: - Generate Workout

    /// Generate a new workout from a natural language prompt
    func generateWorkout(prompt: String, trainingProfile: TrainingProfile?) async throws -> GenerateWorkoutResponse {
        logger.info("Generating workout from prompt (length: \(prompt.count))")

        struct GenerateRequest: Encodable {
            let prompt: String
            let trainingProfile: TrainingProfile?
        }

        let request = try APIRequest.json(
            path: "/api/mobile/ai/generate-workout",
            method: .post,
            body: GenerateRequest(prompt: prompt, trainingProfile: trainingProfile)
        )

        do {
            let response: GenerateWorkoutResponse = try await apiClient.send(request)
            logger.info("Generation successful")
            return response
        } catch let error as APIError {
            throw mapAPIError(error)
        }
    }

    // MARK: - Workout of the Day

    /// Get personalized workout of the day
    func getWorkoutOfTheDay() async throws -> WorkoutRecommendationResponse {
        logger.info("Fetching workout of the day")

        let request = APIRequest(path: "/api/mobile/ai/workout-of-the-day", method: .post)

        do {
            let response: WorkoutRecommendationResponse = try await apiClient.send(request)
            if response.workout != nil {
                logger.info("WOD received")
            }
            return response
        } catch let error as APIError {
            throw mapAPIError(error)
        }
    }

    // MARK: - Workout of the Week

    /// Get personalized workout of the week (paid tiers only)
    func getWorkoutOfTheWeek() async throws -> WorkoutRecommendationResponse {
        logger.info("Fetching workout of the week")

        let request = APIRequest(path: "/api/mobile/ai/workout-of-the-week", method: .get)

        do {
            let response: WorkoutRecommendationResponse = try await apiClient.send(request)
            if response.workout != nil {
                logger.info("WOW received")
            }
            return response
        } catch let error as APIError {
            throw mapAPIError(error)
        }
    }

    // MARK: - Error Mapping

    private func mapAPIError(_ error: APIError) -> AIError {
        switch error {
        case .httpStatus(429, _):
            return .rateLimited
        case .httpStatus(403, let data):
            let message = Self.extractErrorMessage(from: data)
            return .notAvailableForTier(tier: message ?? "current")
        case .httpStatus(let code, let data):
            let message = Self.extractErrorMessage(from: data) ?? "Server error (code \(code))"
            logger.error("AI request failed: \(message, privacy: .public)")
            return .enhancementFailed(message)
        default:
            return .networkError(error)
        }
    }

    /// Extract the "error" field from a JSON error response body
    private static func extractErrorMessage(from data: Data?) -> String? {
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["error"] as? String else {
            return nil
        }
        return message
    }
}
