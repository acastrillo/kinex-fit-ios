import SwiftUI

/// Unified workout creation view with AI generation and import options
struct CreateWorkoutView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: ImportTab = .instagram
    @State private var showingAIGenerate = false

    enum ImportTab: String, CaseIterable, Identifiable {
        case instagram = "URL/Social"
        case photo = "Image/OCR"
        case manual = "Manual"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .instagram: return "link"
            case .photo: return "camera.viewfinder"
            case .manual: return "doc.text"
            }
        }
    }

    private var workoutRepository: WorkoutRepository {
        appState.environment.workoutRepository
    }

    private var availableTabs: [ImportTab] {
        if appState.featureFlags.shareExtensionImportEnabled {
            return ImportTab.allCases
        }
        return [.photo, .manual]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection

                AIFeatureCard {
                    showingAIGenerate = true
                }
                .padding(.horizontal, 16)

                importSection
                    .padding(.horizontal, 16)
            }
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
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
        .onChange(of: appState.featureFlags.shareExtensionImportEnabled) { _, enabled in
            if !enabled && selectedTab == .instagram {
                selectedTab = .photo
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Create Workout")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Text("Generate with AI or import from social media")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 16)
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Text("Import Workout")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
            }

            Picker("Import Method", selection: $selectedTab) {
                ForEach(availableTabs) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(4)
            .background(AppTheme.cardBackgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

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
            .frame(minHeight: 320)
        }
        .padding(16)
        .kinexCard(cornerRadius: 18)
    }

    // MARK: - Actions

    private func saveGeneratedWorkout(title: String, content: String) async {
        let workout = Workout(
            title: title,
            content: content,
            source: .manual  // Generated workouts are saved as manual
        )
        _ = try? await workoutRepository.create(workout)
    }

    private func saveInstagramWorkout(title: String, content: String?) async throws {
        guard let pendingWorkout = appState.pendingInstagramWorkout else { return }

        let workout = Workout(
            title: title,
            content: content,
            source: pendingWorkout.sourcePlatform.workoutSource,
            durationMinutes: pendingWorkout.parsedData.workoutV1?.totalDuration,
            exerciseCount: pendingWorkout.exerciseCount,
            difficulty: pendingWorkout.parsedData.workoutV1?.difficulty?.lowercased(),
            imageURL: pendingWorkout.imageURL,
            sourceURL: pendingWorkout.sourceURL,
            sourceAuthor: pendingWorkout.author?.username
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
