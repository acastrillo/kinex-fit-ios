import SwiftUI

/// Edit view for Instagram-fetched workout before saving.
/// Uses the shared WorkoutCardEditor for card-based exercise editing.
struct InstagramWorkoutEditView: View {
    let fetchedWorkout: FetchedWorkout
    let onSave: (String, String?) async throws -> Void
    let onDiscard: () -> Void

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var workoutCards: [EditableWorkoutCard]
    @State private var rounds: Int?
    @State private var isSaving = false
    @State private var isEnhancing = false
    @State private var error: Error?
    @State private var showingError = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case description
    }

    init(
        fetchedWorkout: FetchedWorkout,
        onSave: @escaping (String, String?) async throws -> Void,
        onDiscard: @escaping () -> Void
    ) {
        self.fetchedWorkout = fetchedWorkout
        self.onSave = onSave
        self.onDiscard = onDiscard

        let parsedTitle = fetchedWorkout.parsedData.title ?? fetchedWorkout.title
        let parsedRounds = fetchedWorkout.parsedData.structure?.rounds
        let exercises = fetchedWorkout.parsedData.exercises

        _title = State(initialValue: parsedTitle)
        _description = State(initialValue: fetchedWorkout.parsedData.summary ?? "")
        _workoutCards = State(initialValue: EditableWorkoutCard.from(exercises: exercises, rounds: parsedRounds))
        _rounds = State(initialValue: parsedRounds)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var composedContent: String {
        EditableWorkoutCard.composeContent(notes: description, cards: workoutCards, rounds: rounds)
    }

    private var enhancementInput: String {
        let original = fetchedWorkout.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !original.isEmpty {
            return original
        }
        return composedContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var platformColor: Color {
        switch fetchedWorkout.sourcePlatform {
        case .instagram: return .pink
        case .tiktok: return .cyan
        case .unknown: return .blue
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection

                    // Instagram image preview
                    imagePreview

                    // Source info card
                    sourceInfoSection

                    // Quota indicator
                    if fetchedWorkout.hasQuotaInfo,
                       let used = fetchedWorkout.quotaUsed,
                       let limit = fetchedWorkout.quotaLimit {
                        InstagramQuotaIndicator(used: used, limit: limit)
                    }

                    // Imported workout preview with original caption + AI enhance
                    importedWorkoutCard

                    // Rounds indicator
                    if let rounds, rounds > 0 {
                        roundsCard(rounds: rounds)
                    }

                    // Workout details (title, description, summary, save)
                    workoutDetailsCard

                    // Editable exercise cards
                    WorkoutCardEditor(
                        cards: $workoutCards,
                        defaultRestSeconds: 60,
                        rounds: rounds
                    )
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        onDiscard()
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.primaryText)
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
            .overlay {
                if isSaving {
                    savingOverlay
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(error?.localizedDescription ?? "An error occurred")
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Create New Workout")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(2)

            Text("Review and save your imported workout")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    // MARK: - Image Preview

    private var imagePreview: some View {
        Group {
            if let imageURLString = fetchedWorkout.imageURL,
               let imageURL = URL(string: imageURLString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    case .failure:
                        EmptyView()
                    case .empty:
                        ProgressView()
                            .frame(height: 150)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
    }

    // MARK: - Source Info

    private var sourceInfoSection: some View {
        HStack(spacing: 12) {
            Image(systemName: fetchedWorkout.sourcePlatform.iconName)
                .foregroundStyle(platformColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("From \(fetchedWorkout.sourcePlatform.displayName)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                if let author = fetchedWorkout.author {
                    Text("@\(author.username)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(fetchedWorkout.workoutType)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .kinexCard(cornerRadius: 6, fill: AppTheme.cardBackgroundElevated)

                Text("\(fetchedWorkout.exerciseCount) exercises")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.tertiaryText)
            }
        }
        .padding(14)
        .kinexCard(cornerRadius: 14)
    }

    // MARK: - Imported Workout Card (caption + enhance)

    private var importedWorkoutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Imported Workout", systemImage: "checkmark.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)

                Spacer(minLength: 8)

                Button {
                    Task { await enhanceWithAI() }
                } label: {
                    HStack(spacing: 6) {
                        if isEnhancing {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isEnhancing ? "Enhancing..." : "Enhance with AI")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                }
                .buttonStyle(.plain)
                .disabled(isEnhancing || enhancementInput.isEmpty)
            }

            // Show parsed exercise summary
            if !fetchedWorkout.parsedData.exercises.isEmpty {
                Rectangle()
                    .fill(AppTheme.separator)
                    .frame(height: 1)

                ForEach(Array(fetchedWorkout.parsedData.exercises.enumerated()), id: \.offset) { index, exercise in
                    HStack(spacing: 8) {
                        Text("\u{2022}")
                            .foregroundStyle(AppTheme.accent)
                        Text(exerciseSummaryLine(exercise))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                    }
                }
            }

            Rectangle()
                .fill(AppTheme.separator)
                .frame(height: 1)

            Text("Original Caption:")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.accent)

            ScrollView {
                Text(fetchedWorkout.content.isEmpty ? "No caption available." : fetchedWorkout.content)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 80, maxHeight: 150)
        }
        .padding(14)
        .kinexCard(cornerRadius: 16)
    }

    // MARK: - Rounds Card

    private func roundsCard(rounds: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("ROUNDS WORKOUT", systemImage: "sparkles")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.tertiaryText)

            Text("\u{2022} Rounds: \(rounds)")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)
        }
        .padding(14)
        .kinexCard(cornerRadius: 14)
    }

    // MARK: - Workout Details Card

    private var workoutDetailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Workout Details")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            VStack(alignment: .leading, spacing: 7) {
                Text("Workout Name")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)

                TextField("Workout Name", text: $title)
                    .focused($focusedField, equals: .title)
                    .textInputAutocapitalization(.words)
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .kinexCard(cornerRadius: 10, fill: AppTheme.cardBackgroundElevated)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Description")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $description)
                        .focused($focusedField, equals: .description)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(minHeight: 100)

                    if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Add notes about this workout...")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(AppTheme.tertiaryText)
                            .padding(.top, 8)
                            .padding(.leading, 6)
                            .allowsHitTesting(false)
                    }
                }
                .padding(10)
                .kinexCard(cornerRadius: 12, fill: AppTheme.cardBackgroundElevated)
            }

            Rectangle()
                .fill(AppTheme.separator)
                .frame(height: 1)

            // Summary
            VStack(alignment: .leading, spacing: 6) {
                Text("Summary")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                let cardCount = workoutCards.filter { !$0.trimmedName.isEmpty }.count
                let totalCards = rounds != nil ? cardCount * (rounds ?? 1) : cardCount

                Text("Cards: \(totalCards)")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)

                Text("Exercises: \(cardCount)")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)

                if let duration = fetchedWorkout.parsedData.workoutV1?.totalDuration {
                    Text("Est. Duration: \(duration) min")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Text("Source: \(fetchedWorkout.sourcePlatform.displayName)")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)

                if let author = fetchedWorkout.author {
                    Text("From: @\(author.username)")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            // Save button
            Button {
                Task { await save() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                    Text("Save New Workout")
                }
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(AppTheme.accent.opacity(isValid ? 1.0 : 0.45))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: AppTheme.accent.opacity(0.35), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!isValid || isSaving || isEnhancing)
        }
        .padding(14)
        .kinexCard(cornerRadius: 16)
    }

    // MARK: - Saving Overlay

    private var savingOverlay: some View {
        ZStack {
            AppTheme.background.opacity(0.82)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .tint(AppTheme.accent)
                Text("Saving workout...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    // MARK: - Helpers

    private func exerciseSummaryLine(_ exercise: ExerciseData) -> String {
        var parts: [String] = [exercise.name]
        if let reps = exercise.reps {
            parts.insert(reps, at: 0)
        }
        if let weight = exercise.weight {
            parts.append("@ \(weight)")
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Actions

    private func enhanceWithAI() async {
        let input = enhancementInput
        guard !input.isEmpty else { return }

        isEnhancing = true
        defer { isEnhancing = false }

        let aiService = AIService(apiClient: appState.environment.apiClient)

        do {
            let response = try await aiService.enhanceWorkout(text: input)
            if let remaining = response.quotaRemaining {
                try? await appState.environment.userRepository.updateAIQuotaFromRemaining(remaining)
            }
            title = response.workout.title

            if let exercises = response.workout.exercises {
                let aiCards = EditableWorkoutCard.from(enhancedExercises: exercises)
                if !aiCards.isEmpty {
                    workoutCards = aiCards
                }
            }

            if let desc = response.workout.description?.trimmingCharacters(in: .whitespacesAndNewlines) {
                description = desc
            }

            if let structure = response.workout.structure, let r = structure.rounds, r > 0 {
                rounds = r
            }
        } catch {
            self.error = error
            showingError = true
        }
    }

    private func save() async {
        focusedField = nil
        isSaving = true

        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let savedContent = composedContent.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await onSave(trimmedTitle, savedContent.isEmpty ? nil : savedContent)
            dismiss()
        } catch {
            self.error = error
            showingError = true
        }

        isSaving = false
    }
}

// MARK: - Preview

#Preview {
    let mockWorkout = FetchedWorkout(
        from: InstagramFetchResponse(
            url: "https://instagram.com/p/test",
            title: "FLEX Program",
            content: "8 Rounds. How fast can you finish it? \u{1F4A5} Drop your time \u{2B07}\u{FE0F}\n\n2 Wall Walks\n6 Pull-Ups (6 Kipping or 4 Strict)\n10 Push-Ups\n14 Kettlebell Swings",
            author: AuthorInfo(username: "fitnessacademy", fullName: "Fitness Academy"),
            stats: PostStats(likes: 1250, comments: 45),
            image: nil,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            mediaType: "image",
            parsedWorkout: nil,
            scanQuotaUsed: 5,
            scanQuotaLimit: 10,
            quotaUsed: 5,
            quotaLimit: 10
        ),
        ingestResponse: WorkoutIngestResponse(
            title: "FLEX Program",
            workoutType: "rounds",
            exercises: [
                ExerciseData(id: "1", name: "Wall Ball", sets: 8, reps: "2", weight: "20 lb", unit: "reps", notes: nil, restSeconds: 60),
                ExerciseData(id: "2", name: "Pull-Up", sets: 8, reps: "6", weight: nil, unit: "reps", notes: nil, restSeconds: 60),
                ExerciseData(id: "3", name: "Push-up", sets: 8, reps: "10", weight: nil, unit: "reps", notes: nil, restSeconds: 60),
                ExerciseData(id: "4", name: "Kettlebell Swing", sets: 8, reps: "14", weight: "53 lb", unit: "reps", notes: nil, restSeconds: 60)
            ],
            rows: nil,
            summary: "8 rounds of 4 exercises.",
            breakdown: nil,
            structure: WorkoutStructure(type: "rounds", timeLimit: nil, rounds: 8, interval: nil, work: nil, rest: nil),
            amrapBlocks: nil,
            emomBlocks: nil,
            usedLLM: false,
            workoutV1: WorkoutV1(name: "FLEX Program", totalDuration: 15, difficulty: "Moderate", tags: ["crossfit"])
        )
    )

    InstagramWorkoutEditView(
        fetchedWorkout: mockWorkout,
        onSave: { _, _ in },
        onDiscard: { }
    )
    .environmentObject(AppState(environment: .preview))
    .appDarkTheme()
}
