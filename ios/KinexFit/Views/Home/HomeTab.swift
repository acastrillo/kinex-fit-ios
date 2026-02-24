import SwiftUI

/// Home tab - landing screen with personalized greeting, AI feature card, and stats grid
struct HomeTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var stats: HomeStats = .empty
    @State private var showingWorkoutGenerator = false
    @State private var user: User?

    private var workoutRepository: WorkoutRepository {
        appState.environment.workoutRepository
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                greetingSection

                AIFeatureCard {
                    showingWorkoutGenerator = true
                }

                statsGrid

                quickActionsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 30)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .refreshable {
            await loadStats()
        }
        .sheet(isPresented: $showingWorkoutGenerator) {
            WorkoutGeneratorView { title, content in
                Task {
                    await saveGeneratedWorkout(title: title, content: content)
                }
            }
        }
        .task {
            user = try? await appState.environment.userRepository.getCurrentUser()
            await loadStats()
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

    // MARK: - Stats Grid

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your Progress")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    title: "WORKOUTS THIS WEEK",
                    value: "\(stats.workoutsThisWeek)",
                    icon: "target",
                    iconColor: AppTheme.statTarget
                )

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

    // MARK: - Data Operations

    private func loadStats() async {
        do {
            let workouts = try await workoutRepository.fetchAll()
            let dates = try await workoutRepository.getWorkoutDates()

            let calculator = HomeStatsCalculator()
            let newStats = calculator.calculate(workouts: workouts, workoutDates: dates)

            await MainActor.run {
                stats = newStats
            }
        } catch {
            // Keep previous stats on transient failure.
        }
    }

    private func saveGeneratedWorkout(title: String, content: String) async {
        let workout = Workout(
            title: title,
            content: content,
            source: .manual // AI-generated but saved as manual entry
        )
        _ = try? await workoutRepository.create(workout)
        await loadStats()
    }
}

// MARK: - Preview

#Preview {
    HomeTab()
        .environmentObject(AppState(environment: .preview))
        .preferredColorScheme(.dark)
}
