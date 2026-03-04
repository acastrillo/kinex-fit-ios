import SwiftUI

/// Home tab - landing screen with personalized greeting, weekly highlight, and progress stats
struct HomeTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var stats: HomeStats = .empty
    @State private var recentWorkouts: [Workout] = []
    @State private var user: User?
    
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
            await loadHomeData()
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
        WorkoutOfTheWeekSection()
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

    private func loadHomeData() async {
        await loadStats()
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

}

// MARK: - Preview

#Preview {
    HomeTab()
        .environmentObject(AppState(environment: .preview))
        .preferredColorScheme(.dark)
}
