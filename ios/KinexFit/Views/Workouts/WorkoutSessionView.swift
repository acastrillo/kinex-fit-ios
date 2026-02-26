import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "WorkoutSession")

// MARK: - Session Models

struct ExerciseCard: Identifiable {
    let id: String
    let exerciseId: String
    let exerciseName: String
    let exerciseNumber: Int
    let setNumber: Int
    let totalSets: Int
    let reps: Int?
    let weight: String?
    let restSeconds: Int?
    let isRun: Bool
}

struct ExerciseMetric {
    var completed: Bool = false
    var isRun: Bool = false
    var targetReps: Int?
    var targetWeight: String?
    var roundCompleted: Int?
    var roundTotal: Int?
    var reps: Int?
    var weight: Double?
    var weightUnit: String = "lbs"
    var distance: Double?
    var distanceUnit: String = "m"
    var timeSeconds: Int?
    var notes: String = ""
}

// MARK: - WorkoutSessionView

struct WorkoutSessionView: View {
    let workout: Workout

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var sessionDuration: Int = 0
    @State private var isPaused = false
    @State private var exerciseMetrics: [String: ExerciseMetric] = [:]
    @State private var workoutNotes = ""
    @State private var isSaving = false
    @State private var saveSuccess = false
    @State private var showEndDialog = false
    @State private var showCompletionSheet = false
    @State private var selectedCardId: String?
    @State private var showMetricSheet = false
    @State private var saveError: String?
    @State private var showSaveError = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var presentation: WorkoutContentPresentation {
        WorkoutContentPresentation.from(
            content: workout.content,
            source: workout.source,
            durationMinutes: workout.durationMinutes,
            fallbackExerciseCount: workout.exerciseCount
        )
    }

    private var workoutCards: [ExerciseCard] {
        let exercises = presentation.exercises
        let rounds = presentation.rounds ?? 1
        var cards: [ExerciseCard] = []

        for exercise in exercises {
            let sets = exercise.sets ?? rounds
            let isRun = isRunExercise(exercise.name)
            for setNum in 1...max(sets, 1) {
                let cardId = "\(exercise.id)-set\(setNum)"
                cards.append(ExerciseCard(
                    id: cardId,
                    exerciseId: exercise.id,
                    exerciseName: exercise.name,
                    exerciseNumber: exercise.index,
                    setNumber: setNum,
                    totalSets: sets,
                    reps: exercise.reps,
                    weight: exercise.weight,
                    restSeconds: exercise.restSeconds ?? presentation.restSeconds,
                    isRun: isRun
                ))
            }
        }
        return cards
    }

    private var completedCount: Int {
        exerciseMetrics.values.filter(\.completed).count
    }

    private var progress: Double {
        guard !workoutCards.isEmpty else { return 0 }
        return Double(completedCount) / Double(workoutCards.count)
    }

