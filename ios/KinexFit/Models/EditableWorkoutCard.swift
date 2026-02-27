import Foundation

/// A single editable exercise card used across workout creation/edit flows.
/// Shared between WorkoutFormView, InstagramWorkoutEditView, and InstagramImportReviewView.
struct EditableWorkoutCard: Identifiable, Equatable {
    let id: UUID
    var name: String
    var sets: String
    var reps: String
    var weight: String
    var restSeconds: String

    init(
        id: UUID = UUID(),
        name: String,
        sets: String,
        reps: String,
        weight: String,
        restSeconds: String
    ) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.restSeconds = restSeconds
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Factory Methods

extension EditableWorkoutCard {
    /// Create cards from backend-parsed `ExerciseData` array (Instagram/ingest response).
    static func from(exercises: [ExerciseData], rounds: Int? = nil) -> [EditableWorkoutCard] {
        exercises.map { exercise in
            EditableWorkoutCard(
                name: exercise.name,
                sets: exercise.sets.map(String.init) ?? (rounds.map(String.init) ?? ""),
                reps: exercise.reps ?? "",
                weight: exercise.weight ?? "",
                restSeconds: exercise.restSeconds.map(String.init) ?? ""
            )
        }
    }

    /// Create cards from AI-enhanced `EnhancedExercise` array.
    static func from(enhancedExercises: [EnhancedExercise]) -> [EditableWorkoutCard] {
        enhancedExercises.compactMap { exercise in
            guard let normalizedName = normalizeAIExerciseName(exercise.name) else {
                return nil
            }

            let reps = normalizedAIReps(for: exercise)
            let setsText = exercise.sets.map(String.init) ?? (reps.isEmpty ? "" : "1")

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
        presentation.exercises.map { exercise in
            EditableWorkoutCard(
                name: exercise.name,
                sets: exercise.sets.map(String.init) ?? "",
                reps: exercise.reps.map(String.init) ?? "",
                weight: exercise.weight ?? "",
                restSeconds: exercise.restSeconds.map(String.init) ?? ""
            )
        }
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

        if let rounds, rounds > 0 {
            lines.append("\(rounds) Rounds")
        }

        for card in usableCards {
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
