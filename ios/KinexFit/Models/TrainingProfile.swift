import Foundation

// MARK: - Training Profile

struct TrainingProfile: Codable {
    var experienceLevel: ExperienceLevel?
    var trainingDaysPerWeek: Int?
    var sessionDuration: Int? // in minutes
    var equipment: Set<Equipment>
    var goals: Set<TrainingGoal>
    var personalRecords: [PersonalRecord]

    init() {
        self.equipment = []
        self.goals = []
        self.personalRecords = []
    }
}

// MARK: - Experience Level

enum ExperienceLevel: String, Codable, CaseIterable {
    case beginner
    case intermediate
    case advanced

    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }

    var description: String {
        switch self {
        case .beginner:
            return "New to fitness or getting back after a break"
        case .intermediate:
            return "Training regularly for 6+ months"
        case .advanced:
            return "Training consistently for 2+ years"
        }
    }

    var icon: String {
        switch self {
        case .beginner: return "figure.walk"
        case .intermediate: return "figure.run"
        case .advanced: return "figure.strengthtraining.traditional"
        }
    }
}

// MARK: - Equipment

enum Equipment: String, Codable, CaseIterable {
    case fullGym = "full_gym"
    case homeGym = "home_gym"
    case minimal = "minimal"
    case bodyweight = "bodyweight"

    var displayName: String {
        switch self {
        case .fullGym: return "Full Gym"
        case .homeGym: return "Home Gym"
        case .minimal: return "Minimal Equipment"
        case .bodyweight: return "Bodyweight Only"
        }
    }

    var description: String {
        switch self {
        case .fullGym:
            return "Access to commercial gym with all equipment"
        case .homeGym:
            return "Barbells, dumbbells, rack, and basic equipment"
        case .minimal:
            return "Dumbbells, resistance bands, or kettlebells"
        case .bodyweight:
            return "No equipment needed"
        }
    }

    var icon: String {
        switch self {
        case .fullGym: return "building.2"
        case .homeGym: return "house"
        case .minimal: return "dumbbell"
        case .bodyweight: return "figure.highintensity.intervaltraining"
        }
    }
}

// MARK: - Training Goal

enum TrainingGoal: String, Codable, CaseIterable {
    case strength
    case endurance
    case weightLoss = "weight_loss"
    case muscleGain = "muscle_gain"
    case generalFitness = "general_fitness"
    case athletic = "athletic"

    var displayName: String {
        switch self {
        case .strength: return "Build Strength"
        case .endurance: return "Improve Endurance"
        case .weightLoss: return "Lose Weight"
        case .muscleGain: return "Gain Muscle"
        case .generalFitness: return "General Fitness"
        case .athletic: return "Athletic Performance"
        }
    }

    var description: String {
        switch self {
        case .strength:
            return "Get stronger with progressive overload"
        case .endurance:
            return "Build cardiovascular and muscular endurance"
        case .weightLoss:
            return "Burn fat and lose weight"
        case .muscleGain:
            return "Build muscle mass and size"
        case .generalFitness:
            return "Stay active and healthy"
        case .athletic:
            return "Improve sports performance"
        }
    }

    var icon: String {
        switch self {
        case .strength: return "bolt.fill"
        case .endurance: return "lungs.fill"
        case .weightLoss: return "flame.fill"
        case .muscleGain: return "figure.strengthtraining.traditional"
        case .generalFitness: return "heart.fill"
        case .athletic: return "sportscourt.fill"
        }
    }
}

// MARK: - Personal Record

struct PersonalRecord: Codable, Identifiable {
    let id: UUID
    let exerciseName: String
    let weight: Double
    let unit: WeightUnit
    let reps: Int?
    let date: Date

    init(id: UUID = UUID(), exerciseName: String, weight: Double, unit: WeightUnit, reps: Int? = nil, date: Date = Date()) {
        self.id = id
        self.exerciseName = exerciseName
        self.weight = weight
        self.unit = unit
        self.reps = reps
        self.date = date
    }

    var displayText: String {
        let weightText = "\(Int(weight))\(unit.symbol)"
        if let reps = reps {
            return "\(exerciseName): \(weightText) x \(reps)"
        } else {
            return "\(exerciseName): \(weightText)"
        }
    }
}

enum WeightUnit: String, Codable {
    case kg
    case lbs

    var symbol: String {
        switch self {
        case .kg: return "kg"
        case .lbs: return "lbs"
        }
    }
}

// MARK: - Common Exercises for PRs

extension PersonalRecord {
    static let commonExercises = [
        "Bench Press",
        "Squat",
        "Deadlift",
        "Overhead Press",
        "Barbell Row",
        "Pull-ups",
        "Clean",
        "Snatch",
    ]
}
