import SwiftUI

/// Edit view for Instagram-fetched workout before saving
struct InstagramWorkoutEditView: View {
    let fetchedWorkout: FetchedWorkout
    let onSave: (String, String?) async throws -> Void
    let onDiscard: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var content: String
    @State private var isSaving = false
    @State private var error: Error?
    @State private var showingError = false

    init(
        fetchedWorkout: FetchedWorkout,
        onSave: @escaping (String, String?) async throws -> Void,
        onDiscard: @escaping () -> Void
    ) {
        self.fetchedWorkout = fetchedWorkout
        self.onSave = onSave
        self.onDiscard = onDiscard
        _title = State(initialValue: fetchedWorkout.title)
        _content = State(initialValue: fetchedWorkout.content)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Instagram image preview (if available)
                    if let imageURLString = fetchedWorkout.imageURL,
                       let imageURL = URL(string: imageURLString) {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 200)
                                    .cornerRadius(12)
                                    .shadow(radius: 4)
                            case .failure:
                                imagePlaceholder
                            case .empty:
                                ProgressView()
                                    .frame(height: 150)
                            @unknown default:
                                imagePlaceholder
                            }
                        }
                    }

                    // Source info
                    sourceInfoSection

                    // Quota indicator
                    if fetchedWorkout.hasQuotaInfo,
                       let used = fetchedWorkout.quotaUsed,
                       let limit = fetchedWorkout.quotaLimit {
                        InstagramQuotaIndicator(used: used, limit: limit)
                    }

                    // Editable fields
                    editableFieldsSection

                    // Parsed exercises preview
                    if !fetchedWorkout.parsedData.exercises.isEmpty {
                        parsedExercisesSection
                    }

                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Review Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        onDiscard()
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(!isValid || isSaving)
                    .fontWeight(.semibold)
                }
            }
            .overlay {
                if isSaving {
                    savingOverlay
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(error?.localizedDescription ?? "An error occurred")
            }
        }
    }

    // MARK: - Subviews

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemBackground))
            .frame(height: 150)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("Image unavailable")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
    }

    private var sourceInfoSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.on.rectangle")
                .foregroundStyle(.pink)

            VStack(alignment: .leading, spacing: 2) {
                Text("From Instagram")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let author = fetchedWorkout.author {
                    Text("@\(author.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(fetchedWorkout.sourceURL)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(fetchedWorkout.workoutType)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(4)

                Text("\(fetchedWorkout.exerciseCount) exercises")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }

    private var editableFieldsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Workout Details")
                .font(.headline)

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Title")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Workout Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Description & Exercises")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
            }
        }
    }

    private var parsedExercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detected Exercises")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(Array(fetchedWorkout.parsedData.exercises.enumerated()), id: \.offset) { index, exercise in
                    ExerciseCard(exercise: exercise, index: index + 1)
                }
            }
        }
    }

    private var savingOverlay: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                Text("Saving workout...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func save() async {
        isSaving = true

        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedContent = content.trimmingCharacters(in: .whitespaces)

        do {
            try await onSave(trimmedTitle, trimmedContent.isEmpty ? nil : trimmedContent)
            dismiss()
        } catch {
            self.error = error
            showingError = true
        }

        isSaving = false
    }
}

// MARK: - Exercise Card

private struct ExerciseCard: View {
    let exercise: ExerciseData
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            // Index badge
            Text("\(index)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.orange)
                .clipShape(Circle())

            // Exercise info
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    if let sets = exercise.sets {
                        Text("\(sets) sets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let reps = exercise.reps {
                        Text("\(reps) \(exercise.unit ?? "reps")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let weight = exercise.weight {
                        Text("@ \(weight)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    let mockWorkout = FetchedWorkout(
        from: InstagramFetchResponse(
            url: "https://instagram.com/p/test",
            title: "Push Day Workout",
            content: "Bench Press 4x8 @ 185 lb\nOverhead Press 3x10 @ 95 lb\nTricep Dips 3x12",
            author: AuthorInfo(username: "fitness_pro", fullName: "Fitness Pro"),
            stats: PostStats(likes: 1250, comments: 45),
            image: nil,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            mediaType: "image",
            parsedWorkout: nil,
            scanQuotaUsed: 5,
            scanQuotaLimit: 10,
            quotaUsed: 5,
            quotaLimit: 10
        ),
        ingestResponse: WorkoutIngestResponse(
            title: "Push Day Workout",
            workoutType: "standard",
            exercises: [
                ExerciseData(id: "1", name: "Bench Press", sets: 4, reps: "8", weight: "185 lb", unit: "reps", notes: nil, restSeconds: nil),
                ExerciseData(id: "2", name: "Overhead Press", sets: 3, reps: "10", weight: "95 lb", unit: "reps", notes: nil, restSeconds: nil),
                ExerciseData(id: "3", name: "Tricep Dips", sets: 3, reps: "12", weight: nil, unit: "reps", notes: nil, restSeconds: nil)
            ],
            rows: nil,
            summary: nil,
            breakdown: nil,
            structure: nil,
            amrapBlocks: nil,
            emomBlocks: nil,
            usedLLM: false,
            workoutV1: nil
        )
    )

    InstagramWorkoutEditView(
        fetchedWorkout: mockWorkout,
        onSave: { _, _ in },
        onDiscard: { }
    )
    .preferredColorScheme(.dark)
}
