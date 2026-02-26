import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout
    var onUpdate: ((Workout) async throws -> Void)?
    var onDelete: (() async throws -> Void)?

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var isEnhancing = false
    @State private var enhancementError: String?
    @State private var showingEnhancementError = false
    @State private var showingSession = false

    private var presentation: WorkoutContentPresentation {
        WorkoutContentPresentation.from(
            content: workout.content,
            source: workout.source,
            durationMinutes: workout.durationMinutes,
            fallbackExerciseCount: workout.exerciseCount
        )
    }

    private var displayedDifficulty: String {
        workout.difficulty?.capitalized ?? "Moderate"
    }

    private var sourceHandle: String {
        if let author = workout.sourceAuthor, !author.isEmpty {
            return "@\(author)"
        }
        switch workout.source {
        case .instagram:
            return "@instagram"
        case .tiktok:
            return "@tiktok"
        case .imported:
            return "@imported"
        case .manual:
            return "@manual"
        case .ocr:
            return "@scan"
        }
    }

    private var sourceLink: URL? {
        // Prefer linking to the original post if available
        if let sourceURL = workout.sourceURL, let url = URL(string: sourceURL) {
            return url
        }
        // Fall back to the author's profile
        if let author = workout.sourceAuthor, !author.isEmpty {
            switch workout.source {
            case .instagram:
                return URL(string: "https://instagram.com/\(author)")
            case .tiktok:
                return URL(string: "https://tiktok.com/@\(author)")
            default:
                return nil
            }
        }
        return nil
    }

    private var shareText: String {
        let details: String
        let exerciseLines = presentation.exercises
            .prefix(8)
            .map { "\($0.index). \($0.name)" }

        if !exerciseLines.isEmpty {
            details = exerciseLines.joined(separator: "\n")
        } else if !presentation.rawContent.isEmpty {
            details = presentation.rawContent
        } else {
            details = "Custom workout created in Kinex Fit"
        }

        return """
        \(workout.title)
        \(presentation.subtitle)

        \(details)
        """
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                titleSection
                topActions
                secondaryActions
                metadataStrip
                startWorkoutButton
                exercisesSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .padding(.bottom, 24)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isEnhancing {
                    ProgressView()
                        .tint(AppTheme.accent)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            WorkoutFormView(
                mode: .edit(workout),
                onSave: { title, content in
                    var updated = workout
                    updated.title = title
                    updated.content = content
                    try await onUpdate?(updated)
                }
            )
        }
        .alert("Enhancement Failed", isPresented: $showingEnhancementError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(enhancementError ?? "Failed to enhance workout")
        }
        .alert("Delete Workout?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await deleteWorkout() }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .navigationDestination(isPresented: $showingSession) {
            WorkoutSessionView(workout: workout)
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(workout.title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(3)
                .minimumScaleFactor(0.82)

            Text(presentation.subtitle)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
    }

    private var topActions: some View {
        HStack(spacing: 8) {
            Button {
                Task { await enhanceWithAI() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text(isEnhancing ? "Enhancing..." : "Enhance with AI")
                }
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .kinexCard(cornerRadius: 12, fill: AppTheme.cardBackground)
            }
            .buttonStyle(.plain)
            .disabled(isEnhancing || presentation.rawContent.isEmpty)

            Button { showingSession = true } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .kinexCard(cornerRadius: 12, fill: AppTheme.cardBackground)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quick Start")
        }
    }

    private var secondaryActions: some View {
        HStack(spacing: 8) {
            Button {
                showingEditSheet = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .kinexCard(cornerRadius: 12, fill: AppTheme.cardBackground)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit Workout")

            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 42, height: 42)
                    .kinexCard(cornerRadius: 12, fill: AppTheme.cardBackground)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share Workout")

            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.error)
                    .frame(width: 42, height: 42)
                    .kinexCard(cornerRadius: 12, fill: AppTheme.cardBackground)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete Workout")

            Spacer()
        }
    }

    private var metadataStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                metadataChip(icon: "clock", text: presentation.formattedDuration)
                metadataChip(icon: "scope", text: displayedDifficulty)
                sourceChip
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var sourceChip: some View {
        if let url = sourceLink {
            Link(destination: url) {
                metadataChip(icon: "person", text: sourceHandle, tappable: true)
            }
        } else {
            metadataChip(icon: "person", text: sourceHandle)
        }
    }

    private var startWorkoutButton: some View {
        Button { showingSession = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text("Start Workout")
            }
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                LinearGradient(
                    colors: [AppTheme.accent, Color(red: 1.0, green: 0.50, blue: 0.22)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: AppTheme.accent.opacity(0.42), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Start an active workout session")
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Exercises (\(max(presentation.exercises.count, workout.exerciseCount ?? presentation.exercises.count)))")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
            }

            if presentation.exercises.isEmpty {
                emptyExerciseState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(presentation.exercises) { exercise in
                        workoutExerciseCard(exercise)
                    }
                }
            }
        }
        .padding(12)
        .kinexCard(cornerRadius: 16)
    }

    private var emptyExerciseState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workout Details")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)

            if presentation.rawContent.isEmpty {
                Text("No workout content yet.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                Text(presentation.rawContent)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .kinexCard(cornerRadius: 10, fill: AppTheme.cardBackgroundElevated)
            }
        }
    }

    private func workoutExerciseCard(_ exercise: WorkoutContentPresentation.Exercise) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(exercise.index)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(minWidth: 16, alignment: .leading)

                Text(exercise.name)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            Text("Rest \(exercise.restSeconds ?? presentation.restSeconds ?? 60)s between sets")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)

            HStack(spacing: 18) {
                statColumn(value: "\(exercise.sets ?? presentation.rounds ?? 1)", label: "sets")
                statColumn(value: "\(exercise.reps ?? 0)", label: "reps")
                if let weight = exercise.weight {
                    statColumn(value: weight, label: "weight")
                }
                statColumn(value: "\(exercise.restSeconds ?? presentation.restSeconds ?? 60)s", label: "rest")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .kinexCard(cornerRadius: 14, fill: AppTheme.cardBackgroundElevated)
    }

    private func metadataChip(icon: String, text: String, tappable: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
            if tappable {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(tappable ? AppTheme.accent : AppTheme.secondaryText)
        .lineLimit(1)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(AppTheme.cardBackgroundElevated)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(tappable ? AppTheme.accent.opacity(0.4) : AppTheme.cardBorder, lineWidth: 1)
        }
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private func deleteWorkout() async {
        do {
            try await onDelete?()
            dismiss()
        } catch {
            // Keep existing behavior non-blocking for now.
        }
    }

    private func enhanceWithAI() async {
        guard !presentation.rawContent.isEmpty else { return }

        isEnhancing = true
        defer { isEnhancing = false }

        let aiService = AIService(apiClient: appState.environment.apiClient)

        do {
            let response = try await aiService.enhanceWorkout(text: presentation.rawContent)
            if let remaining = response.quotaRemaining {
                try? await appState.environment.userRepository.updateAIQuotaFromRemaining(remaining)
            }
            var updated = workout
            updated.title = response.workout.title
            updated.content = Self.composeEnhancedContent(
                description: response.workout.description,
                exercises: response.workout.exercises,
                aiNotes: response.workout.aiNotes,
                fallback: response.workout.content
            )
            try await onUpdate?(updated)
        } catch let error as AIError {
            enhancementError = error.errorDescription ?? "Enhancement failed"
            showingEnhancementError = true
        } catch {
            enhancementError = error.localizedDescription
            showingEnhancementError = true
        }
    }

    /// Compose a content string from structured AI response data.
    /// Uses the exercises array to produce standard exercise notation.
    private static func composeEnhancedContent(
        description: String?,
        exercises: [EnhancedExercise]?,
        aiNotes: [String]?,
        fallback: String
    ) -> String {
        guard let exercises = exercises, !exercises.isEmpty else {
            return fallback
        }

        var lines: [String] = []

        if let desc = description, !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(desc.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")
        }

        for exercise in exercises {
            var line = exercise.name
            if let sets = exercise.sets, let reps = exercise.reps {
                line += " \(sets)x\(reps.stringValue)"
            } else if let sets = exercise.sets {
                line += " \(sets) sets"
            } else if let reps = exercise.reps {
                line += " \(reps.stringValue) reps"
            }
            if let weight = exercise.weight {
                line += " @ \(weight)"
            }
            if let rest = exercise.restSeconds {
                line += " (\(rest)s rest)"
            }
            if let notes = exercise.notes, !notes.isEmpty {
                line += " - \(notes)"
            }
            lines.append(line)
        }

        if let notes = aiNotes, !notes.isEmpty {
            lines.append("")
            lines.append(contentsOf: notes.map { "- \($0)" })
        }

        return lines.joined(separator: "\n")
    }
}