    private var selectedCard: ExerciseCard? {
        guard let id = selectedCardId else { return nil }
        return workoutCards.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            stickyHeader
            sessionContent
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { initializeMetrics() }
        .onReceive(timer) { _ in
            if !isPaused { sessionDuration += 1 }
        }
        .alert("End Workout?", isPresented: $showEndDialog) {
            Button("Continue Training", role: .cancel) { }
            Button("Discard", role: .destructive) { dismiss() }
            Button("Save & End") { showCompletionSheet = true }
        } message: {
            Text("Would you like to save your progress or discard this session?")
        }
        .sheet(isPresented: $showMetricSheet) {
            if let card = selectedCard {
                metricEditorSheet(for: card)
            }
        }
        .sheet(isPresented: $showCompletionSheet) {
            completionSheet
        }
        .alert("Save Failed", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveError ?? "Failed to save workout.")
        }
    }

    // MARK: - Sticky Header

    private var stickyHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    showEndDialog = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                        Text("End")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.secondaryText)
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 12) {
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 13))
                        Text(formatDuration(sessionDuration))
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(.white)

                    Button {
                        isPaused.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text(isPaused ? "Resume" : "Pause")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(isPaused ? AppTheme.accent : AppTheme.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .kinexCard(cornerRadius: 8, fill: AppTheme.cardBackgroundElevated)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("\(completedCount)/\(workoutCards.count) moves completed")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
                if isPaused {
                    Text("Paused")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.cardBackgroundElevated)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.accent)
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.cardBackground.opacity(0.95))
        .overlay(alignment: .bottom) {
            AppTheme.separator.frame(height: 1)
        }
    }

    // MARK: - Session Content

    private var sessionContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(presentation.subtitle)
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                // Exercise Cards
                ForEach(workoutCards) { card in
                    exerciseCardView(card)
                }

                // Finish Button
                Button {
                    showCompletionSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Finish & Save Workout")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.accent, Color(red: 1.0, green: 0.50, blue: 0.22)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: AppTheme.accent.opacity(0.35), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Exercise Card

    private func exerciseCardView(_ card: ExerciseCard) -> some View {
        let metric = exerciseMetrics[card.id]
        let isCompleted = metric?.completed ?? false

        return Button {
            selectedCardId = card.id
            showMetricSheet = true
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Left content
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("\(card.exerciseNumber)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 28, height: 28)
                            .background(AppTheme.accent.opacity(0.15))
                            .clipShape(Circle())

                        Text(card.exerciseName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: 6) {
                        Text("Set \(card.setNumber) of \(card.totalSets)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.cardBackgroundElevated)
                            .clipShape(Capsule())

                        if card.isRun {
                            Text("Run")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.12))
                                .clipShape(Capsule())
                        } else if let reps = card.reps {
                            Text("Target: \(reps) reps\(card.weight.map { " @ \($0)" } ?? "")")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.secondaryText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppTheme.cardBackgroundElevated)
                                .clipShape(Capsule())
                        }
                    }

                    // Logged metrics summary
                    metricsSummaryText(for: card, metric: metric)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right actions
                VStack(spacing: 8) {
                    Button {
                        toggleComplete(card.id)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14))
                            Text(isCompleted ? "Done" : "Complete")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(isCompleted ? Color.green : AppTheme.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isCompleted ? Color.green.opacity(0.12) : AppTheme.cardBackgroundElevated)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule().stroke(isCompleted ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .kinexCard(
                cornerRadius: 14,
                fill: isCompleted ? Color.green.opacity(0.04) : AppTheme.cardBackground
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isCompleted ? Color.green.opacity(0.3) : AppTheme.cardBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func metricsSummaryText(for card: ExerciseCard, metric: ExerciseMetric?) -> some View {
        if let metric {
            if metric.isRun {
                if let dist = metric.distance, dist > 0 {
                    Text("\(String(format: "%.1f", dist)) \(metric.distanceUnit)\(metric.timeSeconds.map { " · \(formatDuration($0))" } ?? "")")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondaryText)
                } else {
                    Text("Tap to log distance & time")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            } else {
                let hasMetrics = (metric.reps ?? 0) > 0 || (metric.weight ?? 0) > 0
                if hasMetrics {
                    let repsText = metric.reps.map { "\($0) reps" } ?? ""
                    let weightText = metric.weight.map { " @ \(String(format: "%.1f", $0)) \(metric.weightUnit)" } ?? ""
                    Text("\(repsText)\(weightText)")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondaryText)
                } else {
                    Text("Tap to log reps & weight")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }
        } else {
            Text("Tap to log metrics")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.tertiaryText)
        }
    }

    // MARK: - Metric Editor Sheet

    private func metricEditorSheet(for card: ExerciseCard) -> some View {
        let binding = Binding<ExerciseMetric>(
            get: { exerciseMetrics[card.id] ?? ExerciseMetric(isRun: card.isRun) },
            set: { exerciseMetrics[card.id] = $0 }
        )

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Exercise info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.exerciseName)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Set \(card.setNumber) of \(card.totalSets)")
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    if !binding.wrappedValue.isRun {
                        strengthMetricFields(binding: binding)
                    } else {
                        runMetricFields(binding: binding)
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                        TextField("Optional notes...", text: binding.notes, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .kinexCard(cornerRadius: 10, fill: AppTheme.cardBackgroundElevated)
                    }

                    // Mark complete toggle
                    Button {
                        binding.wrappedValue.completed.toggle()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: binding.wrappedValue.completed ? "checkmark.circle.fill" : "circle")
                            Text(binding.wrappedValue.completed ? "Completed" : "Mark Complete")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(binding.wrappedValue.completed ? Color.green : AppTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(binding.wrappedValue.completed ? Color.green.opacity(0.12) : AppTheme.cardBackgroundElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(binding.wrappedValue.completed ? Color.green.opacity(0.4) : AppTheme.cardBorder, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Log Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showMetricSheet = false }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func strengthMetricFields(binding: Binding<ExerciseMetric>) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                numericField(title: "Reps", value: Binding(
                    get: { binding.wrappedValue.reps.map(Double.init) },
                    set: { binding.wrappedValue.reps = $0.map(Int.init) }
                ))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Weight")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                    HStack(spacing: 8) {
                        TextField("0", value: binding.weight, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .kinexCard(cornerRadius: 10, fill: AppTheme.cardBackgroundElevated)

                        Picker("", selection: binding.weightUnit) {
                            Text("lbs").tag("lbs")
                            Text("kg").tag("kg")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 90)
                    }
                }
            }
        }
    }

    private func runMetricFields(binding: Binding<ExerciseMetric>) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Distance")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                    TextField("0", value: binding.distance, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .kinexCard(cornerRadius: 10, fill: AppTheme.cardBackgroundElevated)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Unit")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                    Picker("", selection: binding.distanceUnit) {
                        Text("m").tag("m")
                        Text("km").tag("km")
                        Text("mi").tag("mi")
                    }
                    .pickerStyle(.segmented)
                }
            }

            HStack(spacing: 12) {
                numericField(title: "Time (min)", value: Binding(
                    get: {
                        let total = binding.wrappedValue.timeSeconds ?? 0
                        return Double(total / 60)
                    },
                    set: {
                        let minutes = Int($0 ?? 0)
                        let existingSecs = (binding.wrappedValue.timeSeconds ?? 0) % 60
                        binding.wrappedValue.timeSeconds = minutes * 60 + existingSecs
                    }
                ))
                numericField(title: "Time (sec)", value: Binding(
                    get: {
                        let total = binding.wrappedValue.timeSeconds ?? 0
                        return Double(total % 60)
                    },
                    set: {
                        let seconds = min(59, Int($0 ?? 0))
                        let existingMins = (binding.wrappedValue.timeSeconds ?? 0) / 60
                        binding.wrappedValue.timeSeconds = existingMins * 60 + seconds
                    }
                ))
            }
        }
    }

    private func numericField(title: String, value: Binding<Double?>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .textFieldStyle(.plain)
                .padding(12)
                .kinexCard(cornerRadius: 10, fill: AppTheme.cardBackgroundElevated)
        }
    }

    // MARK: - Completion Sheet

    private var completionSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if saveSuccess {
                        successContent
                    } else {
                        summaryContent
                    }
                }
                .padding(16)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(saveSuccess ? "" : "Finish Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !saveSuccess {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { showCompletionSheet = false }
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSaving || saveSuccess)
    }

    private var summaryContent: some View {
        VStack(spacing: 16) {
            // Stats
            VStack(spacing: 10) {
                summaryRow(label: "Workout", value: workout.title)
                summaryRow(label: "Duration", value: formatDuration(sessionDuration))
                summaryRow(label: "Completed", value: "\(completedCount) of \(workoutCards.count) moves")
            }
            .padding(14)
            .kinexCard(cornerRadius: 14)

            // Notes
            VStack(alignment: .leading, spacing: 6) {
                Text("Session Notes")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                TextField("How did it go?", text: $workoutNotes, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .kinexCard(cornerRadius: 10, fill: AppTheme.cardBackgroundElevated)
            }

            // Save button
            Button {
                Task { await saveWorkout() }
            } label: {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(isSaving ? "Saving..." : "Save Workout")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [AppTheme.accent, Color(red: 1.0, green: 0.50, blue: 0.22)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
        }
    }

    private var successContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
                .padding(.top, 20)

            Text("Great job!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Workout saved in \(formatDuration(sessionDuration)).")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.secondaryText)

            Text("Great effort. Keep stacking sessions.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.tertiaryText)
                .padding(.top, 4)
        }
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    // MARK: - Actions

    private func initializeMetrics() {
        for card in workoutCards {
            exerciseMetrics[card.id] = ExerciseMetric(
                isRun: card.isRun,
                targetReps: card.reps,
                targetWeight: card.weight,
                roundCompleted: card.setNumber,
                roundTotal: card.totalSets
            )
        }
    }

    private func toggleComplete(_ cardId: String) {
        guard var metric = exerciseMetrics[cardId] else { return }
        metric.completed.toggle()
        exerciseMetrics[cardId] = metric
    }

    private func saveWorkout() async {
        isSaving = true
        defer { if !saveSuccess { isSaving = false } }

        let completedAt = ISO8601DateFormatter().string(from: Date())
        let completedDate = String(completedAt.prefix(10))
        let durationSeconds = sessionDuration
        let durationMinutes = sessionDuration / 60
        let notes = workoutNotes.trimmingCharacters(in: .whitespacesAndNewlines)

        let metricsPayload: [[String: Any]] = workoutCards.compactMap { card in
            guard let metric = exerciseMetrics[card.id] else { return nil }
            var dict: [String: Any] = [
                "cardId": card.id,
                "exerciseId": card.exerciseId,
                "exerciseName": card.exerciseName,
                "completed": metric.completed,
                "isRun": metric.isRun,
            ]
            if let reps = metric.targetReps { dict["targetReps"] = reps }
            if let weight = metric.targetWeight { dict["targetWeight"] = weight }
            if let rc = metric.roundCompleted { dict["roundCompleted"] = rc }
            if let rt = metric.roundTotal { dict["roundTotal"] = rt }
            if let reps = metric.reps { dict["reps"] = reps }
            if let weight = metric.weight { dict["weight"] = weight }
            dict["weightUnit"] = metric.weightUnit
            if let dist = metric.distance { dict["distance"] = dist }
            dict["distanceUnit"] = metric.distanceUnit
            if let ts = metric.timeSeconds { dict["timeSeconds"] = ts }
            if !metric.notes.isEmpty { dict["notes"] = metric.notes }
            return dict
        }

        // Build completion payload
        var completionBody: [String: Any] = [
            "workoutId": workout.id,
            "completedAt": completedAt,
            "completedDate": completedDate,
            "durationSeconds": durationSeconds,
            "durationMinutes": durationMinutes,
            "exerciseMetrics": metricsPayload,
        ]
        if !notes.isEmpty { completionBody["notes"] = notes }

        do {
            let completionData = try JSONSerialization.data(withJSONObject: completionBody)
            let completionRequest = APIRequest(
                path: "/api/workouts/completions",
                method: .post,
                headers: ["Content-Type": "application/json"],
                body: completionData
            )
            _ = try await appState.environment.apiClient.send(completionRequest)

            // Mark workout as complete
            let completeBody: [String: Any] = [
                "completedAt": completedAt,
                "completedDate": completedDate,
                "durationSeconds": durationSeconds,
            ]
            let completeData = try JSONSerialization.data(withJSONObject: completeBody)
            let completeRequest = APIRequest(
                path: "/api/workouts/\(workout.id)/complete",
                method: .post,
                headers: ["Content-Type": "application/json"],
                body: completeData
            )
            _ = try await appState.environment.apiClient.send(completeRequest)

            saveSuccess = true
            isSaving = false

            // Auto-dismiss after delay
            try? await Task.sleep(for: .seconds(2))
            showCompletionSheet = false
            dismiss()
        } catch {
            logger.error("Failed to save workout: \(error.localizedDescription)")
            saveError = error.localizedDescription
            showSaveError = true
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private func isRunExercise(_ name: String) -> Bool {
        let pattern = #"\b(run|running|jog|jogging|sprint|mile|miles|km|kilometer|5k|10k)\b"#
        return name.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

#Preview("Workout Session") {
    NavigationStack {
        WorkoutSessionView(
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
            )
        )
    }
    .appDarkTheme()
}
