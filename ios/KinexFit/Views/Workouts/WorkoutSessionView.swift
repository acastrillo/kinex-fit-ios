import SwiftUI
import OSLog
import AudioToolbox
import UIKit

private let logger = Logger(subsystem: "com.kinex.fit", category: "WorkoutSession")

private enum WorkoutIntervalPhase {
    case work
    case rest
    case completed

    var label: String {
        switch self {
        case .work: return "Work"
        case .rest: return "Rest"
        case .completed: return "Complete"
        }
    }
}

// MARK: - Session Models

struct ExerciseCard: Identifiable {
    let id: String
    let exerciseId: String
    let exerciseName: String
    let exerciseNumber: Int
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

private enum WorkoutPRCategory: String {
    case weightReps = "WEIGHT_REPS"
    case longestRunDistance = "LONGEST_RUN_DISTANCE"
    case fastestRun = "FASTEST_RUN"
}

private struct WorkoutPRHighlight: Identifiable {
    let exerciseName: String
    let category: WorkoutPRCategory
    let message: String
    let value: String

    var id: String {
        "\(exerciseName)-\(category.rawValue)-\(message)-\(value)"
    }

    var payload: [String: String] {
        [
            "exerciseName": exerciseName,
            "category": category.rawValue,
            "message": message,
            "value": value,
        ]
    }
}

private struct SessionMetricSnapshot {
    let exerciseName: String
    let completed: Bool
    let isRun: Bool
    let reps: Int?
    let weight: Double?
    let weightUnit: String?
    let distance: Double?
    let distanceUnit: String?
    let timeSeconds: Int?
}

private struct WorkoutCompletionHistoryResponse: Decodable {
    let completions: [WorkoutCompletionHistoryItem]?
}

private struct WorkoutCompletionHistoryItem: Decodable {
    let exerciseMetrics: [HistoricalExerciseMetric]?
}

private struct HistoricalExerciseMetric: Decodable {
    let exerciseName: String
    let completed: Bool
    let isRun: Bool
    let reps: Int?
    let weight: Double?
    let weightUnit: String?
    let distance: Double?
    let distanceUnit: String?
    let timeSeconds: Int?

    private enum CodingKeys: String, CodingKey {
        case exerciseName
        case completed
        case isRun
        case reps
        case weight
        case weightUnit
        case distance
        case distanceUnit
        case timeSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exerciseName = (try? container.decode(String.self, forKey: .exerciseName)) ?? ""
        completed = Self.decodeBool(from: container, forKey: .completed) ?? false
        isRun = Self.decodeBool(from: container, forKey: .isRun) ?? false
        reps = Self.decodeInt(from: container, forKey: .reps)
        weight = Self.decodeDouble(from: container, forKey: .weight)
        weightUnit = try? container.decodeIfPresent(String.self, forKey: .weightUnit)
        distance = Self.decodeDouble(from: container, forKey: .distance)
        distanceUnit = try? container.decodeIfPresent(String.self, forKey: .distanceUnit)
        timeSeconds = Self.decodeInt(from: container, forKey: .timeSeconds)
    }

    private static func decodeBool(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Bool? {
        if let value = try? container.decodeIfPresent(Bool.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return value != 0
        }
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true", "yes", "y":
                return true
            case "0", "false", "no", "n":
                return false
            default:
                return nil
            }
        }
        return nil
    }

    private static func decodeInt(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Int? {
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            return Int(value.rounded())
        }
        if let value = try? container.decodeIfPresent(String.self, forKey: key),
           let parsed = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return parsed
        }
        return nil
    }

    private static func decodeDouble(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Double? {
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? container.decodeIfPresent(String.self, forKey: key),
           let parsed = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return parsed
        }
        return nil
    }
}

// MARK: - WorkoutSessionView

