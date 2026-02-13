import SwiftUI

/// Unified workout creation view with AI generation and import options
struct CreateWorkoutView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: ImportTab = .instagram
    @State private var showingAIGenerate = false

    enum ImportTab: String, CaseIterable, Identifiable {
        case instagram = "Instagram"
        case photo = "Photo"
        case manual = "Manual"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .instagram: return "camera.on.rectangle"
            case .photo: return "photo"
            case .manual: return "pencil.line"
            }
        }
    }

    private var workoutRepository: WorkoutRepository {
        appState.environment.workoutRepository
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // AI Generator Card
                    AIGeneratorCard {
                        showingAIGenerate = true
                    }
                    .padding(.horizontal)

                    // Divider
                    WorkoutDivider()
                        .padding(.horizontal)

                    // Import Section
                    importSection
                }
                .padding(.vertical)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Create Workout")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingAIGenerate) {
                WorkoutGeneratorView { title, content in
                    Task {
                        await saveGeneratedWorkout(title: title, content: content)
                    }
                }
            }
            .sheet(isPresented: $appState.showInstagramEditSheet) {
                if let workout = appState.pendingInstagramWorkout {
                    InstagramWorkoutEditView(
                        fetchedWorkout: workout,
                        onSave: saveInstagramWorkout,
                        onDiscard: dismissInstagramEdit
                    )
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Generate with AI or import from Instagram")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal)
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section title
            Text("Import Workout")
                .font(.headline)
                .padding(.horizontal)

            // Tab picker
            Picker("Import Method", selection: $selectedTab) {
                ForEach(ImportTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Tab content
            Group {
                switch selectedTab {
                case .instagram:
                    InstagramImportTab()
                case .photo:
                    PhotoImportTab()
                case .manual:
                    ManualImportTab()
                }
            }
            .frame(minHeight: 300)
        }
    }

    // MARK: - Actions

    private func saveGeneratedWorkout(title: String, content: String) async {
        let workout = Workout(
            title: title,
            content: content,
            source: .manual  // Generated workouts are saved as manual
        )
        try? await workoutRepository.create(workout)
    }

    private func saveInstagramWorkout(title: String, content: String?) async throws {
        guard let fetchedWorkout = appState.pendingInstagramWorkout else { return }

        let workout = Workout(
            title: title,
            content: content,
            source: .instagram
        )
        try await workoutRepository.create(workout)

        // Clear pending workout
        await MainActor.run {
            appState.pendingInstagramWorkout = nil
            appState.showInstagramEditSheet = false
        }
    }

    private func dismissInstagramEdit() {
        appState.pendingInstagramWorkout = nil
        appState.showInstagramEditSheet = false
    }
}

#Preview {
    CreateWorkoutView()
        .environmentObject(AppState(environment: .preview))
        .preferredColorScheme(.dark)
}