#Preview("Workout Detail") {
    NavigationStack {
        WorkoutDetailView(
            workout: Workout(
                title: "FLEX Program",
                content: """
                8 Rounds. How fast can you finish it?

                2 Wall Walks
                6 Pull-Ups
                10 Push-Ups
                14 Kettlebell Swings
                Rest 60s between sets
                """,
                source: .instagram,
                durationMinutes: 64,
                exerciseCount: 4,
                difficulty: "moderate"
            ),
            onUpdate: { _ in },
            onDelete: { }
        )
    }
    .appDarkTheme()
}

/// Parsed workout content that powers the web-style presentation in detail and edit screens.
struct WorkoutContentPresentation {
    struct Exercise: Identifiable, Hashable {
        let id: String
        let index: Int
        let name: String
        let reps: Int?
        let sets: Int?
        let weight: String?
        let restSeconds: Int?
    }

    let rounds: Int?
    let exercises: [Exercise]
    let restSeconds: Int?
    let estimatedDurationMinutes: Int?
    let source: WorkoutSource
    let rawContent: String
    let summaryExerciseCount: Int
    let summaryCardCount: Int

    var subtitle: String {
        if let rounds, summaryExerciseCount > 0 {
            let perRound = max(summaryExerciseCount / max(rounds, 1), 1)
            return "\(rounds) rounds of \(perRound) exercises."
        }
        if summaryExerciseCount > 0 {
            return "\(summaryExerciseCount) exercises."
        }
        return "Workout"
    }

