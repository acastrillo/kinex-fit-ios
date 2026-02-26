import SwiftUI
import UIKit

struct WorkoutsTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var workouts: [Workout] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var showingAddWorkout = false
    @State private var error: Error?

    // Instagram import states
    @State private var selectedImport: InstagramImport?
    @State private var showingImportReview = false

    // Sync states
    @State private var isSyncing = false
    @State private var syncStatus: SyncStatus = .idle
    @State private var pendingCount = 0
    @State private var failedCount = 0
    @State private var showSyncBanner = false
    @State private var hasPerformedInitialSync = false

    private var workoutRepository: WorkoutRepository {
        appState.environment.workoutRepository
    }

    private var syncEngine: SyncEngine {
        appState.environment.syncEngine
    }

    private var filteredWorkouts: [Workout] {
        guard !searchText.isEmpty else { return workouts }
        let query = searchText.lowercased()
        return workouts.filter { workout in
            workout.title.lowercased().contains(query) ||
            (workout.content?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                content
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(
                    workout: workout,
                    onUpdate: updateWorkout,
                    onDelete: { try await deleteWorkout(id: workout.id) }
                )
            }
            .safeAreaInset(edge: .top) {
                if showSyncBanner && (pendingCount > 0 || failedCount > 0) {
                    SyncStatusBanner(
                        pendingCount: pendingCount,
                        failedCount: failedCount,
                        onRetry: triggerManualSync,
                        onDismiss: { showSyncBanner = false }
                    )
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                WorkoutFormView(mode: .create, onSave: createWorkout)
            }
            .sheet(isPresented: $showingImportReview) {
                if let importItem = selectedImport {
                    InstagramImportReviewView(
                        importItem: importItem,
                        onSave: saveImportedWorkout,
                        onDiscard: {
                            appState.instagramImportService.removeImport(importItem)
                            selectedImport = nil
                        }
                    )
                }
            }
            .refreshable {
                await loadWorkouts()
                await triggerSync()
                if appState.featureFlags.shareExtensionImportEnabled {
                    appState.checkForPendingImports()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                if appState.featureFlags.shareExtensionImportEnabled {
                    appState.checkForPendingImports()
                }
            }
        }
        .task {
            await startObserving()
            if appState.featureFlags.shareExtensionImportEnabled {
                appState.checkForPendingImports()
            }
            updateSyncStatus()
            if !hasPerformedInitialSync {
                hasPerformedInitialSync = true
                await triggerSync()
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if appState.featureFlags.shareExtensionImportEnabled && appState.instagramImportService.hasPendingImports {
                    PendingImportsBanner(
                        selectedImport: $selectedImport,
                        showingImportReview: $showingImportReview
                    )
                    .padding(.horizontal, 16)
                }

                if isLoading {
                    LoadingView()
                        .padding(.top, 80)
                } else if workouts.isEmpty {
                    EmptyWorkoutsView(onAddTapped: { showingAddWorkout = true })
                        .padding(.top, 80)
                } else if !searchText.isEmpty && filteredWorkouts.isEmpty {
                    SearchEmptyState(query: searchText)
                        .padding(.top, 80)
                } else {
                    workoutCards
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workout Library")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("\(workouts.count) workout\(workouts.count == 1 ? "" : "s") saved")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer(minLength: 12)

                VStack(spacing: 10) {
                    if pendingCount > 0 || failedCount > 0 {
                        SyncStatusIndicator(
                            status: syncStatus,
                            pendingCount: pendingCount,
                            failedCount: failedCount,
                            onTap: triggerManualSync
                        )
                    }
                }
            }

            searchField
        }
        .padding(.horizontal, 16)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.secondaryText)

            TextField("Search workouts...", text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .foregroundStyle(AppTheme.primaryText)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .kinexCard(cornerRadius: 14, fill: AppTheme.cardBackgroundElevated)
    }

    private var workoutCards: some View {
        // Workaround: eager layout avoids first-row tap misalignment seen with LazyVStack in this view.
        VStack(spacing: 14) {
            ForEach(filteredWorkouts) { workout in
                NavigationLink(value: workout) {
                    WorkoutRowView(workout: workout)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .contextMenu {
                    Button(role: .destructive) {
                        Task {
                            try? await deleteWorkout(id: workout.id)
                        }
                    } label: {
                        Label("Delete Workout", systemImage: "trash")
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Data Operations

    private func startObserving() async {
        do {
            for try await updatedWorkouts in workoutRepository.observeAll() {
                workouts = updatedWorkouts
                isLoading = false
            }
        } catch {
            self.error = error
            isLoading = false
        }
    }

    private func loadWorkouts() async {
        do {
            workouts = try await workoutRepository.fetchAll()
            error = nil
        } catch {
            self.error = error
        }
    }

    private func createWorkout(title: String, content: String?) async throws {
        let workout = Workout(
            title: title,
            content: content?.isEmpty == true ? nil : content,
            source: .manual,
            exerciseCount: estimateExerciseCount(from: content)
        )
        try await workoutRepository.create(workout)
    }

    private func updateWorkout(_ workout: Workout) async throws {
        try await workoutRepository.update(workout)
    }

    private func deleteWorkout(id: String) async throws {
        try await workoutRepository.delete(id: id)
    }

    private func saveImportedWorkout(title: String, content: String?) async throws {
        let workout = Workout(
            title: title,
            content: content,
            source: .instagram,
            exerciseCount: estimateExerciseCount(from: content),
            difficulty: inferDifficulty(title: title, content: content),
            sourceURL: selectedImport?.postURL
        )
        try await workoutRepository.create(workout)
        selectedImport = nil
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

    private func inferDifficulty(title: String, content: String?) -> String? {
        let sourceText = "\(title) \(content ?? "")".lowercased()
        if sourceText.contains("beginner") { return "beginner" }
        if sourceText.contains("advanced") || sourceText.contains("elite") { return "advanced" }
        if sourceText.contains("intermediate") { return "intermediate" }
        return nil
    }

    // MARK: - Sync Operations

    private func updateSyncStatus() {
        do {
            pendingCount = try syncEngine.getPendingCount()
            failedCount = try syncEngine.getFailedCount()

            if isSyncing {
                syncStatus = .syncing
            } else if failedCount > 0 {
                syncStatus = .error
                showSyncBanner = true
            } else if pendingCount > 0 {
                syncStatus = .idle
            } else {
                syncStatus = .success
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    if syncStatus == .success {
                        syncStatus = .idle
                    }
                }
            }
        } catch {
            // Failed to get sync status
        }
    }

    private func triggerSync() async {
        guard !isSyncing else { return }

        isSyncing = true
        syncStatus = .syncing

        do {
            try await syncEngine.processSyncQueue()
            _ = try await workoutRepository.importFromServer()
            await loadWorkouts() // Refresh workouts after push + pull sync
        } catch {
            // Sync failed, status will be updated by updateSyncStatus
        }

        isSyncing = false
        updateSyncStatus()
    }

    private func triggerManualSync() {
        Task {
            await triggerSync()
        }
    }
}

// MARK: - Loading View

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(AppTheme.accent)

            Text("Loading workouts...")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Empty States

private struct EmptyWorkoutsView: View {
    let onAddTapped: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(AppTheme.secondaryText)

            Text("No Workouts Yet")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.primaryText)

            Text("Add your first workout to start building your library.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)

            Button("Add Workout") {
                onAddTapped()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }
}

private struct SearchEmptyState: View {
    let query: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)

            Text("No Matches")
                .font(.headline)
                .foregroundStyle(AppTheme.primaryText)

            Text("No workouts found for \"\(query)\".")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
}

// MARK: - Preview

#Preview("With Workouts") {
    let appState = AppState(environment: .preview)

    // Add sample workouts
    Task {
        let repo = appState.environment.workoutRepository
        _ = try? await repo.create(Workout(
            title: "This Week's Workout - Endurance Builder",
            content: "A high-intensity conditioning workout combining aerobic intervals with functional strength movements.",
            source: .manual,
            durationMinutes: 55,
            exerciseCount: 9,
            difficulty: "advanced"
        ))
        _ = try? await repo.create(Workout(
            title: "30-Minute Bodyweight Full Body Blast",
            content: "High-intensity bodyweight circuit targeting all major muscle groups. Perfect for building work capacity.",
            source: .instagram,
            durationMinutes: 30,
            exerciseCount: 7,
            difficulty: "advanced"
        ))
    }

    return WorkoutsTab()
        .environmentObject(appState)
        .appDarkTheme()
}

#Preview("Empty State") {
    WorkoutsTab()
        .environmentObject(AppState(environment: .preview))
        .appDarkTheme()
}