struct WorkoutSessionView: View {
    let workout: Workout
    private let recommendedTimerConfiguration: WorkoutSessionTimerConfiguration

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
    @State private var showReadyToCompleteDialog = false
    @State private var selectedCardId: String?
    @State private var showMetricSheet = false
    @State private var saveError: String?
    @State private var showSaveError = false
    @State private var detectedPRs: [WorkoutPRHighlight] = []
    @State private var timerConfiguration: WorkoutSessionTimerConfiguration
    @State private var intervalPhase: WorkoutIntervalPhase
    @State private var intervalRound: Int
    @State private var intervalPhaseRemainingSeconds: Int
    @State private var intervalElapsedSeconds: Int
    @State private var showTimerSelection = false
    @State private var hapticEnabled = true
    @State private var didPresentAutoCompletion = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(
        workout: Workout,
        initialTimerConfiguration: WorkoutSessionTimerConfiguration? = nil
    ) {
        self.workout = workout
        let inferredPresentation = WorkoutContentPresentation.from(
            content: workout.content,
            source: workout.source,
            durationMinutes: workout.durationMinutes,
            fallbackExerciseCount: workout.exerciseCount
        )
        let recommended = WorkoutSessionTimerConfiguration.recommended(from: inferredPresentation)
        let resolvedConfiguration = (initialTimerConfiguration ?? recommended).normalized()
        self.recommendedTimerConfiguration = recommended
        _timerConfiguration = State(initialValue: resolvedConfiguration)
        _intervalPhase = State(initialValue: resolvedConfiguration.usesCountdown ? .work : .completed)
        _intervalRound = State(initialValue: 1)
        _intervalPhaseRemainingSeconds = State(
            initialValue: resolvedConfiguration.usesCountdown ? resolvedConfiguration.clampedWorkSeconds : 0
        )
        _intervalElapsedSeconds = State(initialValue: 0)
    }

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
            let sets = max(exercise.sets ?? rounds, 1)
            let isRun = isRunExercise(exercise.name)
            let cardId = exercise.id
            cards.append(ExerciseCard(
                id: cardId,
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                exerciseNumber: exercise.index,
                totalSets: sets,
                reps: exercise.reps,
                weight: exercise.weight,
                restSeconds: exercise.restSeconds ?? presentation.restSeconds,
                isRun: isRun
            ))
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

    private func currentSet(for card: ExerciseCard) -> Int {
        let stored = exerciseMetrics[card.id]?.roundCompleted ?? 1
        return min(max(stored, 1), card.totalSets)
    }

    private var displayedTimerSeconds: Int {
        if timerConfiguration.usesCountdown {
            return max(intervalPhaseRemainingSeconds, 0)
        }
        return sessionDuration
    }

    private var timerStatusText: String {
        if timerConfiguration.type == .standard {
            return "Standard count-up timer"
        }
        if intervalPhase == .completed {
            return "\(timerConfiguration.type.displayName) timer complete"
        }
        return "\(intervalPhase.label) • Round \(min(intervalRound, timerConfiguration.clampedRounds))/\(timerConfiguration.clampedRounds)"
    }

