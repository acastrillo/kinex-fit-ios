import Foundation

struct CaptionParsedWorkout: Identifiable, Equatable {
    var id: String
    var sourceType: WorkoutSource
    var sourceURL: String?
    var title: String
    var exercises: [CaptionParsedExercise]
    var restBetweenSets: String?
    var notes: String?
    var createdAt: Date
    var parsingConfidence: Double
    var unparsedLines: [CaptionUnparsedLine]
    var rounds: Int?

    init(
        id: String = UUID().uuidString,
        sourceType: WorkoutSource,
        sourceURL: String?,
        title: String,
        exercises: [CaptionParsedExercise],
        restBetweenSets: String?,
        notes: String?,
        createdAt: Date = Date(),
        parsingConfidence: Double,
        unparsedLines: [CaptionUnparsedLine],
        rounds: Int?
    ) {
        self.id = id
        self.sourceType = sourceType
        self.sourceURL = sourceURL
        self.title = title
        self.exercises = exercises
        self.restBetweenSets = restBetweenSets
        self.notes = notes
        self.createdAt = createdAt
        self.parsingConfidence = min(max(parsingConfidence, 0), 1)
        self.unparsedLines = unparsedLines
        self.rounds = rounds
    }
}

struct CaptionParsedExercise: Identifiable, Equatable {
    var id: String
    var kinexExerciseID: String?
    var exerciseName: String
    var rawName: String
    var sets: Int?
    var reps: Int?
    var duration: Int?
    var restAfter: String?
    var notes: String?
    var position: Int
    var match: CaptionExerciseMatch

    init(
        id: String = UUID().uuidString,
        kinexExerciseID: String? = nil,
        exerciseName: String,
        rawName: String,
        sets: Int?,
        reps: Int?,
        duration: Int?,
        restAfter: String?,
        notes: String?,
        position: Int,
        match: CaptionExerciseMatch
    ) {
        self.id = id
        self.kinexExerciseID = kinexExerciseID
        self.exerciseName = exerciseName
        self.rawName = rawName
        self.sets = sets
        self.reps = reps
        self.duration = duration
        self.restAfter = restAfter
        self.notes = notes
        self.position = position
        self.match = match
    }
}

enum CaptionExerciseMatch: Equatable {
    case exact(kinexExerciseID: String?)
    case fuzzy(kinexExerciseID: String?, confidence: Double)
    case ambiguous([CaptionExerciseOption])
    case unknown(closestMatches: [String])

    var requiresResolution: Bool {
        switch self {
        case .ambiguous, .unknown:
            return true
        case .exact, .fuzzy:
            return false
        }
    }

    var kinexExerciseID: String? {
        switch self {
        case .exact(let kinexExerciseID):
            return kinexExerciseID
        case .fuzzy(let kinexExerciseID, _):
            return kinexExerciseID
        case .ambiguous, .unknown:
            return nil
        }
    }
}

struct CaptionExerciseOption: Identifiable, Equatable {
    var kinexExerciseID: String?
    var displayName: String

    var id: String {
        if let kinexExerciseID {
            return kinexExerciseID
        }
        return "name-\(displayName.lowercased())"
    }
}

struct CaptionUnparsedLine: Identifiable, Equatable {
    var id: String
    var text: String
    var reason: String?

    init(id: String = UUID().uuidString, text: String, reason: String? = nil) {
        self.id = id
        self.text = text
        self.reason = reason
    }
}

struct CaptionParseDraft: Equatable {
    var title: String
    var exercises: [CaptionDraftExercise]
    var restBetweenSets: String?
    var rounds: Int?
    var unparsedLines: [CaptionUnparsedLine]
    var confidence: Double
    var notes: String?
}

struct CaptionDraftExercise: Identifiable, Equatable {
    var id: String
    var sets: Int?
    var reps: Int?
    var duration: Int?
    var name: String
    var notes: String?
    var position: Int

    init(
        id: String = UUID().uuidString,
        sets: Int?,
        reps: Int?,
        duration: Int?,
        name: String,
        notes: String?,
        position: Int
    ) {
        self.id = id
        self.sets = sets
        self.reps = reps
        self.duration = duration
        self.name = name
        self.notes = notes
        self.position = position
    }
}

struct AuthoritativeExerciseHint: Equatable {
    var kinexExerciseID: String
    var displayName: String
    var aliases: [String]

    init(kinexExerciseID: String, displayName: String, aliases: [String] = []) {
        self.kinexExerciseID = kinexExerciseID
        self.displayName = displayName
        self.aliases = aliases
    }
}
