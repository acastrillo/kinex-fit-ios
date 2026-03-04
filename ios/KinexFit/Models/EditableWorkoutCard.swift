import Foundation

enum WorkoutBlockType: String, Codable, CaseIterable, Hashable {
    case amrap
    case emom

    var displayName: String {
        switch self {
        case .amrap: return "AMRAP"
        case .emom: return "EMOM"
        }
    }

    var iconName: String {
        switch self {
        case .amrap: return "flame"
        case .emom: return "clock.badge.checkmark"
        }
    }
}

struct WorkoutBlockContext: Equatable, Hashable {
    var id: String
    var type: WorkoutBlockType
    var value: String?

    init(id: String = UUID().uuidString, type: WorkoutBlockType, value: String? = nil) {
        self.id = id
        self.type = type
        self.value = value?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedValue: String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var title: String {
        if let normalizedValue {
            return "\(type.displayName) \(normalizedValue)"
        }
        return type.displayName
    }

    var identityKey: String {
        "\(type.rawValue)|\(normalizedValue?.lowercased() ?? "")"
    }
}

/// A single editable exercise card used across workout creation/edit flows.
/// Shared between WorkoutFormView, InstagramWorkoutEditView, and InstagramImportReviewView.
struct EditableWorkoutCard: Identifiable, Equatable {
    let id: UUID
    var name: String
    var sets: String
    var reps: String
    var weight: String
    var restSeconds: String
    var block: WorkoutBlockContext?

    init(
        id: UUID = UUID(),
        name: String,
        sets: String,
        reps: String,
        weight: String,
        restSeconds: String,
        block: WorkoutBlockContext? = nil
    ) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.restSeconds = restSeconds
        self.block = block
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Factory Methods

extension EditableWorkoutCard {
    /// Create cards from backend-parsed `ExerciseData` array (Instagram/ingest response).
    static func from(exercises: [ExerciseData], rounds: Int? = nil) -> [EditableWorkoutCard] {
        cards(from: exercises, rounds: rounds, block: nil)
    }

    /// Create cards from backend ingest response, preserving AMRAP/EMOM block groupings when available.
    static func from(ingestResponse: WorkoutIngestResponse) -> [EditableWorkoutCard] {
        var blockAwareCards: [EditableWorkoutCard] = []

        if let amrapBlocks = ingestResponse.amrapBlocks {
            for (index, block) in amrapBlocks.enumerated() {
                let context = WorkoutBlockContext(
                    id: block.id ?? "amrap-\(index + 1)",
                    type: .amrap,
                    value: normalizedBlockValue(block.timeLimit)
                )
                blockAwareCards.append(contentsOf: cards(from: block.exercises, rounds: nil, block: context))
            }
        }

        if let emomBlocks = ingestResponse.emomBlocks {
            for (index, block) in emomBlocks.enumerated() {
                let context = WorkoutBlockContext(
                    id: block.id ?? "emom-\(index + 1)",
                    type: .emom,
                    value: normalizedBlockValue(block.interval)
                )
                blockAwareCards.append(contentsOf: cards(from: block.exercises, rounds: nil, block: context))
            }
        }

        if !blockAwareCards.isEmpty {
            return blockAwareCards
        }

        if let structureType = ingestResponse.structure?.type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            switch structureType {
            case WorkoutBlockType.amrap.rawValue:
                let context = WorkoutBlockContext(
                    id: "amrap-1",
                    type: .amrap,
                    value: normalizedBlockValue(ingestResponse.structure?.timeLimit)
                )
                return cards(from: ingestResponse.exercises, rounds: nil, block: context)
            case WorkoutBlockType.emom.rawValue:
                let context = WorkoutBlockContext(
                    id: "emom-1",
                    type: .emom,
                    value: normalizedBlockValue(ingestResponse.structure?.interval)
                )
                return cards(from: ingestResponse.exercises, rounds: nil, block: context)
            default:
                break
            }
        }

        return from(exercises: ingestResponse.exercises, rounds: ingestResponse.structure?.rounds)
    }

    /// Create cards from AI-enhanced `EnhancedExercise` array.
    static func from(enhancedExercises: [EnhancedExercise], rounds: Int? = nil) -> [EditableWorkoutCard] {
        let roundsFallback = rounds.flatMap { $0 > 0 ? $0 : nil }

        return enhancedExercises.compactMap { exercise in
            guard let normalizedName = normalizeAIExerciseName(exercise.name) else {
                return nil
            }

            let reps = normalizedAIReps(for: exercise)
            let setsText: String
            if let sets = exercise.sets, sets > 0 {
                setsText = String(sets)
            } else if let roundsFallback {
                setsText = String(roundsFallback)
            } else {
                setsText = reps.isEmpty ? "" : "1"
            }

            return EditableWorkoutCard(
                name: normalizedName,
                sets: setsText,
                reps: reps,
                weight: exercise.weight?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                restSeconds: exercise.restSeconds.map(String.init) ?? ""
            )
        }
    }

    /// Create cards from local `WorkoutContentPresentation` exercises.
    static func from(presentation: WorkoutContentPresentation) -> [EditableWorkoutCard] {
        let roundsFallback = presentation.rounds.flatMap { $0 > 0 ? $0 : nil }

        return presentation.exercises.map { exercise in
            EditableWorkoutCard(
                name: exercise.name,
                sets: exercise.sets.map(String.init) ?? roundsFallback.map(String.init) ?? "",
                reps: exercise.reps.map(String.init) ?? "",
                weight: exercise.weight ?? "",
                restSeconds: exercise.restSeconds.map(String.init) ?? "",
                block: exercise.block
            )
        }
    }

