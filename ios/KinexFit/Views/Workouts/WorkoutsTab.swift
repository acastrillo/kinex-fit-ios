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
            Group {
                if isLoading {
                    LoadingView()
                } else if workouts.isEmpty {
                    EmptyWorkoutsView(onAddTapped: { showingAddWorkout = true })
                } else if !searchText.isEmpty && filteredWorkouts.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    workoutList
                }
            }
            .navigationTitle("Workouts")
            .searchable(text: $searchText, prompt: "Search workouts")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if pendingCount > 0 || failedCount > 0 {
                        SyncStatusIndicator(
                            status: syncStatus,
                            pendingCount: pendingCount,
                            failedCount: failedCount,
                            onTap: triggerManualSync
                        )
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddWorkout = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
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
                appState.checkForPendingImports()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                appState.checkForPendingImports()
            }
        }
        .task {
            await startObserving()
            appState.checkForPendingImports()
            updateSyncStatus()
        }
    }

    // MARK: - Workout List

    private var workoutList: some View {
        List {
            // Pending imports banner
            if appState.instagramImportService.hasPendingImports {
                Section {
                    PendingImportsBanner(
                        selectedImport: $selectedImport,
                        showingImportReview: $showingImportReview
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // Workouts
            ForEach(filteredWorkouts) { workout in
                NavigationLink(value: workout) {
                    WorkoutRowView(workout: workout)
                }
            }
            .onDelete(perform: deleteWorkouts)
        }
        .listStyle(.plain)
        .navigationDestination(for: Workout.self) { workout in
            WorkoutDetailView(
                workout: workout,
                onUpdate: updateWorkout,
                onDelete: { try await deleteWorkout(id: workout.id) }
            )
        }
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
            source: .manual
        )
        try await workoutRepository.create(workout)
    }

    private func updateWorkout(_ workout: Workout) async throws {
        try await workoutRepository.update(workout)
    }

    private func deleteWorkout(id: String) async throws {
        try await workoutRepository.delete(id: id)
    }

    private func deleteWorkouts(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let workout = filteredWorkouts[index]
                try? await workoutRepository.delete(id: workout.id)
            }
        }
    }

    private func saveImportedWorkout(title: String, content: String?) async throws {
        let workout = Workout(
            title: title,
            content: content,
            source: .instagram
        )
        try await workoutRepository.create(workout)
        selectedImport = nil
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
                // Hide success status after 2 seconds
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
            await loadWorkouts() // Refresh workouts after sync
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
            Text("Loading workouts...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Empty State

private struct EmptyWorkoutsView: View {
    let onAddTapped: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Workouts", systemImage: "dumbbell")
        } description: {
            Text("Add your first workout to get started")
        } actions: {
            Button("Add Workout") {
                onAddTapped()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Preview

#Preview("With Workouts") {
    let appState = AppState(environment: .preview)

    // Add sample workouts
    Task {
        let repo = appState.environment.workoutRepository
        try? await repo.create(Workout(
            title: "Push Day",
            content: "Bench Press 4x8\nOverhead Press 3x10\nTricep Dips 3x12",
            source: .manual
        ))
        try? await repo.create(Workout(
            title: "HIIT Session",
            content: "20 min AMRAP\n10 Burpees\n20 Air Squats\n30 Double Unders",
            source: .instagram
        ))
        try? await repo.create(Workout(
            title: "CrossFit WOD",
            content: "Fran\n21-15-9\nThrusters 95/65\nPull-ups",
            source: .ocr
        ))
    }

    return WorkoutsTab()
        .environmentObject(appState)
}

#Preview("Empty State") {
    WorkoutsTab()
        .environmentObject(AppState(environment: .preview))
}
