import Foundation

@MainActor
final class GuestModeManager: ObservableObject {
    static let shared = GuestModeManager()

    @Published var workoutsSaved: Int
    @Published var aiGenerationsUsed: Int
    @Published var showSaveLimitBanner: Bool = false
    @Published var showAILimitBanner: Bool = false

    private let defaults = UserDefaults.standard
    private let saveCountKey = "guest_workoutsSaved"
    private let aiCountKey = "guest_aiGenerationsUsed"

    let maxWorkoutSaves = 3
    let maxAIGenerations = 1

    init() {
        self.workoutsSaved = UserDefaults.standard.integer(forKey: "guest_workoutsSaved")
        self.aiGenerationsUsed = UserDefaults.standard.integer(forKey: "guest_aiGenerationsUsed")
    }

    func canSaveWorkout() -> Bool {
        workoutsSaved < maxWorkoutSaves
    }

    func canUseAI() -> Bool {
        aiGenerationsUsed < maxAIGenerations
    }

    func recordWorkoutSave() {
        workoutsSaved += 1
        defaults.set(workoutsSaved, forKey: saveCountKey)
        if workoutsSaved >= maxWorkoutSaves {
            showSaveLimitBanner = true
        }
    }

    func recordAIGeneration() {
        aiGenerationsUsed += 1
        defaults.set(aiGenerationsUsed, forKey: aiCountKey)
        if aiGenerationsUsed >= maxAIGenerations {
            showAILimitBanner = true
        }
    }

    /// Remaining saves before the guest cap is hit.
    var remainingSaves: Int {
        max(0, maxWorkoutSaves - workoutsSaved)
    }

    /// Reset all guest counters — call after a user signs up.
    func reset() {
        workoutsSaved = 0
        aiGenerationsUsed = 0
        showSaveLimitBanner = false
        showAILimitBanner = false
        defaults.removeObject(forKey: saveCountKey)
        defaults.removeObject(forKey: aiCountKey)
    }
}

// MARK: - Errors

enum GuestLimitError: LocalizedError {
    case workoutSaveLimitReached
    case aiGenerationLimitReached

    var errorDescription: String? {
        switch self {
        case .workoutSaveLimitReached:
            return "You've reached the 3-workout guest limit. Sign up free to save unlimited workouts."
        case .aiGenerationLimitReached:
            return "You've used your free AI workout. Sign up free for unlimited AI generations."
        }
    }
}
