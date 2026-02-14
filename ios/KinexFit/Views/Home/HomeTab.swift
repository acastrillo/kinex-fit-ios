import SwiftUI

/// Home tab - landing screen with personalized greeting, AI feature card, and stats grid
struct HomeTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var stats: HomeStats = .empty
    @State private var isLoading = true
    @State private var showingWorkoutGenerator = false
    @State private var user: User?

    private var workoutRepository: WorkoutRepository {
        appState.environment.workoutRepository
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Greeting section
                    greetingSection

                    // AI Feature Card
                    AIFeatureCard {
                        showingWorkoutGenerator = true
                    }

                    // Stats section header
                    Text("Your Progress")
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryText)

                    // Stats grid
                    statsGrid
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Home")
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
        }
        .task {
            user = try? await appState.environment.userRepository.getCurrentUser()
            await loadStats()
        }
    }

    // MARK: - Greeting Section

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(timeBasedGreeting)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.primaryText)

            if let firstName = user?.firstName, !firstName.isEmpty {
                Text("Welcome back, \(firstName)!")
                    .font(.headline)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Text("Ready to crush your fitness goals today?")
                .font(.subheadline)
                .foregroundStyle(AppTheme.tertiaryText)
        }
    }

    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: "Workouts This Week",
                value: "\(stats.workoutsThisWeek)",
                icon: "target",
                iconColor: AppTheme.statTarget
            )

            StatCard(
                title: "Total Workouts",
                value: "\(stats.totalWorkouts)",
                icon: "dumbbell.fill",
                iconColor: AppTheme.statDumbbell
            )

            StatCard(
                title: "Hours Trained",
                value: stats.formattedHoursTrained,
                icon: "clock.fill",
                iconColor: AppTheme.statClock
            )

            StatCard(
                title: "Streak",
                value: stats.formattedStreak,
                icon: "flame.fill",
                iconColor: AppTheme.statStreak
            )
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
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func saveGeneratedWorkout(title: String, content: String) async {
        let workout = Workout(
            title: title,
            content: content,
            source: .manual // AI-generated but saved as manual entry
        )
        try? await workoutRepository.create(workout)
        await loadStats()
    }
}

// MARK: - Preview

#Preview {
    HomeTab()
        .environmentObject(AppState(environment: .preview))
        .preferredColorScheme(.dark)
}
