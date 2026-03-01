import Foundation

// MARK: - Training Profile

struct TrainingProfile: Codable {
    var experience: ExperienceLevel?
    var preferredSplit: PreferredSplit?
    var trainingDays: Int?
    var sessionDuration: Int? // in minutes
    var equipment: Set<Equipment>
    var trainingLocation: TrainingLocation?
    var goals: Set<TrainingGoal>
    var primaryGoal: TrainingGoal?
    var constraints: [TrainingConstraint]
    var preferences: TrainingPreferences?
    var personalRecords: [PersonalRecord]
    var updatedAt: String?
    var createdAt: String?

    init() {
        self.experience = nil
        self.preferredSplit = nil
        self.trainingDays = nil
        self.sessionDuration = nil
        self.equipment = []
        self.trainingLocation = nil
        self.goals = []
        self.primaryGoal = nil
        self.constraints = []
        self.preferences = nil
        self.personalRecords = []
        self.updatedAt = nil
        self.createdAt = nil
    }

    // Backward-compatible aliases used by existing onboarding views
    var experienceLevel: ExperienceLevel? {
        get { experience }
        set { experience = newValue }
    }

    var trainingDaysPerWeek: Int? {
        get { trainingDays }
        set { trainingDays = newValue }
    }

    static let trainingDaysRange = 1...7
    static let sessionDurationRange = 15...180

    var validationErrors: [String] {
        var errors: [String] = []

        if let trainingDays, !Self.trainingDaysRange.contains(trainingDays) {
            errors.append("Training days must be between 1 and 7")
        }

        if let sessionDuration, !Self.sessionDurationRange.contains(sessionDuration) {
            errors.append("Session duration must be between 15 and 180 minutes")
        }

        return errors
    }
}

extension TrainingProfile {
    private enum CodingKeys: String, CodingKey {
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
        case personalRecords
        case updatedAt
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.experience = try container.decodeIfPresent(ExperienceLevel.self, forKey: .experience)
        self.preferredSplit = try container.decodeIfPresent(PreferredSplit.self, forKey: .preferredSplit)
        self.trainingDays = try container.decodeIfPresent(Int.self, forKey: .trainingDays)
        self.sessionDuration = try container.decodeIfPresent(Int.self, forKey: .sessionDuration)
        self.equipment = try container.decodeIfPresent(Set<Equipment>.self, forKey: .equipment) ?? []
        self.trainingLocation = try container.decodeIfPresent(TrainingLocation.self, forKey: .trainingLocation)
        self.goals = try container.decodeIfPresent(Set<TrainingGoal>.self, forKey: .goals) ?? []
        self.primaryGoal = try container.decodeIfPresent(TrainingGoal.self, forKey: .primaryGoal)
        self.constraints = try container.decodeIfPresent([TrainingConstraint].self, forKey: .constraints) ?? []
        self.preferences = try container.decodeIfPresent(TrainingPreferences.self, forKey: .preferences)
        self.updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)