    private static func cards(
        from exercises: [ExerciseData],
        rounds: Int?,
        block: WorkoutBlockContext?
    ) -> [EditableWorkoutCard] {
        let roundsFallback = rounds.flatMap { $0 > 0 ? $0 : nil }

        return exercises.map { exercise in
            EditableWorkoutCard(
                name: exercise.name,
                sets: exercise.sets.map(String.init) ?? (roundsFallback.map(String.init) ?? ""),
                reps: exercise.reps ?? "",
                weight: exercise.weight ?? "",
                restSeconds: exercise.restSeconds.map(String.init) ?? "",
                block: block
            )
        }
    }

    private static func normalizedBlockValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedAIReps(for exercise: EnhancedExercise) -> String {
        if let reps = exercise.reps?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
           !reps.isEmpty {
            return reps
        }

        guard let duration = exercise.duration, duration > 0 else {
            return ""
        }

        if duration % 60 == 0, duration >= 60 {
            return "\(duration / 60) min"
        }

        return "\(duration)s"
    }

    private static func normalizeAIExerciseName(_ rawName: String) -> String? {
        var name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)

        if name.range(of: #"(?i)^\s*min(?:ute)?\s*\d+\s*[:\-]\s*"#, options: .regularExpression) != nil {
            name = name.replacingOccurrences(
                of: #"(?i)^\s*min(?:ute)?\s*\d+\s*[:\-]\s*"#,
                with: "",
                options: .regularExpression
            )
        }

        name = name.replacingOccurrences(
            of: #"^\s*[\d\.\)\-•]+\s*"#,
            with: "",
            options: .regularExpression
        )
        name = name
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else { return nil }
        guard name.count <= 80 else { return nil }
        guard name.contains(where: { $0.isLetter }) else { return nil }

        let lowered = name.lowercased()

        let nonExercisePattern = #"(?i)(https?://|www\.|@[\w.]+|#\w+|\b(?:follow|comment|tag|share|subscribe|save this|link in bio|dm)\b)"#
        if lowered.range(of: nonExercisePattern, options: .regularExpression) != nil {
            return nil
        }

        let headerLabels: Set<String> = [
            "strength",
            "strength endurance complex",
            "core",
            "accessory",
            "warm up",
            "cool down",
            "finisher",
            "notes",
            "description",
            "part a",
            "part b",
            "part c",
            "block 1",
            "block 2",
            "block 3"
        ]
        if headerLabels.contains(lowered) || lowered.hasSuffix(":") {
            return nil
        }

        if lowered.split(separator: " ").count > 12 {
            return nil
        }

        return name
    }
}

// MARK: - Content Composition

extension EditableWorkoutCard {
    /// Compose a flat text string from cards + notes suitable for saving as workout content.
    static func composeContent(notes: String, cards: [EditableWorkoutCard], rounds: Int?) -> String {
        var lines: [String] = []
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            lines.append(trimmedNotes)
        }

        let usableCards = cards.filter { !$0.trimmedName.isEmpty }
        guard !usableCards.isEmpty else {
            return lines.joined(separator: "\n\n")
        }

        let hasBlockSections = usableCards.contains { $0.block != nil }
        if let rounds, rounds > 0, !hasBlockSections {
            lines.append("\(rounds) Rounds")
        }

        var lastBlockIdentity: String?
        for card in usableCards {
            let blockIdentity = card.block?.identityKey
            if let block = card.block, blockIdentity != lastBlockIdentity {
                lines.append(block.title)
            }
            lastBlockIdentity = blockIdentity

            var lineComponents: [String] = []
            if !card.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lineComponents.append(card.reps.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            lineComponents.append(card.trimmedName)
            var line = lineComponents.joined(separator: " ")

            if !card.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                line += " @ \(card.weight.trimmingCharacters(in: .whitespacesAndNewlines))"
            }
            if !card.sets.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                line += " (\(card.sets.trimmingCharacters(in: .whitespacesAndNewlines)) sets)"
            }
            if !card.restSeconds.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                line += " Rest \(card.restSeconds.trimmingCharacters(in: .whitespacesAndNewlines))s"
            }
            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }

    /// Extract non-exercise "notes" lines from raw content by filtering out exercise-like lines.
    static func extractNotes(from rawContent: String, exercises: [WorkoutContentPresentation.Exercise]) -> String {
        let lines = rawContent
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return "" }

        let exerciseNames = exercises.map { $0.name.lowercased() }
        let filtered = lines.filter { line in
            let lowered = line.lowercased()

            if lowered.range(of: #"^\d{1,2}\s*rounds?\b"#, options: .regularExpression) != nil {
                return false
            }
            if lowered.range(of: #"(?i)^(?:block\s*[a-z0-9]+\s*[:\-]?\s*)?(?:amrap|emom)\b"#, options: .regularExpression) != nil {
                return false
            }
            if lowered.contains("every minute on the minute") {
                return false
            }
            if lowered.range(of: #"^\d{1,3}\s+[a-z]"#, options: .regularExpression) != nil {
                return false
            }
            if lowered.range(of: #"(?i)\brest\b[^0-9]{0,10}\d{1,3}\s*(?:s|sec|secs|seconds)\b"#, options: .regularExpression) != nil {
                return false
            }
            if lowered.contains("sets"), lowered.contains("reps") {
                return false
            }
            if exerciseNames.contains(where: { lowered.contains($0) }) {
                return false
            }
            return true
        }

        return filtered.joined(separator: "\n")
    }
}
