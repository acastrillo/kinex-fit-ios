import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout
    var onUpdate: ((Workout) async throws -> Void)?
    var onDelete: (() async throws -> Void)?

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    @State private var isEnhancing = false
    @State private var enhancementError: String?
    @State private var showingEnhancementError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with metadata
                headerSection

                Divider()

                // Workout content
                if let content = workout.content, !content.isEmpty {
                    contentSection(content: content)
                } else {
                    emptyContentSection
                }
            }
            .padding()
        }
        .navigationTitle(workout.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if isEnhancing {
                    ProgressView()
                }

                Menu {
                    Button {
                        Task { await enhanceWithAI() }
                    } label: {
                        Label("Enhance with AI", systemImage: "sparkles")
                    }
                    .disabled(isEnhancing || workout.content == nil || workout.content?.isEmpty == true)

                    Divider()

                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Enhancement Failed", isPresented: $showingEnhancementError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(enhancementError ?? "Failed to enhance workout")
        }
        .sheet(isPresented: $showingEditSheet) {
            WorkoutFormView(
                mode: .edit(workout),
                onSave: { title, content in
                    var updated = workout
                    updated.title = title
                    updated.content = content
                    try await onUpdate?(updated)
                }
            )
        }
        .alert("Delete Workout?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await deleteWorkout() }
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                // Source badge
                HStack(spacing: 6) {
                    Image(systemName: workout.source.iconName)
                    Text(workout.source.displayName)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.secondary.opacity(0.15))
                .cornerRadius(6)

                // Dates
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.tertiary)
                        Text("Created: \(workout.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    }

                    if workout.updatedAt != workout.createdAt {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .foregroundStyle(.tertiary)
                            Text("Updated: \(workout.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Content Section

    private func contentSection(content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Details")
                .font(.headline)
                .foregroundStyle(.primary)

            Text(content)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
        }
    }

    private var emptyContentSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)

            Text("No details added")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Add Details") {
                showingEditSheet = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Actions

    private func deleteWorkout() async {
        isDeleting = true
        do {
            try await onDelete?()
            dismiss()
        } catch {
            // Handle error - could show alert
        }
        isDeleting = false
    }

    private func enhanceWithAI() async {
        guard let content = workout.content, !content.isEmpty else { return }

        isEnhancing = true
        defer { isEnhancing = false }

        let aiService = AIService(apiClient: appState.environment.apiClient)

        do {
            let response = try await aiService.enhanceWorkout(text: content)

            // Update workout with enhanced content
            var updated = workout
            updated.content = response.workout.content
            updated.title = response.workout.title
            try await onUpdate?(updated)
        } catch let error as AIError {
            enhancementError = error.errorDescription ?? "Enhancement failed"
            showingEnhancementError = true
        } catch {
            enhancementError = error.localizedDescription
            showingEnhancementError = true
        }
    }
}

// MARK: - Preview

#Preview("With Content") {
    NavigationStack {
        WorkoutDetailView(
            workout: Workout(
                title: "Push Day - Chest and Triceps",
                content: """
                Bench Press
                4 sets x 8 reps @ 185 lbs

                Incline Dumbbell Press
                3 sets x 10 reps @ 60 lbs

                Cable Flyes
                3 sets x 12 reps

                Tricep Pushdowns
                3 sets x 15 reps

                Overhead Tricep Extension
                3 sets x 12 reps
                """,
                source: .manual
            ),
            onUpdate: { _ in },
            onDelete: { }
        )
    }
}

#Preview("Empty Content") {
    NavigationStack {
        WorkoutDetailView(
            workout: Workout(
                title: "Quick Workout",
                content: nil,
                source: .instagram
            ),
            onUpdate: { _ in },
            onDelete: { }
        )
    }
}
