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
    let onSave: (String, String?) async throws -> Void

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

    init(mode: Mode, onSave: @escaping (String, String?) async throws -> Void) {
        self.mode = mode
        self.onSave = onSave

        switch mode {
        case .create:
            _title = State(initialValue: "")
            _content = State(initialValue: "")
            _originalContent = State(initialValue: "")
            _workoutCards = State(initialValue: [])
            _rounds = State(initialValue: nil)
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
            _originalContent = State(initialValue: existingContent)
            _workoutCards = State(initialValue: EditableWorkoutCard.from(presentation: initialPresentation))
            _rounds = State(initialValue: initialPresentation.rounds)
        }
    }

    private var parserSource: WorkoutSource {
        if case .edit(let workout) = mode {
            return workout.source
        }
        return .manual
    }

    private var parserDuration: Int? {
        if case .edit(let workout) = mode {
            return workout.durationMinutes
        }
        return nil
    }

    private var parserExerciseCount: Int? {
        if case .edit(let workout) = mode {
            return workout.exerciseCount
        }
        return nil
    }

    private var composedContent: String {
        EditableWorkoutCard.composeContent(notes: content, cards: workoutCards, rounds: rounds)
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
                .disabled(isEnhancing || composedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Rectangle()
                .fill(AppTheme.separator)
                .frame(height: 1)

            Text("Original Caption:")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.accent)

            ScrollView {
                Text(originalContent.isEmpty ? "No original caption available." : originalContent)
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

    private func applyParsedContent(_ rawContent: String) {
        let parsed = WorkoutContentPresentation.from(
            content: rawContent,
            source: parserSource,
            durationMinutes: parserDuration,
            fallbackExerciseCount: parserExerciseCount
        )
        content = EditableWorkoutCard.extractNotes(from: rawContent, exercises: parsed.exercises)
        rounds = parsed.rounds
        workoutCards = EditableWorkoutCard.from(presentation: parsed)
    }

    private func enhanceWithAI() async {
        let input = composedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        isEnhancing = true
        defer { isEnhancing = false }

        let aiService = AIService(apiClient: appState.environment.apiClient)

        do {
            let response = try await aiService.enhanceWorkout(text: input)
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
        if let exercises = workout.exercises, !exercises.isEmpty {
            workoutCards = EditableWorkoutCard.from(enhancedExercises: exercises)

            var notes: [String] = []
            if let desc = workout.description, !desc.isEmpty {
                notes.append(desc)
            }
            if let aiNotes = workout.aiNotes, !aiNotes.isEmpty {
                notes.append("")
                notes.append(contentsOf: aiNotes.map { "- \($0)" })
            }
            content = notes.joined(separator: "\n")

            if let structure = workout.structure, let r = structure.rounds, r > 0 {
                rounds = r
            }
        } else {
            applyParsedContent(workout.content)
        }
    }

    private func save() async {
        focusedField = nil
        isSaving = true

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = composedContent.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await onSave(trimmedTitle, trimmedContent.isEmpty ? nil : trimmedContent)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }

        isSaving = false
    }
}

#Preview("Create") {
    WorkoutFormView(mode: .create) { _, _ in }
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
    ) { _, _ in }
    .environmentObject(AppState(environment: .preview))
    .appDarkTheme()
}
