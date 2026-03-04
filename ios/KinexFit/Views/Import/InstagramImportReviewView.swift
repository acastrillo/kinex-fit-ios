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
    @State private var enhancementSourceText: String = ""
    @State private var mediaImage: UIImage?
    @State private var parsedRestBetweenSets: String?
    @State private var parsingConfidence: Double = 0
    @State private var unresolvedMatches: [PendingMatchResolution] = []
    @State private var unparsedLines: [CaptionUnparsedLine] = []
    @State private var isApplyingParserOutput = false
    @State private var hasInitializedFromParser = false
    @State private var hasUserEditedContent = false
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

    private struct PendingMatchResolution: Identifiable, Equatable {
        var id: String
        var cardID: UUID
        var rawName: String
        var options: [CaptionExerciseOption]
        var selectedOptionID: String

        init(cardID: UUID, rawName: String, options: [CaptionExerciseOption]) {
            self.id = cardID.uuidString
            self.cardID = cardID
            self.rawName = rawName
            self.options = options
            self.selectedOptionID = options.first?.id ?? ""
        }

        var selectedOption: CaptionExerciseOption? {
            options.first(where: { $0.id == selectedOptionID })
        }
    }

    private var importService: InstagramImportService {
        appState.instagramImportService
    }

    private var parsingService: CaptionImportParsingService {
        CaptionImportParsingService(apiClient: appState.environment.apiClient)
    }

    private var sourcePlatform: SocialPlatform {
        guard let url = importItem.postURL else {
            return .instagram
        }
        return SocialPlatform.detect(from: url)
    }

    private var sourceAccentColor: Color {
        switch sourcePlatform {
        case .instagram:
            return .pink
        case .tiktok:
            return .cyan
        case .unknown:
            return .blue
        }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var composedContent: String {
        EditableWorkoutCard.composeContent(notes: description, cards: workoutCards, rounds: rounds)
    }

    private var enhancementInput: String {
        let original = enhancementSourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !original.isEmpty {
            return original
        }
        return composedContent.trimmingCharacters(in: .whitespacesAndNewlines)
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

                        if !unresolvedMatches.isEmpty {
                            unresolvedMatchesCard
                        }

                        if !unparsedLines.isEmpty {
                            unparsedLinesCard
                        }

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
        .onChange(of: title) { _, _ in
            markUserEdited()
        }
        .onChange(of: description) { _, _ in
            markUserEdited()
        }
        .onChange(of: workoutCards) { _, _ in
            markUserEdited()
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
            Image(systemName: sourcePlatform.iconName)
                .foregroundStyle(sourceAccentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(sourcePlatform.displayName) Import")
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
            Text("Preparing workout preview...")
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
                .disabled(isEnhancing || enhancementInput.isEmpty)
            }

            let parsedExerciseCount = workoutCards.filter { !$0.trimmedName.isEmpty }.count
            if parsedExerciseCount > 0 {
                HStack(spacing: 10) {
                    Text("Found \(parsedExerciseCount) exercise\(parsedExerciseCount == 1 ? "" : "s")")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("\(Int((parsingConfidence * 100).rounded()))% confidence")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                if let parsedRestBetweenSets, !parsedRestBetweenSets.isEmpty {
                    Text("Rest between sets: \(parsedRestBetweenSets)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }
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

    // MARK: - Match Resolution

    private var unresolvedMatchesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resolve Exercise Matches")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            ForEach(unresolvedMatches.indices, id: \.self) { index in
                let resolution = unresolvedMatches[index]
                VStack(alignment: .leading, spacing: 8) {
                    Text("“\(resolution.rawName)”")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)

                    Picker(
                        "Match",
                        selection: Binding(
                            get: { unresolvedMatches[index].selectedOptionID },
                            set: { newValue in
                                unresolvedMatches[index].selectedOptionID = newValue
                                applyResolution(unresolvedMatches[index])
                            }
                        )
                    ) {
                        ForEach(resolution.options) { option in
                            Text(option.displayName).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(10)
                .kinexCard(cornerRadius: 10, fill: AppTheme.cardBackgroundElevated)
            }
        }
        .padding(14)
        .kinexCard(cornerRadius: 16)
    }

    // MARK: - Unparsed

    private var unparsedLinesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Unparsed Lines")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            ForEach(unparsedLines) { line in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.text)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(2)

                        if let reason = line.reason, !reason.isEmpty {
                            Text(reason)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.tertiaryText)
                        }
                    }

                    Spacer(minLength: 8)

                    Button("Add") {
                        addUnparsedLineToCards(line)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .buttonStyle(.plain)
                }
                .padding(10)
                .kinexCard(cornerRadius: 10, fill: AppTheme.cardBackgroundElevated)
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

                Text("Source: \(sourcePlatform.displayName) Share")
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
                await parseExtractedText(processed.extractedText, sourceURL: processed.postURL)
                isProcessing = false
            } catch {
                self.error = error
                showingError = true
                await parseExtractedText(importItem.captionText, sourceURL: importItem.postURL)
                isProcessing = false
            }
        } else {
            await parseExtractedText(importItem.extractedText ?? importItem.captionText, sourceURL: importItem.postURL)
        }
    }

    private func parseExtractedText(_ text: String?, sourceURL: String?) async {
        guard !hasUserEditedContent else { return }

        guard let text = text, !text.isEmpty else {
            title = defaultTitle
            description = ""
            workoutCards = []
            rounds = nil
            enhancementSourceText = ""
            unresolvedMatches = []
            unparsedLines = []
            parsedRestBetweenSets = nil
            parsingConfidence = 0
            return
        }

        enhancementSourceText = text
        isProcessing = true

        let parsedWorkout = await parsingService.parseImportText(text, sourceURL: sourceURL)
        if hasUserEditedContent {
            isProcessing = false
            return
        }

        applyParsedWorkout(parsedWorkout, rawText: text)
        isProcessing = false
    }

    private var defaultTitle: String {
        switch sourcePlatform {
        case .tiktok:
            return "TikTok Workout"
        case .instagram:
            return "Instagram Workout"
        case .unknown:
            return "Imported Workout"
        }
    }

    private func applyParsedWorkout(_ parsedWorkout: CaptionParsedWorkout, rawText: String) {
        isApplyingParserOutput = true
        defer { isApplyingParserOutput = false }

        var nextCards: [EditableWorkoutCard] = []
        var nextResolutions: [PendingMatchResolution] = []
        let defaultRest = secondsText(from: parsedWorkout.restBetweenSets)

        for exercise in parsedWorkout.exercises.sorted(by: { $0.position < $1.position }) {
            let card = EditableWorkoutCard(
                name: exercise.exerciseName,
                sets: exercise.sets.map(String.init) ?? "",
                reps: repsText(for: exercise),
                weight: "",
                restSeconds: defaultRest
            )
            nextCards.append(card)

            switch exercise.match {
            case .ambiguous(let options):
                let resolvedOptions = deduplicatedOptions(from: options, fallbackName: exercise.exerciseName)
                if !resolvedOptions.isEmpty {
                    nextResolutions.append(
                        PendingMatchResolution(
                            cardID: card.id,
                            rawName: exercise.rawName,
                            options: resolvedOptions
                        )
                    )
                }

            case .unknown(let closestMatches):
                let options = deduplicatedOptions(
                    from: closestMatches.map { CaptionExerciseOption(kinexExerciseID: nil, displayName: $0) },
                    fallbackName: exercise.exerciseName
                )
                if options.count > 1 {
                    nextResolutions.append(
                        PendingMatchResolution(
                            cardID: card.id,
                            rawName: exercise.rawName,
                            options: options
                        )
                    )
                }

            case .exact, .fuzzy:
                break
            }
        }

        title = parsedWorkout.title
        rounds = parsedWorkout.rounds
        parsingConfidence = parsedWorkout.parsingConfidence
        parsedRestBetweenSets = parsedWorkout.restBetweenSets
        unresolvedMatches = nextResolutions
        unparsedLines = parsedWorkout.unparsedLines

        if nextCards.isEmpty {
            description = parsedWorkout.notes ?? rawText
            workoutCards = []
        } else {
            description = parsedWorkout.notes ?? ""
            workoutCards = nextCards
        }

        hasInitializedFromParser = true
    }

    private func repsText(for exercise: CaptionParsedExercise) -> String {
        if let reps = exercise.reps {
            return String(reps)
        }
        if let duration = exercise.duration {
            if duration % 60 == 0, duration >= 60 {
                return "\(duration / 60) min"
            }
            return "\(duration)s"
        }
        return ""
    }

    private func secondsText(from restValue: String?) -> String {
        guard let restValue = restValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !restValue.isEmpty else {
            return ""
        }

        let lowered = restValue.lowercased()
        if lowered.contains("min"),
           let value = Int(lowered.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()),
           value > 0 {
            return String(value * 60)
        }
        if let value = Int(lowered.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()),
           value > 0 {
            return String(value)
        }
        return ""
    }

    private func deduplicatedOptions(from options: [CaptionExerciseOption], fallbackName: String) -> [CaptionExerciseOption] {
        var seen = Set<String>()
        var deduped: [CaptionExerciseOption] = []

        let allOptions = [CaptionExerciseOption(kinexExerciseID: nil, displayName: fallbackName)] + options
        for option in allOptions {
            let key = option.displayName.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            deduped.append(option)
        }

        return deduped
    }

    private func applyResolution(_ resolution: PendingMatchResolution) {
        guard let selected = resolution.selectedOption else { return }
        guard let index = workoutCards.firstIndex(where: { $0.id == resolution.cardID }) else { return }

        workoutCards[index].name = selected.displayName
        hasUserEditedContent = true
    }

    private func addUnparsedLineToCards(_ line: CaptionUnparsedLine) {
        let defaultRest = secondsText(from: parsedRestBetweenSets)
        let newCard = EditableWorkoutCard(
            name: line.text,
            sets: "",
            reps: "",
            weight: "",
            restSeconds: defaultRest
        )
        workoutCards.append(newCard)
        unparsedLines.removeAll { $0.id == line.id }
        hasUserEditedContent = true
    }

    private func markUserEdited() {
        guard hasInitializedFromParser else { return }
        guard !isApplyingParserOutput else { return }
        hasUserEditedContent = true
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
            let aiRounds = response.workout.structure?.rounds.flatMap { $0 > 0 ? $0 : nil }

            if let exercises = response.workout.exercises {
                let aiCards = EditableWorkoutCard.from(enhancedExercises: exercises, rounds: aiRounds)
                if !aiCards.isEmpty {
                    workoutCards = aiCards
                    unresolvedMatches = []
                    unparsedLines = []
                }
            }

            if let desc = response.workout.description?.trimmingCharacters(in: .whitespacesAndNewlines) {
                description = desc
            }

            rounds = aiRounds
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