    var formattedDuration: String {
        guard let estimatedDurationMinutes, estimatedDurationMinutes > 0 else {
            return "0m"
        }
        let hours = estimatedDurationMinutes / 60
        let minutes = estimatedDurationMinutes % 60
        if hours > 0 {
            return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    static func from(
        content: String?,
        source: WorkoutSource,
        durationMinutes: Int?,
        fallbackExerciseCount: Int?
    ) -> WorkoutContentPresentation {
        let rawContent = (content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = rawContent
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let rounds = firstIntegerMatch(in: rawContent, pattern: #"(?i)\b(\d{1,2})\s*rounds?\b"#)
        let globalRestSeconds = firstIntegerMatch(
            in: rawContent,
            pattern: #"(?i)\brest\b[^0-9]{0,10}(\d{1,3})\s*(?:s|sec|secs|seconds)\b"#
        )

        let parsedExercises = parseExercises(
            from: lines,
            rounds: rounds,
            fallbackRestSeconds: globalRestSeconds
        )
        let exerciseCount = max(
            fallbackExerciseCount ?? 0,
            parsedExercises.count
        )
        let summaryExerciseCount: Int
        if let rounds, rounds > 1, exerciseCount > 0 {
            summaryExerciseCount = rounds * exerciseCount
        } else {
            summaryExerciseCount = exerciseCount
        }

        let summaryCardCount: Int
        if let rounds, rounds > 1, exerciseCount > 0 {
            // Mirrors web semantics where rest cards can appear between rounds.
            summaryCardCount = summaryExerciseCount + max(rounds - 1, 0)
        } else {
            summaryCardCount = summaryExerciseCount
        }

        let inferredDuration = inferDurationMinutes(
            explicitDuration: durationMinutes,
            content: rawContent,
            rounds: rounds,
            exerciseCount: exerciseCount,
            restSeconds: globalRestSeconds
        )

        return WorkoutContentPresentation(
            rounds: rounds,
            exercises: parsedExercises,
            restSeconds: globalRestSeconds,
            estimatedDurationMinutes: inferredDuration,
            source: source,
            rawContent: rawContent,
            summaryExerciseCount: summaryExerciseCount,
            summaryCardCount: summaryCardCount
        )
    }

    private static func parseExercises(
        from lines: [String],
        rounds: Int?,
        fallbackRestSeconds: Int?
    ) -> [Exercise] {
        var exercises: [Exercise] = []

        for rawLine in lines {
            let cleanedLine = normalizeLine(rawLine)
            guard shouldKeepExerciseLine(cleanedLine, rounds: rounds) else { continue }

            let repsFromPrefix = capture(in: cleanedLine, pattern: #"^(\d{1,3})\s+(.+)$"#)
            let reps = repsFromPrefix.flatMap { Int($0[0]) }
            let lineWithoutPrefix = repsFromPrefix.map { $0[1] } ?? cleanedLine

            let sets = firstIntegerMatch(in: lineWithoutPrefix, pattern: #"(?i)\b(\d{1,2})\s*sets?\b"#)
            let repsFromSetsPattern = firstIntegerMatch(
                in: lineWithoutPrefix,
                pattern: #"(?i)\b\d{1,2}\s*[xX]\s*(\d{1,3})\b"#
            )
            let weightCapture = capture(
                in: lineWithoutPrefix,
                pattern: #"(?i)\b(\d+(?:\.\d+)?)\s*(lb|lbs|kg|kgs)\b"#
            )
            let localRest = firstIntegerMatch(
                in: lineWithoutPrefix,
                pattern: #"(?i)\brest\b[^0-9]{0,10}(\d{1,3})\s*(?:s|sec|secs|seconds)\b"#
            )

            let name = sanitizeExerciseName(lineWithoutPrefix)
            guard !name.isEmpty else { continue }

            let index = exercises.count + 1
            let weight: String?
            if let capture = weightCapture {
                weight = "\(capture[0]) \(capture[1].lowercased())"
            } else {
                weight = nil
            }

            exercises.append(
                Exercise(
                    id: "exercise-\(index)-\(name.lowercased())",
                    index: index,
                    name: name,
                    reps: reps ?? repsFromSetsPattern,
                    sets: sets,
                    weight: weight,
                    restSeconds: localRest ?? fallbackRestSeconds
                )
            )

            if exercises.count >= 24 {
                break
            }
        }

        return exercises
    }

    private static func shouldKeepExerciseLine(_ line: String, rounds: Int?) -> Bool {
        guard !line.isEmpty else { return false }
        let lowered = line.lowercased()

        if lowered.contains("http://") || lowered.contains("https://") || lowered.contains("www.") {
            return false
        }
        if lowered.hasPrefix("#") || lowered.contains(" #") || lowered.contains("workoutmotivation") {
            return false
        }
        if lowered.hasPrefix("training:") || lowered.hasPrefix("source:") || lowered.hasPrefix("original caption") {
            return false
        }
        if lowered.hasPrefix("rest ") || lowered.hasPrefix("rest:") || lowered.hasPrefix("round rest") {
            return false
        }
        if lowered.contains("drop your time") && lowered.contains("round") {
            return false
        }
        if let rounds, lowered == "\(rounds) rounds" {
            return false
        }
        if !line.contains(where: { $0.isLetter }) {
            return false
        }

        let words = line.split(separator: " ")
        if words.count > 14 {
            return false
        }

        return true
    }

    private static func normalizeLine(_ line: String) -> String {
        var normalized = line
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\t", with: " ")
        normalized = normalized.replacingOccurrences(
            of: #"^[\-\*•]+\s*"#,
            with: "",
            options: .regularExpression
        )
        return normalized
    }

    private static func sanitizeExerciseName(_ raw: String) -> String {
        var output = raw
            .replacingOccurrences(
                of: #"(?i)\b\d{1,2}\s*x\s*\d{1,3}\b"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?i)\b\d{1,2}\s*sets?\b"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?i)\b\d{1,3}\s*(?:reps?|times)\b"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?i)\b\d+(?:\.\d+)?\s*(lb|lbs|kg|kgs)\b"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?i)\brest\b[^0-9]{0,10}\d{1,3}\s*(?:s|sec|secs|seconds)\b"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: CharacterSet(charactersIn: ":-,() ").union(.whitespacesAndNewlines))

        if output.contains("("), output.contains(")") {
            output = output.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        }

        return output
    }

    private static func inferDurationMinutes(
        explicitDuration: Int?,
        content: String,
        rounds: Int?,
        exerciseCount: Int,
        restSeconds: Int?
    ) -> Int? {
        if let explicitDuration, explicitDuration > 0 {
            return explicitDuration
        }

        if let minutesFromText = firstIntegerMatch(
            in: content,
            pattern: #"(?i)\b(\d{1,3})\s*(?:min|mins|minute|minutes)\b"#
        ) {
            return minutesFromText
        }

        guard exerciseCount > 0 else { return nil }

        let roundsCount = max(rounds ?? 1, 1)
        let defaultWorkSeconds = 45
        let inferredRest = restSeconds ?? 60
        let totalWork = roundsCount * exerciseCount * defaultWorkSeconds
        let totalRest = max(roundsCount * exerciseCount - 1, 0) * inferredRest
        let totalMinutes = Int((Double(totalWork + totalRest) / 60.0).rounded())
        return max(totalMinutes, 1)
    }

    private static func firstIntegerMatch(in source: String, pattern: String) -> Int? {
        capture(in: source, pattern: pattern).flatMap { Int($0[0]) }
    }

    private static func capture(in source: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        guard let match = regex.firstMatch(in: source, options: [], range: range) else {
            return nil
        }

        var captures: [String] = []
        for idx in 1..<match.numberOfRanges {
            let nsRange = match.range(at: idx)
            guard let swiftRange = Range(nsRange, in: source) else {
                captures.append("")
                continue
            }
            captures.append(String(source[swiftRange]))
        }
        return captures
    }
}