    private var countdownProgress: Double {
        guard timerConfiguration.usesCountdown else { return 0 }
        let total = Double(max(timerConfiguration.totalDurationSeconds, 1))
        let progress = Double(intervalElapsedSeconds) / total
        return min(max(progress, 0), 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            stickyHeader
            sessionContent
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            initializeMetrics()
            if timerConfiguration.usesCountdown {
                resetIntervalState(for: timerConfiguration)
            }
            Task {
                await loadNotificationPreferences()
            }
        }
        .onReceive(timer) { _ in
            handleSessionTick()
        }
        .alert("End Workout?", isPresented: $showEndDialog) {
            Button("Continue Training", role: .cancel) { }
            Button("Discard", role: .destructive) { dismiss() }
            Button("Save & End") { showCompletionSheet = true }
        } message: {
            Text("Would you like to save your progress or discard this session?")
        }
        .alert("All Workout Cards Completed", isPresented: $showReadyToCompleteDialog) {
            Button("Not Yet", role: .cancel) { }
            Button("Yes, Complete") { showCompletionSheet = true }
        } message: {
            Text("Timer paused. Are you ready to complete this workout?")
        }
        .sheet(isPresented: $showMetricSheet) {
            if let card = selectedCard {
                metricEditorSheet(for: card)
            }
        }
        .sheet(isPresented: $showCompletionSheet) {
            completionSheet
        }
        .sheet(isPresented: $showTimerSelection) {
            WorkoutTimerSelectionSheet(
                current: timerConfiguration,
                recommended: recommendedTimerConfiguration
            ) { updatedConfiguration in
                applyTimerConfiguration(updatedConfiguration)
            }
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

                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: timerConfiguration.type.iconName)
                            .font(.system(size: 13))
                        Text(formatDuration(displayedTimerSeconds))
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .kinexCard(cornerRadius: 8, fill: AppTheme.cardBackgroundElevated)

                    Button {
                        showTimerSelection = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .kinexCard(cornerRadius: 8, fill: AppTheme.cardBackgroundElevated)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Change Timer")
                    .accessibilityValue(timerConfiguration.accessibilityLabel)

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
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(completedCount)/\(workoutCards.count) moves completed")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(timerStatusText)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                Spacer()
                if timerConfiguration.usesCountdown && intervalPhase == .completed {
                    Text("Complete")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                } else if isPaused {
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

                timerStatusCard

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

    private var timerStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: timerConfiguration.type.iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                    Text(timerConfiguration.selectionLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button {
                    showTimerSelection = true
                } label: {
                    Text("Adjust")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent.opacity(0.14))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(formatDuration(displayedTimerSeconds))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                if timerConfiguration.usesCountdown {
                    Text("remaining")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                } else {
                    Text("elapsed")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            if timerConfiguration.usesCountdown {
                HStack(spacing: 8) {
                    Text(intervalPhase.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(intervalPhase == .rest ? .orange : AppTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (intervalPhase == .rest ? Color.orange : AppTheme.accent).opacity(0.16)
                        )
                        .clipShape(Capsule())

                    Text("Round \(min(intervalRound, timerConfiguration.clampedRounds))/\(timerConfiguration.clampedRounds)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            if timerConfiguration.usesCountdown {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppTheme.cardBackgroundElevated)
                            .frame(height: 6)
                        Capsule()
                            .fill(AppTheme.accent)
                            .frame(
                                width: geometry.size.width * countdownProgress,
                                height: 6
                            )
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(12)
        .kinexCard(cornerRadius: 14, fill: AppTheme.cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        }
    }

    // MARK: - Exercise Card

    private func exerciseCardView(_ card: ExerciseCard) -> some View {
        let metric = exerciseMetrics[card.id]
        let isCompleted = metric?.completed ?? false
        let activeSet = currentSet(for: card)

        return HStack(alignment: .top, spacing: 12) {
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
                    Text("Set \(activeSet) of \(card.totalSets)")
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

                metricsSummaryText(metric: metric, isCompleted: isCompleted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "hand.tap.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(isCompleted ? "Done" : "Advance")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(isCompleted ? Color.green : AppTheme.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isCompleted ? Color.green.opacity(0.14) : AppTheme.cardBackgroundElevated)
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(isCompleted ? Color.green.opacity(0.45) : Color.clear, lineWidth: 1)
                }

                if !isCompleted {
                    Text("Tap card")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }
        }
        .padding(14)
        .kinexCard(
            cornerRadius: 14,
            fill: isCompleted ? Color.green.opacity(0.08) : AppTheme.cardBackground
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isCompleted ? Color.green.opacity(0.35) : AppTheme.cardBorder, lineWidth: 1)
        }
        .shadow(color: isCompleted ? Color.green.opacity(0.22) : Color.clear, radius: 12, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            advanceCardProgress(card.id)
        }
        .onLongPressGesture(minimumDuration: 0.45) {
            selectedCardId = card.id
            showMetricSheet = true
        }
    }

    @ViewBuilder
    private func metricsSummaryText(
        metric: ExerciseMetric?,
        isCompleted: Bool
    ) -> some View {
        if isCompleted {
            Text("Completed")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.green.opacity(0.92))
        } else if let metric {
            if metric.isRun {
                if let dist = metric.distance, dist > 0 {
                    Text("\(String(format: "%.1f", dist)) \(metric.distanceUnit)\(metric.timeSeconds.map { " · \(formatDuration($0))" } ?? "")")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondaryText)
                } else {
                    Text("Long press to log distance & time")
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
                    Text("Long press to log reps & weight")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }
        } else {
            Text("Tap to advance set")
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
                        Text("Set \(currentSet(for: card)) of \(card.totalSets)")
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

                    Text("Long press any workout card to log metrics without advancing sets.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.tertiaryText)
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
                summaryRow(label: "Timer", value: timerConfiguration.selectionLabel)
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

            if detectedPRs.isEmpty {
                Text("Great effort. Keep stacking sessions.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("\(detectedPRs.count) new PR\(detectedPRs.count == 1 ? "" : "s")!")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(Color(red: 0.98, green: 0.84, blue: 0.40))

                    VStack(spacing: 8) {
                        ForEach(detectedPRs) { pr in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pr.message)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color(red: 1.0, green: 0.90, blue: 0.72))
                                Text(pr.value)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(red: 1.0, green: 0.93, blue: 0.82))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.orange.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
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

    private func handleSessionTick() {
        guard !isPaused else { return }
        sessionDuration += 1

        guard timerConfiguration.usesCountdown else { return }
        guard intervalPhase != .completed else { return }

        if intervalPhaseRemainingSeconds > 0 {
            intervalPhaseRemainingSeconds -= 1
            intervalElapsedSeconds += 1
        }

        if intervalPhaseRemainingSeconds == 0 {
            advanceIntervalPhase()
        }
    }

    private func resetIntervalState(for configuration: WorkoutSessionTimerConfiguration) {
        guard configuration.usesCountdown else {
            intervalPhase = .completed
            intervalRound = 1
            intervalPhaseRemainingSeconds = 0
            intervalElapsedSeconds = 0
            return
        }

        intervalPhase = .work
        intervalRound = 1
        intervalPhaseRemainingSeconds = configuration.clampedWorkSeconds
        intervalElapsedSeconds = 0
    }

    private func advanceIntervalPhase() {
        switch intervalPhase {
        case .work:
            let hasAnotherRound = intervalRound < timerConfiguration.clampedRounds
            guard hasAnotherRound else {
                finishIntervalTimer()
                return
            }

            if timerConfiguration.clampedRestSeconds > 0 {
                intervalPhase = .rest
                intervalPhaseRemainingSeconds = timerConfiguration.clampedRestSeconds
                triggerTransitionAlert(for: .rest)
            } else {
                intervalRound += 1
                intervalPhase = .work
                intervalPhaseRemainingSeconds = timerConfiguration.clampedWorkSeconds
                triggerTransitionAlert(for: .work)
            }
        case .rest:
            let hasAnotherRound = intervalRound < timerConfiguration.clampedRounds
            guard hasAnotherRound else {
                finishIntervalTimer()
                return
            }
            intervalRound += 1
            intervalPhase = .work
            intervalPhaseRemainingSeconds = timerConfiguration.clampedWorkSeconds
            triggerTransitionAlert(for: .work)
        case .completed:
            break
        }
    }

    private func finishIntervalTimer() {
        guard intervalPhase != .completed else { return }
        intervalPhase = .completed
        intervalPhaseRemainingSeconds = 0

        AudioServicesPlaySystemSound(SystemSoundID(1005))
        
        if hapticEnabled {
            let feedback = UINotificationFeedbackGenerator()
            feedback.prepare()
            feedback.notificationOccurred(.success)
        }

        guard !didPresentAutoCompletion else { return }
        didPresentAutoCompletion = true
        isPaused = true
        showCompletionSheet = true
    }

    private func triggerTransitionAlert(for phase: WorkoutIntervalPhase) {
        AudioServicesPlaySystemSound(SystemSoundID(1113))
        
        let feedback = UINotificationFeedbackGenerator()
        feedback.prepare()
        
        switch phase {
        case .work:
            if hapticEnabled {
                feedback.notificationOccurred(.success)
            }
        case .rest:
            if hapticEnabled {
                feedback.notificationOccurred(.warning)
            }
        case .completed:
            if hapticEnabled {
                feedback.notificationOccurred(.success)
            }
        }
    }

    private func loadNotificationPreferences() async {
        guard let user = try? await appState.environment.userRepository.getCurrentUser() else { return }
        hapticEnabled = user.enableNotificationHaptics
    }

    private func applyTimerConfiguration(_ configuration: WorkoutSessionTimerConfiguration) {
        let normalized = configuration.normalized()
        timerConfiguration = normalized
        resetIntervalState(for: normalized)
        didPresentAutoCompletion = false
    }

    private func initializeMetrics() {
        for card in workoutCards {
            exerciseMetrics[card.id] = ExerciseMetric(
                isRun: card.isRun,
                targetReps: card.reps,
                targetWeight: card.weight,
                roundCompleted: 1,
                roundTotal: card.totalSets
            )
        }
    }

    private func advanceCardProgress(_ cardId: String) {
        guard let card = workoutCards.first(where: { $0.id == cardId }),
              var metric = exerciseMetrics[cardId] else {
            return
        }
        guard !metric.completed else { return }

        let currentRound = min(max(metric.roundCompleted ?? 1, 1), card.totalSets)
        if currentRound < card.totalSets {
            metric.roundCompleted = currentRound + 1
            if hapticEnabled {
                let feedback = UISelectionFeedbackGenerator()
                feedback.prepare()
                feedback.selectionChanged()
            }
        } else {
            metric.roundCompleted = card.totalSets
            metric.completed = true
            if hapticEnabled {
                let feedback = UINotificationFeedbackGenerator()
                feedback.prepare()
                feedback.notificationOccurred(.success)
            }
        }

        exerciseMetrics[cardId] = metric
        pauseAndPromptIfAllCardsCompleted()
    }

    private func pauseAndPromptIfAllCardsCompleted() {
        guard !showCompletionSheet else { return }
        guard !showReadyToCompleteDialog else { return }
        guard completedCount == workoutCards.count, !workoutCards.isEmpty else { return }
        isPaused = true
        showReadyToCompleteDialog = true
    }

    private func saveWorkout() async {
        isSaving = true
        defer { if !saveSuccess { isSaving = false } }

        let completedAt = ISO8601DateFormatter().string(from: Date())
        let completedDate = String(completedAt.prefix(10))
        let durationSeconds = sessionDuration
        let durationMinutes = sessionDuration / 60
        let notes = workoutNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        var currentMetrics: [SessionMetricSnapshot] = []

        let metricsPayload: [[String: Any]] = workoutCards.compactMap { card in
            guard let metric = exerciseMetrics[card.id] else { return nil }
            currentMetrics.append(
                SessionMetricSnapshot(
                    exerciseName: card.exerciseName,
                    completed: metric.completed,
                    isRun: metric.isRun,
                    reps: metric.reps,
                    weight: metric.weight,
                    weightUnit: metric.weightUnit,
                    distance: metric.distance,
                    distanceUnit: metric.distanceUnit,
                    timeSeconds: metric.timeSeconds
                )
            )
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
        let historicalMetrics = await fetchHistoricalExerciseMetrics(limit: 200)
        let prHighlights = detectSessionPRs(
            currentMetrics: currentMetrics,
            historicalMetrics: historicalMetrics
        )
        detectedPRs = prHighlights

        // Build completion payload
        var completionBody: [String: Any] = [
            "workoutId": workout.id,
            "completedAt": completedAt,
            "completedDate": completedDate,
            "durationSeconds": durationSeconds,
            "durationMinutes": durationMinutes,
            "exerciseMetrics": metricsPayload,
            "prHighlights": prHighlights.map(\.payload),
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

    private func fetchHistoricalExerciseMetrics(limit: Int) async -> [HistoricalExerciseMetric] {
        do {
            let request = APIRequest(
                path: "/api/workouts/completions",
                method: .get,
                queryItems: [URLQueryItem(name: "limit", value: "\(limit)")]
            )
            let response: WorkoutCompletionHistoryResponse = try await appState.environment.apiClient.send(request)
            return (response.completions ?? []).flatMap { $0.exerciseMetrics ?? [] }
        } catch {
            logger.warning("Unable to load completion history for PR detection: \(error.localizedDescription)")
            return []
        }
    }

    private func detectSessionPRs(
        currentMetrics: [SessionMetricSnapshot],
        historicalMetrics: [HistoricalExerciseMetric]
    ) -> [WorkoutPRHighlight] {
        var highlights: [WorkoutPRHighlight] = []

        for metric in currentMetrics where metric.completed {
            let exerciseKey = normalizeExerciseName(metric.exerciseName)
            let exerciseHistory = historicalMetrics.filter {
                normalizeExerciseName($0.exerciseName) == exerciseKey
            }

            if !metric.isRun {
                guard let weight = metric.weight, weight > 0,
                      let reps = metric.reps, reps > 0 else {
                    continue
                }

                let unit = normalizeWeightUnit(metric.weightUnit)
                let candidateOneRM = calculateOneRepMax(
                    weight: normalizeWeight(weight, unit: unit),
                    reps: reps
                )
                let previousBest = exerciseHistory.reduce(0.0) { best, item in
                    guard let itemWeight = item.weight, itemWeight > 0,
                          let itemReps = item.reps, itemReps > 0 else {
                        return best
                    }
                    let itemUnit = normalizeWeightUnit(item.weightUnit)
                    let itemOneRM = calculateOneRepMax(
                        weight: normalizeWeight(itemWeight, unit: itemUnit),
                        reps: itemReps
                    )
                    return max(best, itemOneRM)
                }

                if candidateOneRM > previousBest + 0.5 {
                    highlights.append(
                        WorkoutPRHighlight(
                            exerciseName: metric.exerciseName,
                            category: .weightReps,
                            message: "New strength PR on \(metric.exerciseName)!",
                            value: "\(Int(weight.rounded())) \(unit) x \(reps) (~\(Int(candidateOneRM.rounded())) 1RM)"
                        )
                    )
                }
                continue
            }

            guard let distance = metric.distance, distance > 0 else {
                continue
            }

            let distanceUnit = normalizeDistanceUnit(metric.distanceUnit)
            let candidateMeters = toMeters(distance, unit: distanceUnit)
            let bestMeters = exerciseHistory.reduce(0.0) { best, item in
                guard item.isRun, let itemDistance = item.distance, itemDistance > 0 else {
                    return best
                }
                return max(best, toMeters(itemDistance, unit: normalizeDistanceUnit(item.distanceUnit)))
            }

            if candidateMeters > bestMeters + 0.5 {
                highlights.append(
                    WorkoutPRHighlight(
                        exerciseName: metric.exerciseName,
                        category: .longestRunDistance,
                        message: "Longest distance PR for \(metric.exerciseName)!",
                        value: formatDistanceValue(distance, unit: distanceUnit)
                    )
                )
            }

            if let timeSeconds = metric.timeSeconds, timeSeconds > 0 {
                let similarDistanceHistory = exerciseHistory.filter { item in
                    guard item.isRun,
                          let itemDistance = item.distance,
                          itemDistance > 0,
                          let itemTime = item.timeSeconds,
                          itemTime > 0 else {
                        return false
                    }
                    let itemMeters = toMeters(itemDistance, unit: normalizeDistanceUnit(item.distanceUnit))
                    return abs(itemMeters - candidateMeters) <= 1
                }

                let bestTime = similarDistanceHistory.reduce(Int.max) { best, item in
                    min(best, item.timeSeconds ?? Int.max)
                }

                if bestTime == Int.max || timeSeconds < bestTime {
                    highlights.append(
                        WorkoutPRHighlight(
                            exerciseName: metric.exerciseName,
                            category: .fastestRun,
                            message: "Fastest time PR for \(metric.exerciseName)!",
                            value: "\(formatDuration(timeSeconds)) for \(formatDistanceValue(distance, unit: distanceUnit))"
                        )
                    )
                }
            }
        }

        return highlights
    }

    private func calculateOneRepMax(weight: Double, reps: Int) -> Double {
        guard reps > 1 else { return weight }
        let brzycki = reps > 12 ? weight : weight / (1.0278 - (0.0278 * Double(reps)))
        let epley = weight * (1 + (Double(reps) / 30))
        return ((brzycki + epley) / 2).rounded()
    }

    private func normalizeWeight(_ weight: Double, unit: String) -> Double {
        if unit == "kg" {
            return weight * 2.20462
        }
        return weight
    }

    private func normalizeWeightUnit(_ unit: String?) -> String {
        let normalized = unit?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "lbs"
        if normalized == "kg" || normalized == "kgs" || normalized.hasPrefix("kilo") {
            return "kg"
        }
        return "lbs"
    }

    private func normalizeDistanceUnit(_ unit: String?) -> String {
        let normalized = unit?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "m"
        if normalized == "km" {
            return "km"
        }
        if normalized == "mi" || normalized.hasPrefix("mile") {
            return "mi"
        }
        return "m"
    }

    private func toMeters(_ distance: Double, unit: String) -> Double {
        switch unit {
        case "km":
            return distance * 1000
        case "mi":
            return distance * 1609.34
        default:
            return distance
        }
    }

    private func formatDistanceValue(_ distance: Double, unit: String) -> String {
        let isWholeNumber = abs(distance.rounded() - distance) < 0.0001
        let decimals: Int
        if unit == "m" {
            decimals = isWholeNumber ? 0 : 1
        } else {
            decimals = isWholeNumber ? 0 : 2
        }
        return "\(String(format: "%.\(decimals)f", distance)) \(unit)"
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private func normalizeExerciseName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func isRunExercise(_ name: String) -> Bool {
        let pattern = #"\b(run|running|jog|jogging|sprint|mile|miles|km|kilometer|kilometre|5k|10k)\b"#
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
