import SwiftUI

/// Add workout tab - central action hub with options for manual entry, scanning, and AI generation
struct AddWorkoutTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingManualEntry = false
    @State private var showingScanWorkout = false
    @State private var showingAIGenerate = false

    private var workoutRepository: WorkoutRepository {
        appState.environment.workoutRepository
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(AppTheme.accent)

                        Text("Add Workout")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.primaryText)

                        Text("Choose how you want to log your workout")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 10)

                    // Options
                    VStack(spacing: 16) {
                        AddOptionCard(
                            icon: "pencil.line",
                            title: "Manual Entry",
                            subtitle: "Type in your workout details",
                            accentColor: AppTheme.accent
                        ) {
                            showingManualEntry = true
                        }

                        AddOptionCard(
                            icon: "doc.text.viewfinder",
                            title: "Scan Workout",
                            subtitle: "Take a photo to extract exercises",
                            accentColor: AppTheme.statClock
                        ) {
                            showingScanWorkout = true
                        }

                        AddOptionCard(
                            icon: "sparkles",
                            title: "AI Generate",
                            subtitle: "Let AI create a workout for you",
                            accentColor: AppTheme.statStreak
                        ) {
                            showingAIGenerate = true
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Add")
            .sheet(isPresented: $showingManualEntry) {
                WorkoutFormView(mode: .create, onSave: createWorkout)
            }
            .sheet(isPresented: $showingScanWorkout) {
                ScanTab()
            }
            .sheet(isPresented: $showingAIGenerate) {
                WorkoutGeneratorView { title, content in
                    Task {
                        await saveGeneratedWorkout(title: title, content: content)
                    }
                }
            }
        }
    }

    // MARK: - Data Operations

    private func createWorkout(title: String, content: String?, enhancementSourceText: String?) async throws {
        let normalizedContent = content?.isEmpty == true ? nil : content
        let normalizedEnhancementSource = enhancementSourceText?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let workout = Workout(
            title: title,
            content: normalizedContent,
            enhancementSourceText: (normalizedEnhancementSource?.isEmpty == false ? normalizedEnhancementSource : normalizedContent),
            source: .manual
        )
        let savedWorkout = try await workoutRepository.create(workout)
        await MainActor.run {
            appState.navigateToWorkoutCard(workoutID: savedWorkout.id)
        }
    }

    private func saveGeneratedWorkout(title: String, content: String) async {
        let workout = Workout(
            title: title,
            content: content,
            enhancementSourceText: content,
            source: .manual
        )
        guard let savedWorkout = try? await workoutRepository.create(workout) else { return }
        await MainActor.run {
            appState.navigateToWorkoutCard(workoutID: savedWorkout.id)
        }
    }
}

// MARK: - Add Option Card

private struct AddOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(accentColor)
                    .frame(width: 44, height: 44)
                    .background(accentColor.opacity(0.15))
                    .cornerRadius(12)

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryText)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            .padding()
            .background(AppTheme.cardBackground)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    AddWorkoutTab()
        .environmentObject(AppState(environment: .preview))
        .preferredColorScheme(.dark)
}
