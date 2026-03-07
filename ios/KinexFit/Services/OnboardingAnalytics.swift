import Foundation

// MARK: - Events

enum OnboardingEvent {
    // Lifecycle
    case started(source: String)
    case skipped(step: String)
    case completed(importCompleted: Bool, timeTakenSeconds: Int)

    // Import funnel
    case importAttemptStarted(source: String)
    case importVideoAnalyzed(exerciseCount: Int, processingMs: Int)
    case importSuccess(exerciseCount: Int)
    case importSkipped(reason: String)

    // Guest mode
    case guestSaveAttempt(count: Int)
    case guestSaveLimitReached(action: String)
    case guestAIAttempt(count: Int)
    case guestAILimitReached(action: String)

    // Sign-up funnel
    case signupPrompted(context: String)
    case signupStarted(source: String)
    case signupCompleted
    case signupSkipped

    var name: String {
        switch self {
        case .started: return "onboarding_started"
        case .skipped: return "onboarding_skipped"
        case .completed: return "onboarding_completed"
        case .importAttemptStarted: return "import_attempt_started"
        case .importVideoAnalyzed: return "import_video_analyzed"
        case .importSuccess: return "import_success"
        case .importSkipped: return "import_skipped"
        case .guestSaveAttempt: return "guest_save_attempt"
        case .guestSaveLimitReached: return "guest_save_limit_reached"
        case .guestAIAttempt: return "guest_ai_attempt"
        case .guestAILimitReached: return "guest_ai_limit_reached"
        case .signupPrompted: return "signup_prompted"
        case .signupStarted: return "signup_started"
        case .signupCompleted: return "signup_completed"
        case .signupSkipped: return "signup_skipped"
        }
    }

    var properties: [String: Any] {
        switch self {
        case .started(let source):
            return ["source": source]
        case .skipped(let step):
            return ["step_name": step]
        case .completed(let importCompleted, let timeTaken):
            return ["import_completed": importCompleted, "time_taken_seconds": timeTaken]
        case .importAttemptStarted(let source):
            return ["source": source]
        case .importVideoAnalyzed(let count, let ms):
            return ["exercise_count": count, "processing_time_ms": ms]
        case .importSuccess(let count):
            return ["exercise_count": count]
        case .importSkipped(let reason):
            return ["reason": reason]
        case .guestSaveAttempt(let count):
            return ["save_count_after": count]
        case .guestSaveLimitReached(let action):
            return ["action": action]
        case .guestAIAttempt(let count):
            return ["attempt_count": count]
        case .guestAILimitReached(let action):
            return ["action": action]
        case .signupPrompted(let context):
            return ["context": context]
        case .signupStarted(let source):
            return ["source": source]
        case .signupCompleted, .signupSkipped:
            return [:]
        }
    }
}

// MARK: - Service

final class OnboardingAnalytics {
    static let shared = OnboardingAnalytics()

    private init() {}

    func track(_ event: OnboardingEvent) {
        // Log to console during development.
        // Replace with your analytics backend (Amplitude, Mixpanel, PostHog, etc.).
        var message = "[Analytics] \(event.name)"
        if !event.properties.isEmpty {
            let props = event.properties
                .map { "\($0.key)=\($0.value)" }
                .sorted()
                .joined(separator: ", ")
            message += " | \(props)"
        }
        print(message)

        // TODO: Forward to analytics backend when integrated.
        // AnalyticsBackend.shared.logEvent(name: event.name, properties: event.properties)
    }
}
