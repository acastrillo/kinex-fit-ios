import SwiftUI

struct WorkoutFormView: View {
    enum Mode {
        case create
        case edit(Workout)

        var title: String {
            switch self {
            case .create: return "Create New Workout"
            case .edit: return "Edit Workout"
            }
        }

        var subtitle: String {
            switch self {
            case .create:
                return "Review and save your imported workout"
            case .edit:
                return "Tune details before saving changes"
            }
        }

        var saveButtonTitle: String {
            switch self {
            case .create: return "Save New Workout"
            case .edit: return "Save Workout"
            }
        }
    }

    let mode: Mode
    let onSave: (String, String?, String?) async throws -> Void
    private let createSource: WorkoutSource
    private let createDurationMinutes: Int?
    private let createExerciseCount: Int?

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var content: String
    @State private var originalContent: String
    @State private var workoutCards: [EditableWorkoutCard]
    @State private var rounds: Int?
    @State private var isSaving = false
    @State private var isEnhancing = false
    @State private var errorMessage: String?
    @State private var showingError = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case content
    }

    init(
        mode: Mode,
        initialTitle: String? = nil,
        initialRawContent: String? = nil,
        initialSource: WorkoutSource = .manual,
        initialDurationMinutes: Int? = nil,
        initialExerciseCount: Int? = nil,
        onSave: @escaping (String, String?, String?) async throws -> Void
    ) {
        self.mode = mode
        self.onSave = onSave
        self.createSource = initialSource
        self.createDurationMinutes = initialDurationMinutes
        self.createExerciseCount = initialExerciseCount

        let normalizedInitialTitle = initialTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedInitialContent = initialRawContent?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .create:
            guard let rawContent = normalizedInitialContent, !rawContent.isEmpty else {
                _title = State(initialValue: normalizedInitialTitle ?? "")
                _content = State(initialValue: "")
                _originalContent = State(initialValue: "")
                _workoutCards = State(initialValue: [])
                _rounds = State(initialValue: nil)
                return
            }

            let parsed = WorkoutContentPresentation.from(
                content: rawContent,
                source: initialSource,
                durationMinutes: initialDurationMinutes,
                fallbackExerciseCount: initialExerciseCount
            )
            let fallbackTitle = WorkoutTextParser.parse(rawContent).title
            let resolvedTitle = (normalizedInitialTitle?.isEmpty == false ? normalizedInitialTitle : fallbackTitle) ?? fallbackTitle
            _title = State(initialValue: resolvedTitle)
            _content = State(initialValue: EditableWorkoutCard.extractNotes(from: rawContent, exercises: parsed.exercises))
            _originalContent = State(initialValue: rawContent)
            _workoutCards = State(initialValue: EditableWorkoutCard.from(presentation: parsed))
            _rounds = State(initialValue: parsed.rounds)
        case .edit(let workout):
            let existingContent = workout.content ?? ""
            let initialPresentation = WorkoutContentPresentation.from(
                content: existingContent,
                source: workout.source,
                durationMinutes: workout.durationMinutes,
                fallbackExerciseCount: workout.exerciseCount
            )

            _title = State(initialValue: workout.title)
            _content = State(initialValue: EditableWorkoutCard.extractNotes(from: existingContent, exercises: initialPresentation.exercises))
            _originalContent = State(initialValue: workout.enhancementSourceText ?? existingContent)
            _workoutCards = State(initialValue: EditableWorkoutCard.from(presentation: initialPresentation))
            _rounds = State(initialValue: initialPresentation.rounds)
        }
    }

    private var parserSource: WorkoutSource {
        if case .edit(let workout) = mode {
            return workout.source
        }
        return createSource
    }

    private var parserDuration: Int? {
        if case .edit(let workout) = mode {
            return workout.durationMinutes
        }
        return createDurationMinutes
    }

    private var parserExerciseCount: Int? {
        if case .edit(let workout) = mode {
            return workout.exerciseCount
        }
        return createExerciseCount
    }

    private var composedContent: String {
        EditableWorkoutCard.composeContent(notes: content, cards: workoutCards, rounds: rounds)
    }

    private var enhancementInput: String {
        let rawOriginal = originalContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rawOriginal.isEmpty {
            return rawOriginal
        }
        return composedContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var presentation: WorkoutContentPresentation {
        WorkoutContentPresentation.from(
            content: composedContent,
            source: parserSource,
            durationMinutes: parserDuration,
            fallbackExerciseCount: parserExerciseCount
        )
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    importedWorkoutCard

                    if let rounds, rounds > 0 {
                        roundsCard(rounds: rounds)
                    }

                    workoutDetailsCard

                    WorkoutCardEditor(
                        cards: $workoutCards,
                        defaultRestSeconds: presentation.restSeconds ?? 60,
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
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.primaryText)
                    .disabled(isSaving || isEnhancing)
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
                Text(errorMessage ?? "Failed to save workout")
            }
            .onAppear {
                if case .create = mode {
                    focusedField = .title
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(mode.title)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(2)

            Text(mode.subtitle)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

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
                        Image(systemName: "sparkles")
                        Text(isEnhancing ? "Enhancing..." : "Enhance with AI")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                }
                .buttonStyle(.plain)
                .disabled(isEnhancing || enhancementInput.isEmpty)
            }

            Rectangle()
                .fill(AppTheme.separator)
                .frame(height: 1)

            Text("Original Parsed Input:")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.accent)

            ScrollView {
                Text(originalContent.isEmpty ? "No original parsed input available." : originalContent)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 110, maxHeight: 150)
        }
        .padding(14)
        .kinexCard(cornerRadius: 16)
    }

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
                    TextEditor(text: $content)
                        .focused($focusedField, equals: .content)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(minHeight: 120)

                    if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Describe this workout (goals, intensity, focus areas...)")
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

            VStack(alignment: .leading, spacing: 6) {
                Text("Summary")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Text("Cards: \(presentation.summaryCardCount)")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)

                Text("Exercises: \(presentation.summaryExerciseCount)")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)

                Text("Est. Duration: \(presentation.formattedDuration)")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)

                Text("Source: \(parserSource.displayName)")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Button {
                Task { await save() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                    Text(mode.saveButtonTitle)
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

    private var savingOverlay: some View {
        ZStack {
            AppTheme.background.opacity(0.82)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .tint(AppTheme.accent)
                Text("Saving...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    // MARK: - Actions

    private func enhanceWithAI() async {
        let input = enhancementInput
        guard !input.isEmpty else { return }

        if originalContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            originalContent = input
        }

        isEnhancing = true
        defer { isEnhancing = false }

        let aiService = AIService(apiClient: appState.environment.apiClient)

        do {
            let response = try await aiService.enhanceWorkout(text: input)
            if let remaining = response.quotaRemaining {
                try? await appState.environment.userRepository.updateAIQuotaFromRemaining(remaining)
            }
            title = response.workout.title
            applyEnhancedResponse(response.workout)
        } catch let error as AIError {
            errorMessage = error.errorDescription ?? "Enhancement failed"
            showingError = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func applyEnhancedResponse(_ workout: EnhancedWorkoutData) {
        if let exercises = workout.exercises {
            let aiCards = EditableWorkoutCard.from(enhancedExercises: exercises)
            if !aiCards.isEmpty {
                workoutCards = aiCards
            }
        }

        if let desc = workout.description?.trimmingCharacters(in: .whitespacesAndNewlines) {
            content = desc
        }

        if let structure = workout.structure, let r = structure.rounds, r > 0 {
            rounds = r
        }
    }

    private func save() async {
        focusedField = nil
        isSaving = true

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = composedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEnhancementSource = enhancementInput.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await onSave(
                trimmedTitle,
                trimmedContent.isEmpty ? nil : trimmedContent,
                trimmedEnhancementSource.isEmpty ? nil : trimmedEnhancementSource
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }

        isSaving = false
    }
}

#Preview("Create") {
    WorkoutFormView(mode: .create) { _, _, _ in }
        .environmentObject(AppState(environment: .preview))
        .appDarkTheme()
}

#Preview("Edit") {
    WorkoutFormView(
        mode: .edit(
            Workout(
                title: "FLEX Program",
                content: """
                8 Rounds. How fast can you finish it?
                2 Wall Walks
                6 Pull-Ups
                10 Push-Ups
                14 Kettlebell Swings
                """,
                source: .instagram,
                durationMinutes: 15,
                exerciseCount: 4
            )
        )
    ) { _, _, _ in }
    .environmentObject(AppState(environment: .preview))
    .appDarkTheme()
}
