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
        logger.info("Enhancing workout from text: \(text.prefix(50))...")

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
            logger.info("Enhancement successful: \(response.workout.title)")
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
            logger.info("Enhancement successful: \(response.workout.title)")
            return response
        } catch let error as APIError {
            throw mapAPIError(error)
        }
    }

    // MARK: - Generate Workout

    /// Generate a new workout from a natural language prompt
    func generateWorkout(prompt: String) async throws -> GenerateWorkoutResponse {
        logger.info("Generating workout from prompt: \(prompt.prefix(50))...")

        struct GenerateRequest: Encodable {
            let prompt: String
        }

        let request = try APIRequest.json(
            path: "/api/mobile/ai/generate-workout",
            method: .post,
            body: GenerateRequest(prompt: prompt)
        )

        do {
            let response: GenerateWorkoutResponse = try await apiClient.send(request)
            logger.info("Generation successful: \(response.workout.title)")
            return response
        } catch let error as APIError {
            throw mapAPIError(error)
        }
    }

    // MARK: - Workout of the Day

    /// Get personalized workout of the day
    func getWorkoutOfTheDay() async throws -> WorkoutRecommendationResponse {
        logger.info("Fetching workout of the day")

        let request = APIRequest(path: "/api/mobile/ai/workout-of-the-day")

        do {
            let response: WorkoutRecommendationResponse = try await apiClient.send(request)
            if let workout = response.workout {
                logger.info("WOD received: \(workout.title)")
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

        let request = APIRequest(path: "/api/mobile/ai/workout-of-the-week")

        do {
            let response: WorkoutRecommendationResponse = try await apiClient.send(request)
            if let workout = response.workout {
                logger.info("WOW received: \(workout.title)")
            }
            return response
        } catch let error as APIError {
            throw mapAPIError(error)
        }
    }

    // MARK: - Error Mapping

    private func mapAPIError(_ error: APIError) -> AIError {
        switch error {
        case .httpStatus(429):
            return .rateLimited
        case .httpStatus(403):
            return .notAvailableForTier(tier: "current")
        case .httpStatus(let code):
            return .enhancementFailed("Server error (code \(code))")
        default:
            return .networkError(error)
        }
    }
}
