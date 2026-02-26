import SwiftUI

/// Review view for Instagram imports from the Share Extension.
/// Uses the shared WorkoutCardEditor for card-based exercise editing.
struct InstagramImportReviewView: View {
    let importItem: InstagramImport
    let onSave: (String, String?) async throws -> Void
    let onDiscard: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var workoutCards: [EditableWorkoutCard] = []
    @State private var rounds: Int? = nil
    @State private var mediaImage: UIImage?
    @State private var isProcessing = false
    @State private var isSaving = false
    @State private var isEnhancing = false
    @State private var error: Error?
    @State private var showingError = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case description
    }

    private var importService: InstagramImportService {
        appState.instagramImportService
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var composedContent: String {
        EditableWorkoutCard.composeContent(notes: description, cards: workoutCards, rounds: rounds)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection

                    // Media preview
                    if let image = mediaImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Source info
                    sourceInfoSection

                    if isProcessing {
                        processingView
                    } else {
                        // Imported workout card with enhance
                        importedWorkoutCard

                        // Rounds indicator
                        if let rounds, rounds > 0 {
                            roundsCard(rounds: rounds)
                        }

                        // Workout details
                        workoutDetailsCard

                        // Exercise cards editor
                        WorkoutCardEditor(
                            cards: $workoutCards,
                            defaultRestSeconds: 60,
                            rounds: rounds
                        )
                    }
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
        .task {
            await loadData()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Import Workout")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(2)

            Text("Review and save your shared workout")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    // MARK: - Source Info

    private var sourceInfoSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.on.rectangle")
                .foregroundStyle(.pink)

            VStack(alignment: .leading, spacing: 2) {
                Text("Instagram Import")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                if let url = importItem.postURL {
                    Text(url)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(importItem.mediaType.rawValue.capitalized)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .kinexCard(cornerRadius: 6, fill: AppTheme.cardBackgroundElevated)
        }
        .padding(14)
        .kinexCard(cornerRadius: 14)
    }

    // MARK: - Processing

    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(AppTheme.accent)
            Text("Extracting text from media...")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Imported Workout Card

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
                .disabled(isEnhancing || composedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let text = importItem.extractedText ?? importItem.captionText, !text.isEmpty {
                Rectangle()
                    .fill(AppTheme.separator)
                    .frame(height: 1)

                Text("Original Text:")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)

                ScrollView {
                    Text(text)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 60, maxHeight: 120)
            }
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

    // MARK: - Workout Details

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

                Text("Exercises: \(cardCount)")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)

                Text("Source: Instagram Share")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
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
            .disabled(!isValid || isSaving || isEnhancing || isProcessing)
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

    // MARK: - Data Loading

    private func loadData() async {
        mediaImage = importService.getMediaImage(for: importItem)

        if importItem.extractedText == nil && importItem.processingStatus == .pending {
            isProcessing = true
            do {
                let processed = try await importService.processImport(importItem)
                await MainActor.run {
                    parseExtractedText(processed.extractedText)
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    showingError = true
                    isProcessing = false
                    parseExtractedText(importItem.captionText)
                }
            }
        } else {
            parseExtractedText(importItem.extractedText ?? importItem.captionText)
        }
    }

    private func parseExtractedText(_ text: String?) {
        guard let text = text, !text.isEmpty else {
            title = "Instagram Workout"
            description = ""
            workoutCards = []
            return
        }

        let parsed = WorkoutTextParser.parse(text)
        title = parsed.title

        // Use WorkoutContentPresentation to extract exercises for card building
        let presentation = WorkoutContentPresentation.from(
            content: text,
            source: .instagram,
            durationMinutes: nil,
            fallbackExerciseCount: nil
        )

        if !presentation.exercises.isEmpty {
            workoutCards = EditableWorkoutCard.from(presentation: presentation)
            rounds = presentation.rounds
            description = EditableWorkoutCard.extractNotes(from: text, exercises: presentation.exercises)
        } else {
            // Fallback: no exercises detected, put text as description
            description = parsed.content
            workoutCards = []
        }
    }

    // MARK: - Actions

    private func enhanceWithAI() async {
        let input = composedContent.trimmingCharacters(in: .whitespacesAndNewlines)
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

            if let exercises = response.workout.exercises, !exercises.isEmpty {
                workoutCards = EditableWorkoutCard.from(enhancedExercises: exercises)

                var notes: [String] = []
                if let desc = response.workout.description, !desc.isEmpty {
                    notes.append(desc)
                }
                if let aiNotes = response.workout.aiNotes, !aiNotes.isEmpty {
                    notes.append("")
                    notes.append(contentsOf: aiNotes.map { "- \($0)" })
                }
                description = notes.joined(separator: "\n")

                if let structure = response.workout.structure, let r = structure.rounds, r > 0 {
                    rounds = r
                }
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
        let trimmedContent = composedContent.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await onSave(trimmedTitle, trimmedContent.isEmpty ? nil : trimmedContent)
            importService.removeImport(importItem)
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
    InstagramImportReviewView(
        importItem: InstagramImport(
            postURL: "https://instagram.com/p/abc123",
            captionText: "Push Day\n\nBench Press 4x8\nOverhead Press 3x10\nTricep Dips 3x12",
            mediaType: .image,
            mediaLocalPath: "test.jpg",
            extractedText: "Push Day\n\nBench Press 4x8\nOverhead Press 3x10\nTricep Dips 3x12"
        ),
        onSave: { _, _ in },
        onDiscard: { }
    )
    .environmentObject(AppState(environment: .preview))
    .appDarkTheme()
}
