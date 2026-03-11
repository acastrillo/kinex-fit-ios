import SwiftUI

/// Promotional card for Workout-of-the-Week generation.
/// Used as the empty state before a weekly workout has been fetched.
struct AIFeatureCard: View {
    let onGenerateTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Workout of the Week")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("Your free AI-generated weekly workout plan")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.top, 8)

                Text("Get Your AI Workout")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Text("AI workout tailored to your training profile.\nFresh every week!")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)

            Button(action: onGenerateTapped) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate This Week's Workout")
                }
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: AppTheme.accent.opacity(0.38), radius: 16, y: 7)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .kinexCard(cornerRadius: 18)
    }
}

/// Shared workout-of-the-week section used on Home and Create tabs.
struct WorkoutOfTheWeekSection: View {
    @EnvironmentObject private var appState: AppState
    @State private var workoutOfTheWeek: WorkoutRepository.WorkoutOfTheWeekCacheEntry?
    @State private var isLoadingWorkoutOfTheWeek = false
    @State private var isOpeningWorkoutOfTheWeek = false
    @State private var workoutOfTheWeekLoadFailed = false
    @State private var showingWorkoutOfTheWeekEditor = false

    private var workoutRepository: WorkoutRepository {
        appState.environment.workoutRepository
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Workout of the Week")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                Button {
                    Task {
                        await loadWorkoutOfTheWeek(forceRefresh: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(8)
                        .background(AppTheme.cardBackgroundElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isLoadingWorkoutOfTheWeek)
            }

            if isLoadingWorkoutOfTheWeek && workoutOfTheWeek == nil {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(AppTheme.accent)

                    Text("Loading this week's featured workout...")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .kinexCard(cornerRadius: 14, fill: AppTheme.cardBackgroundElevated)
            } else if let workoutOfTheWeek {
                workoutOfTheWeekCard(workoutOfTheWeek)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if workoutOfTheWeekLoadFailed {
                        Text("Couldn't load this week's featured workout.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    AIFeatureCard {
                        Task {
                            await loadWorkoutOfTheWeek(forceRefresh: true)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingWorkoutOfTheWeekEditor) {
            if let workoutOfTheWeek {
                WorkoutFormView(
                    mode: .create,
                    initialTitle: workoutOfTheWeek.title,
                    initialRawContent: workoutOfTheWeek.content,
                    initialSource: .imported,
                    onSave: saveWorkoutOfTheWeek
                )
            }
        }
        .onAppear {
            Task {
                await loadWorkoutOfTheWeek()
            }
        }
    }

    private func workoutOfTheWeekCard(_ featuredWorkout: WorkoutRepository.WorkoutOfTheWeekCacheEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("FEATURED")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(AppTheme.accent.opacity(0.88))
                    .clipShape(Capsule())

                if featuredWorkout.isNew {
                    Text("NEW")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(AppTheme.primaryText.opacity(0.15))
                        .clipShape(Capsule())
                }

                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.88))
            }

            Text(featuredWorkout.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(2)

            Text(workoutOfTheWeekSummary(for: featuredWorkout))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.primaryText.opacity(0.84))
                .lineLimit(3)

            HStack(spacing: 10) {
                if let difficulty = difficultyLabel(from: featuredWorkout.difficulty) {
                    Text(difficulty)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(AppTheme.primaryText.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text("Refreshes \(dateLabel(for: featuredWorkout.expiresAt))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText.opacity(0.78))

                Spacer()
            }

            Button {
                Task {
                    await openWorkoutOfTheWeek(featuredWorkout)
                }
            } label: {
                HStack(spacing: 8) {
                    if isOpeningWorkoutOfTheWeek {
                        ProgressView()
                            .tint(AppTheme.accent)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                    }

                    Text(isOpeningWorkoutOfTheWeek ? "Opening..." : "Open Workout")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 10)
                .background(AppTheme.background.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isOpeningWorkoutOfTheWeek)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.accent.opacity(0.36),
                    AppTheme.cardBackgroundElevated
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
        }
    }

    private func dateLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            return date.formatted(.dateTime.month(.defaultDigits).day())
        }
        return date.formatted(.dateTime.month(.defaultDigits).day().year())
    }

    private func loadWorkoutOfTheWeek(forceRefresh: Bool = false) async {
        await MainActor.run {
            isLoadingWorkoutOfTheWeek = true
            workoutOfTheWeekLoadFailed = false
        }

        defer {
            Task { @MainActor in
                isLoadingWorkoutOfTheWeek = false
            }
        }

        do {
            let featuredWorkout = try await workoutRepository.fetchWorkoutOfTheWeek(forceRefresh: forceRefresh)
            await MainActor.run {
                workoutOfTheWeek = featuredWorkout
            }
        } catch {
            await MainActor.run {
                if workoutOfTheWeek?.isExpired == true {
                    workoutOfTheWeek = nil
                }
                workoutOfTheWeekLoadFailed = true
            }
        }
    }

    private func openWorkoutOfTheWeek(_ featuredWorkout: WorkoutRepository.WorkoutOfTheWeekCacheEntry) async {
        guard !isOpeningWorkoutOfTheWeek else { return }

        await MainActor.run {
            isOpeningWorkoutOfTheWeek = true
        }

        defer {
            Task { @MainActor in
                isOpeningWorkoutOfTheWeek = false
            }
        }

        if let workoutID = featuredWorkout.preferredWorkoutID,
           let existingWorkout = try? await workoutRepository.fetch(id: workoutID) {
            await MainActor.run {
                appState.navigateToWorkoutCard(workoutID: existingWorkout.id)
            }
            return
        }

        await MainActor.run {
            showingWorkoutOfTheWeekEditor = true
        }
    }

    private func saveWorkoutOfTheWeek(title: String, content: String?, enhancementSourceText: String?) async throws {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedContent = content?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEnhancementSource = enhancementSourceText?.trimmingCharacters(in: .whitespacesAndNewlines)

        let workout = Workout(
            title: normalizedTitle.isEmpty ? "Workout of the Week" : normalizedTitle,
            content: normalizedContent?.isEmpty == false ? normalizedContent : nil,
            enhancementSourceText: normalizedEnhancementSource?.isEmpty == false
                ? normalizedEnhancementSource
                : normalizedContent,
            source: .imported,
            exerciseCount: estimateExerciseCount(from: normalizedContent),
            difficulty: workoutOfTheWeek?.difficulty
        )

        let savedWorkout = try await workoutRepository.create(workout)
        await workoutRepository.setWorkoutOfTheWeekLocalWorkoutID(savedWorkout.id)

        await MainActor.run {
            workoutOfTheWeek?.localWorkoutID = savedWorkout.id
            showingWorkoutOfTheWeekEditor = false
            appState.navigateToWorkoutCard(workoutID: savedWorkout.id)
        }
    }

    private func workoutOfTheWeekSummary(for featuredWorkout: WorkoutRepository.WorkoutOfTheWeekCacheEntry) -> String {
        let rationale = featuredWorkout.rationale?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let rationale, !rationale.isEmpty {
            return rationale
        }

        let content = featuredWorkout.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.isEmpty {
            return "Tap to review and save this week's featured workout."
        }
        return content
    }

    private func difficultyLabel(from rawDifficulty: String?) -> String? {
        guard let rawDifficulty,
              !rawDifficulty.isEmpty else {
            return nil
        }

        let normalized = rawDifficulty.lowercased()
        switch normalized {
        case "hiit":
            return "HIIT"
        default:
            return String(normalized.prefix(1)).uppercased() + String(normalized.dropFirst())
        }
    }

    private func estimateExerciseCount(from content: String?) -> Int? {
        guard let content else { return nil }
        let lines = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                !line.isEmpty &&
                !line.hasPrefix("-") &&
                !line.hasPrefix("#") &&
                !line.lowercased().contains("warm") &&
                !line.lowercased().contains("cool")
            }

        guard !lines.isEmpty else { return nil }
        return min(lines.count, 30)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        AIFeatureCard {
            // Action handled by parent view
        }
    }
    .padding()
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