        let recordMap = try container.decodeIfPresent([String: PersonalRecordPayload].self, forKey: .personalRecords) ?? [:]
        self.personalRecords = recordMap.map { exercise, value in
            PersonalRecord(
                exerciseName: exercise,
                weight: value.weight,
                unit: value.unit,
                reps: value.reps,
                date: value.date,
                notes: value.notes
            )
        }
        .sorted { $0.exerciseName.localizedCaseInsensitiveCompare($1.exerciseName) == .orderedAscending }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(experience, forKey: .experience)
        try container.encodeIfPresent(preferredSplit, forKey: .preferredSplit)
        try container.encodeIfPresent(trainingDays, forKey: .trainingDays)
        try container.encodeIfPresent(sessionDuration, forKey: .sessionDuration)
        try container.encode(Array(equipment).sorted { $0.rawValue < $1.rawValue }, forKey: .equipment)
        try container.encodeIfPresent(trainingLocation, forKey: .trainingLocation)
        try container.encode(Array(goals).sorted { $0.rawValue < $1.rawValue }, forKey: .goals)
        try container.encodeIfPresent(primaryGoal, forKey: .primaryGoal)
        try container.encode(constraints, forKey: .constraints)
        try container.encodeIfPresent(preferences, forKey: .preferences)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)

        var recordMap: [String: PersonalRecordPayload] = [:]
        for record in personalRecords {
            let exerciseName = record.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !exerciseName.isEmpty else { continue }

            recordMap[exerciseName] = PersonalRecordPayload(
                weight: record.weight,
                reps: max(1, record.reps ?? 1),
                unit: record.unit,
                date: record.date,
                notes: record.notes
            )
        }
        try container.encode(recordMap, forKey: .personalRecords)
    }

    private struct PersonalRecordPayload: Codable {
        let weight: Double
        let reps: Int
        let unit: WeightUnit
        let date: String
        let notes: String?
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

// MARK: - Preferred Split

enum PreferredSplit: String, Codable, CaseIterable {
    case fullBody = "full-body"
    case upperLower = "upper-lower"
    case pushPullLegs = "push-pull-legs"
    case broSplit = "bro-split"
    case custom

    var displayName: String {
        switch self {
        case .fullBody: return "Full Body"
        case .upperLower: return "Upper / Lower"
        case .pushPullLegs: return "Push / Pull / Legs"
        case .broSplit: return "Bro Split"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Training Location

enum TrainingLocation: String, Codable, CaseIterable {
    case home
    case gym
    case both

    var displayName: String {
        switch self {
        case .home: return "Home"
        case .gym: return "Gym"
        case .both: return "Home + Gym"
        }
    }
}

// MARK: - Equipment

struct Equipment: Hashable, Codable, RawRepresentable, CaseIterable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    // Legacy aliases retained for existing onboarding previews/usages.
    static let fullGym = Equipment.barbell
    static let homeGym = Equipment.dumbbells
    static let minimal = Equipment.resistanceBands
    static let bodyweight = Equipment.pullUpBar

    // Free Weights
    static let barbell = Equipment("Barbell")
    static let dumbbells = Equipment("Dumbbells")
    static let kettlebells = Equipment("Kettlebells")
    static let weightPlates = Equipment("Weight plates")
    static let ezCurlBar = Equipment("EZ curl bar")

    // Racks & Benches
    static let squatRack = Equipment("Squat rack")
    static let powerRack = Equipment("Power rack")
    static let benchFlat = Equipment("Bench (flat)")
    static let benchAdjustable = Equipment("Bench (adjustable)")
    static let preacherCurlBench = Equipment("Preacher curl bench")

    // Bodyweight & Functional
    static let pullUpBar = Equipment("Pull-up bar")
    static let dipStation = Equipment("Dip station")
    static let gymnasticsRings = Equipment("Gymnastics rings")
    static let parallettes = Equipment("Parallettes")
    static let battleRopes = Equipment("Battle ropes")
    static let slamBalls = Equipment("Slam balls")

    // Cable & Machines
    static let cableMachine = Equipment("Cable machine")
    static let functionalTrainer = Equipment("Functional trainer")
    static let smithMachine = Equipment("Smith machine")
    static let legPress = Equipment("Leg press")
    static let legExtension = Equipment("Leg extension")
    static let legCurl = Equipment("Leg curl")
    static let latPulldown = Equipment("Lat pulldown")
    static let seatedRow = Equipment("Seated row")
    static let chestPressMachine = Equipment("Chest press machine")
    static let shoulderPressMachine = Equipment("Shoulder press machine")

    // Cardio Equipment
    static let treadmill = Equipment("Treadmill")
    static let stationaryBike = Equipment("Stationary bike")
    static let rowingMachine = Equipment("Rowing machine")
    static let elliptical = Equipment("Elliptical")
    static let stairClimber = Equipment("Stair climber")
    static let assaultBike = Equipment("Assault bike")
    static let skiErg = Equipment("Ski erg")

    // Functional Training
    static let plyometricBox = Equipment("Plyometric box")
    static let stepPlatform = Equipment("Step platform")
    static let trxSuspensionTrainer = Equipment("TRX/Suspension trainer")
    static let resistanceBands = Equipment("Resistance bands")
    static let resistanceLoops = Equipment("Resistance loops")
    static let medicineBall = Equipment("Medicine ball")
    static let weightedVest = Equipment("Weighted vest")
    static let sandbag = Equipment("Sandbag")
    static let landmineAttachment = Equipment("Landmine attachment")

    // Recovery & Flexibility
    static let foamRoller = Equipment("Foam roller")
    static let yogaMat = Equipment("Yoga mat")
    static let massageGun = Equipment("Massage gun")
    static let stretchingStrap = Equipment("Stretching strap")
    static let balanceBoard = Equipment("Balance board")

    // Other
    static let jumpRope = Equipment("Jump rope")
    static let barre = Equipment("Barre")
    static let abWheel = Equipment("Ab wheel")
    static let gluteHamDeveloper = Equipment("Glute-ham developer (GHD)")
    static let trapBar = Equipment("Trap bar")

    static let allCases: [Equipment] = [
        .barbell, .dumbbells, .kettlebells, .weightPlates, .ezCurlBar,
        .squatRack, .powerRack, .benchFlat, .benchAdjustable, .preacherCurlBench,
        .pullUpBar, .dipStation, .gymnasticsRings, .parallettes, .battleRopes, .slamBalls,
        .cableMachine, .functionalTrainer, .smithMachine, .legPress, .legExtension,
        .legCurl, .latPulldown, .seatedRow, .chestPressMachine, .shoulderPressMachine,
        .treadmill, .stationaryBike, .rowingMachine, .elliptical, .stairClimber,
        .assaultBike, .skiErg,
        .plyometricBox, .stepPlatform, .trxSuspensionTrainer, .resistanceBands,
        .resistanceLoops, .medicineBall, .weightedVest, .sandbag, .landmineAttachment,
        .foamRoller, .yogaMat, .massageGun, .stretchingStrap, .balanceBoard,
        .jumpRope, .barre, .abWheel, .gluteHamDeveloper, .trapBar,
    ]

    var displayName: String {
        rawValue
    }

    var description: String {
        switch rawValue {
        case "Barbell", "Dumbbells", "Kettlebells", "Weight plates", "EZ curl bar":
            return "Free weight equipment"
        case "Squat rack", "Power rack", "Bench (flat)", "Bench (adjustable)", "Preacher curl bench":
            return "Strength setup equipment"
        case "Pull-up bar", "Dip station", "Gymnastics rings", "Parallettes", "Battle ropes", "Slam balls":
            return "Bodyweight and functional tools"
        case "Cable machine", "Functional trainer", "Smith machine", "Leg press", "Leg extension", "Leg curl", "Lat pulldown", "Seated row", "Chest press machine", "Shoulder press machine":
            return "Machine-based training equipment"
        case "Treadmill", "Stationary bike", "Rowing machine", "Elliptical", "Stair climber", "Assault bike", "Ski erg":
            return "Cardio equipment"
        case "Plyometric box", "Step platform", "TRX/Suspension trainer", "Resistance bands", "Resistance loops", "Medicine ball", "Weighted vest", "Sandbag", "Landmine attachment":
            return "Functional training tools"
        case "Foam roller", "Yoga mat", "Massage gun", "Stretching strap", "Balance board":
            return "Recovery and mobility tools"
        default:
            return "Available training equipment"
        }
    }

    var icon: String {
        switch rawValue {
        case "Treadmill", "Stationary bike", "Rowing machine", "Elliptical", "Stair climber", "Assault bike", "Ski erg":
            return "figure.run"
        case "Foam roller", "Yoga mat", "Massage gun", "Stretching strap", "Balance board":
            return "figure.cooldown"
        case "Pull-up bar", "Dip station", "Gymnastics rings", "Parallettes":
            return "figure.strengthtraining.functional"
        default:
            return "dumbbell"
        }
    }
}

// MARK: - Training Goal

struct TrainingGoal: Hashable, Codable, RawRepresentable, CaseIterable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    // Legacy aliases retained for existing onboarding previews/usages.
    static let strength = TrainingGoal.increaseStrengthPowerlifting
    static let endurance = TrainingGoal.improveCardiovascularEndurance
    static let weightLoss = TrainingGoal.loseFatWeightLoss
    static let muscleGain = TrainingGoal.buildMuscleHypertrophy
    static let generalFitness = TrainingGoal.generalFitnessHealthMaintenance
    static let athletic = TrainingGoal.athleticPerformanceSportsTraining

    static let buildMuscleHypertrophy = TrainingGoal("Build muscle (hypertrophy)")
    static let increaseStrengthPowerlifting = TrainingGoal("Increase strength (powerlifting)")
    static let loseFatWeightLoss = TrainingGoal("Lose fat / Weight loss")
    static let improveCardiovascularEndurance = TrainingGoal("Improve cardiovascular endurance")
    static let improveMobilityFlexibility = TrainingGoal("Improve mobility / Flexibility")
    static let athleticPerformanceSportsTraining = TrainingGoal("Athletic performance / Sports training")
    static let generalFitnessHealthMaintenance = TrainingGoal("General fitness / Health maintenance")
    static let bodybuildingPhysiqueCompetition = TrainingGoal("Bodybuilding / Physique competition")
    static let functionalFitnessCrossFit = TrainingGoal("Functional fitness / CrossFit")
    static let rehabilitationInjuryRecovery = TrainingGoal("Rehabilitation / Injury recovery")
    static let improvePostureCoreStability = TrainingGoal("Improve posture / Core stability")
    static let increasePowerExplosiveness = TrainingGoal("Increase power / Explosiveness")
    static let marathonEnduranceEventTraining = TrainingGoal("Marathon / Endurance event training")
    static let toneAndDefineMuscles = TrainingGoal("Tone and define muscles")
    static let buildWorkCapacityConditioning = TrainingGoal("Build work capacity / Conditioning")

    static let allCases: [TrainingGoal] = [
        .buildMuscleHypertrophy,
        .increaseStrengthPowerlifting,
        .loseFatWeightLoss,
        .improveCardiovascularEndurance,
        .improveMobilityFlexibility,
        .athleticPerformanceSportsTraining,
        .generalFitnessHealthMaintenance,
        .bodybuildingPhysiqueCompetition,
        .functionalFitnessCrossFit,
        .rehabilitationInjuryRecovery,
        .improvePostureCoreStability,
        .increasePowerExplosiveness,
        .marathonEnduranceEventTraining,
        .toneAndDefineMuscles,
        .buildWorkCapacityConditioning,
    ]

    var displayName: String {
        rawValue
    }

    var description: String {
        rawValue
    }

    var icon: String {
        switch rawValue {
        case "Build muscle (hypertrophy)", "Bodybuilding / Physique competition", "Tone and define muscles":
            return "figure.strengthtraining.traditional"
        case "Increase strength (powerlifting)", "Increase power / Explosiveness":
            return "bolt.fill"
        case "Lose fat / Weight loss", "Build work capacity / Conditioning":
            return "flame.fill"
        case "Improve cardiovascular endurance", "Marathon / Endurance event training":
            return "lungs.fill"
        case "Improve mobility / Flexibility", "Improve posture / Core stability":
            return "figure.flexibility"
        case "Athletic performance / Sports training", "Functional fitness / CrossFit":
            return "sportscourt.fill"
        case "Rehabilitation / Injury recovery":
            return "cross.case.fill"
        default:
            return "target"
        }
    }
}

// MARK: - Training Constraint

struct TrainingConstraint: Codable, Hashable, Identifiable {
    var id: String
    var description: String
    var affectedExercises: [String]?
    var createdAt: String

    init(
        id: String = UUID().uuidString,
        description: String,
        affectedExercises: [String]? = nil,
        createdAt: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id
        self.description = description
        self.affectedExercises = affectedExercises
        self.createdAt = createdAt
    }
}

// MARK: - Training Preferences

struct TrainingPreferences: Codable, Hashable {
    var favoriteExercises: [String]?
    var dislikedExercises: [String]?
    var warmupRequired: Bool?
    var cooldownRequired: Bool?
}

// MARK: - Personal Record

struct PersonalRecord: Codable, Identifiable {
    let id: UUID
    var exerciseName: String
    var weight: Double
    var unit: WeightUnit
    var reps: Int?
    var date: String // YYYY-MM-DD
    var notes: String?

    init(
        id: UUID = UUID(),
        exerciseName: String,
        weight: Double,
        unit: WeightUnit,
        reps: Int? = nil,
        date: String = PersonalRecord.defaultDateString(),
        notes: String? = nil
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.weight = weight
        self.unit = unit
        if let reps {
            self.reps = max(1, reps)
        } else {
            self.reps = nil
        }
        self.date = date
        self.notes = notes
    }

    var displayText: String {
        let weightText = "\(Int(weight))\(unit.symbol)"
        if let reps {
            return "\(exerciseName): \(weightText) x \(reps)"
        }
        return "\(exerciseName): \(weightText)"
    }

    private static func defaultDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    private enum CodingKeys: String, CodingKey {
        case weight
        case reps
        case unit
        case date
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.exerciseName = ""
        self.weight = try container.decode(Double.self, forKey: .weight)
        self.reps = try container.decodeIfPresent(Int.self, forKey: .reps)
        if let reps {
            self.reps = max(1, reps)
        }
        self.unit = try container.decode(WeightUnit.self, forKey: .unit)
        self.date = try container.decodeIfPresent(String.self, forKey: .date) ?? Self.defaultDateString()
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(weight, forKey: .weight)
        try container.encode(max(1, reps ?? 1), forKey: .reps)
        try container.encode(unit, forKey: .unit)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(notes, forKey: .notes)
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
        "Bench press",
        "Incline bench press",
        "Dumbbell bench press",
        "Dips",
        "Deadlift",
        "Barbell row",
        "Pull-ups",
        "Lat pulldown",
        "Overhead press",
        "Military press",
        "Dumbbell shoulder press",
        "Squat",
        "Front squat",
        "Romanian deadlift",
        "Leg press",
        "Barbell curl",
        "Close-grip bench press",
        "Skull crushers",
    ]
}
