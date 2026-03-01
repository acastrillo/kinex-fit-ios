import SwiftUI

/// Home tab - landing screen with personalized greeting, weekly highlight, and progress stats
struct HomeTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var stats: HomeStats = .empty
    @State private var recentWorkouts: [Workout] = []
    @State private var user: User?
    @State private var workoutOfTheWeek: WorkoutRepository.WorkoutOfTheWeekCacheEntry?
    @State private var isLoadingWorkoutOfTheWeek = false
    @State private var isOpeningWorkoutOfTheWeek = false
    @State private var workoutOfTheWeekLoadFailed = false
    @State private var showingWorkoutOfTheWeekEditor = false
    
    private var workoutRepository: WorkoutRepository {
        appState.environment.workoutRepository
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                greetingSection
                workoutOfTheWeekSection

                statsGrid

                quickActionsSection

                recentWorkoutsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 30)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .refreshable {
            await loadHomeData(forceRefreshWorkoutOfTheWeek: true)
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
        .task {
            user = try? await appState.environment.userRepository.getCurrentUser()
            await loadHomeData()
        }
    }
    
    // MARK: - Greeting Section

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome back, \(displayName)!")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Text("Ready to crush your fitness goals today?")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var displayName: String {
        if let firstName = user?.firstName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !firstName.isEmpty {
            return firstName
        }
        return "Athlete"
    }

    // MARK: - Weekly Workout

    private var workoutOfTheWeekSection: some View {
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
                    Text(workoutOfTheWeekLoadFailed
                         ? "Couldn't load this week's featured workout."
                         : "No featured workout is available right now.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)

                    Button("Try Again") {
                        Task {
                            await loadWorkoutOfTheWeek(forceRefresh: true)
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .kinexCard(cornerRadius: 14, fill: AppTheme.cardBackgroundElevated)
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

    // MARK: - Stats Grid

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your Progress")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                Button {
                    appState.navigateToTab(.calendar)
                } label: {
                    StatCard(
                        title: "WORKOUTS THIS WEEK",
                        value: "\(stats.workoutsThisWeek)",
                        icon: "target",
                        iconColor: AppTheme.statTarget
                    )
                }
                .buttonStyle(.plain)

                StatCard(
                    title: "TOTAL WORKOUTS",
                    value: "\(stats.totalWorkouts)",
                    icon: "dumbbell.fill",
                    iconColor: AppTheme.statDumbbell
                )

                StatCard(
                    title: "HOURS TRAINED",
                    value: stats.formattedHoursTrained,
                    icon: "clock.fill",
                    iconColor: AppTheme.statClock
                )

                StatCard(
                    title: "STREAK",
                    value: stats.formattedStreak,
                    icon: "rosette",
                    iconColor: AppTheme.statStreak
                )
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Button {
                appState.navigateToTab(.add)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Add Workout")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)

                        Text("Create or import workout")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer()
                }
                .padding(14)
                .kinexCard()
            }
            .buttonStyle(.plain)
        }
    }

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("Last 5 Workouts")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                Button("View All") {
                    appState.navigateToTab(.library)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
            }

            if recentWorkouts.isEmpty {
                Text("No workouts saved yet. Start with Add Workout to build momentum.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .kinexCard(cornerRadius: 14, fill: AppTheme.cardBackgroundElevated)
            } else {
                VStack(spacing: 10) {
                    ForEach(recentWorkouts) { workout in
                        Button {
                            appState.navigateToTab(.library)
                        } label: {
                            recentWorkoutRow(workout)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func recentWorkoutRow(_ workout: Workout) -> some View {
        HStack(spacing: 12) {
            Image(systemName: workout.source.iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 28, height: 28)
                .background(AppTheme.accent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(workout.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2)

                Text(workoutMetadata(for: workout))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            Text(dateLabel(for: workout.createdAt))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.trailing)
        }
        .padding(12)
        .kinexCard(cornerRadius: 14, fill: AppTheme.cardBackgroundElevated)
    }

    private func workoutMetadata(for workout: Workout) -> String {
        var parts: [String] = []
        if let exerciseCount = workout.exerciseCount, exerciseCount > 0 {
            parts.append("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
        }
        parts.append(workout.source.displayName.lowercased())
        return parts.joined(separator: " • ")
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

    // MARK: - Data Operations

    private func loadHomeData(forceRefreshWorkoutOfTheWeek: Bool = false) async {
        await loadStats()
        await loadWorkoutOfTheWeek(forceRefresh: forceRefreshWorkoutOfTheWeek)
    }

    private func loadStats() async {
        do {
            let workouts = try await workoutRepository.fetchAll()
            let dates = try await workoutRepository.getWorkoutDates()

            let calculator = HomeStatsCalculator()
            let newStats = calculator.calculate(workouts: workouts, workoutDates: dates)

            await MainActor.run {
                stats = newStats
                recentWorkouts = Array(workouts.prefix(5))
            }
        } catch {
            // Keep previous stats on transient failure.
        }
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
    HomeTab()
        .environmentObject(AppState(environment: .preview))
        .preferredColorScheme(.dark)
}
