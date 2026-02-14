import Foundation

// MARK: - AI Quota

struct AIQuota: Codable {
    let used: Int
    let limit: Int
    let remaining: Int
    let isExhausted: Bool
    let tier: String
    let resetsAt: String?

    var usagePercentage: Double {
        guard limit > 0 else { return 0 }
        return Double(used) / Double(limit)
    }

    var displayText: String {
        if limit == 0 {
            return "AI not available on free tier"
        }
        return "\(used)/\(limit) AI requests used"
    }

    /// Tier-based limits from backend
    static let tierLimits: [String: Int] = [
        "free": 0,
        "core": 10,
        "pro": 30,
        "elite": 100
    ]
}

// MARK: - Timer Suggestion

struct TimerSuggestion: Codable {
    let type: TimerType
    let duration: Int?
    let intervals: Int?
    let workTime: Int?
    let restTime: Int?
    let rounds: Int?

    enum TimerType: String, Codable {
        case emom = "emom"
        case amrap = "amrap"
        case intervalWorkRest = "interval_work_rest"
        case tabata = "tabata"
        case forTime = "for_time"
        case none = "none"

        var displayName: String {
            switch self {
            case .emom: return "EMOM"
            case .amrap: return "AMRAP"
            case .intervalWorkRest: return "Interval"
            case .tabata: return "Tabata"
            case .forTime: return "For Time"
            case .none: return "No Timer"
            }
        }

        var icon: String {
            switch self {
            case .emom: return "clock.badge.checkmark"
            case .amrap: return "flame"
            case .intervalWorkRest: return "repeat"
            case .tabata: return "timer"
            case .forTime: return "stopwatch"
            case .none: return "clock"
            }
        }
    }

    var description: String {
        switch type {
        case .emom:
            if let duration = duration {
                return "\(duration) min EMOM"
            }
            return "EMOM"
        case .amrap:
            if let duration = duration {
                return "\(duration) min AMRAP"
            }
            return "AMRAP"
        case .intervalWorkRest:
            if let work = workTime, let rest = restTime {
                return "\(work)s work / \(rest)s rest"
            }
            return "Interval Training"
        case .tabata:
            return "Tabata (20s on / 10s off)"
        case .forTime:
            return "For Time"
        case .none:
            return "No timer needed"
        }
    }
}

// MARK: - Workout Type

enum WorkoutType: String, Codable {
    case hyrox = "hyrox"
    case metcon = "metcon"
    case strength = "strength"
    case endurance = "endurance"
    case recovery = "recovery"
    case mixed = "mixed"
    case hiit = "hiit"
    case crossfit = "crossfit"

    var displayName: String {
        switch self {
        case .hyrox: return "Hyrox"
        case .metcon: return "MetCon"
        case .strength: return "Strength"
        case .endurance: return "Endurance"
        case .recovery: return "Recovery"
        case .mixed: return "Mixed"
        case .hiit: return "HIIT"
        case .crossfit: return "CrossFit"
        }
    }

    var color: String {
        switch self {
        case .hyrox: return "orange"
        case .metcon: return "red"
        case .strength: return "blue"
        case .endurance: return "green"
        case .recovery: return "purple"
        case .mixed: return "gray"
        case .hiit: return "pink"
        case .crossfit: return "yellow"
        }
    }
}

// MARK: - Enhanced Workout Response

struct EnhanceWorkoutResponse: Codable {
    let workout: EnhancedWorkoutData
    let quotaRemaining: Int?
}

struct EnhancedWorkoutData: Codable {
    let workoutId: String?
    let title: String
    let description: String?
    let exercises: [EnhancedExercise]?
    let tags: [String]?
    let difficulty: String?
    let totalDuration: Int?
    let workoutType: String?
    let structure: AIWorkoutStructure?
    let aiEnhanced: Bool?
    let aiNotes: [String]?

    var content: String {
        description ?? ""
    }
}

struct AIWorkoutStructure: Codable {
    let rounds: Int?
    let timePerRound: Int?
    let timeLimit: Int?
    let totalTime: Int?
    let pattern: String?
}

struct EnhancedExercise: Codable, Identifiable {
    let id: String?
    let name: String
    let sets: Int?
    let reps: StringOrInt?
    let weight: String?
    let restSeconds: Int?
    let notes: String?
    let duration: Int?

    var exerciseId: String {
        id ?? name
    }

    var displayText: String {
        var parts: [String] = [name]
        if let sets = sets, let reps = reps {
            parts.append("\(sets)x\(reps.stringValue)")
        } else if let sets = sets {
            parts.append("\(sets) sets")
        } else if let reps = reps {
            parts.append(reps.stringValue)
        }
        if let weight = weight {
            parts.append("@ \(weight)")
        }
        return parts.joined(separator: " ")
    }
}

/// Helper to decode reps that can be either Int or String
enum StringOrInt: Codable {
    case string(String)
    case int(Int)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else {
            throw DecodingError.typeMismatch(
                StringOrInt.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or Int")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str): try container.encode(str)
        case .int(let num): try container.encode(num)
        }
    }

    var stringValue: String {
        switch self {
        case .string(let str): return str
        case .int(let num): return "\(num)"
        }
    }

    var intValue: Int? {
        switch self {
        case .string(let str): return Int(str)
        case .int(let num): return num
        }
    }
}

// MARK: - Generate Workout Response

struct GenerateWorkoutResponse: Codable {
    let workout: EnhancedWorkoutData
    let rationale: String?
    let alternatives: [String]?
    let timerSuggestion: TimerSuggestion?
    let workoutType: WorkoutType?
    let quotaUsed: Int?
    let quotaLimit: Int?
}

// MARK: - Workout of the Day/Week Response

struct WorkoutRecommendationResponse: Codable {
    let workout: EnhancedWorkoutData?
    let message: String?
    let alreadyScheduled: Bool?
}

// MARK: - AI Error

enum AIError: LocalizedError {
    case quotaExhausted(used: Int, limit: Int)
    case notAvailableForTier(tier: String)
    case rateLimited
    case enhancementFailed(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .quotaExhausted(let used, let limit):
            return "You've used all \(limit) AI requests this month (\(used)/\(limit)). Upgrade for more."
        case .notAvailableForTier(let tier):
            return "AI features are not available on the \(tier) plan. Upgrade to access."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .enhancementFailed(let message):
            return "Enhancement failed: \(message)"
        case .networkError:
            return "Network error. Check your connection and try again."
        }
    }
}
