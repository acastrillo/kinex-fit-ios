import SwiftUI

/// Shows the result of an AI enhancement
struct EnhancementResultView: View {
    let response: EnhanceWorkoutResponse
    let originalText: String
    let onAccept: (String, String) -> Void
    let onDiscard: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingOriginal = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Enhanced workout preview
                    enhancedWorkoutSection

                    // Exercises list
                    if let exercises = response.workout.exercises, !exercises.isEmpty {
                        exercisesSection(exercises)
                    }

                    // Workout type badge
                    if let workoutType = response.workout.workoutType {
                        workoutTypeBadge(workoutType)
                    }

                    // AI Notes
                    if let aiNotes = response.workout.aiNotes, !aiNotes.isEmpty {
                        aiNotesSection(aiNotes)
                    }

                    Divider()

                    // Original text comparison
                    originalTextSection
                }
                .padding()
            }
            .navigationTitle("AI Enhanced")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        onDiscard()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Use This") {
                        onAccept(
                            response.workout.title,
                            response.workout.content
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sections

    private var enhancedWorkoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("Enhanced Workout")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(response.workout.title)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(response.workout.content)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
        }
    }

    private func exercisesSection(_ exercises: [EnhancedExercise]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundStyle(.blue)
                Text("Exercises")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(exercises, id: \.exerciseId) { exercise in
                    HStack {
                        Text(exercise.displayText)
                            .font(.subheadline)
                        Spacer()
                        if let notes = exercise.notes {
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private func workoutTypeBadge(_ type: String) -> some View {
        HStack {
            Text("Workout Type")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(type.capitalized)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
        }
    }

    private func aiNotesSection(_ notes: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundStyle(.yellow)
                Text("AI Insights")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(notes, id: \.self) { note in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(12)
        }
    }

    private var originalTextSection: some View {
        DisclosureGroup("View Original Text", isExpanded: $showingOriginal) {
            Text(originalText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
        }
    }
}

// MARK: - Preview

#Preview {
    EnhancementResultView(
        response: EnhanceWorkoutResponse(
            workout: EnhancedWorkoutData(
                workoutId: "preview_123",
                title: "Push Day - Chest & Triceps",
                description: "Upper body push workout focusing on chest and triceps",
                exercises: [
                    EnhancedExercise(id: "1", name: "Bench Press", sets: 4, reps: .int(8), weight: .string("185 lbs"), restSeconds: 90, notes: nil, duration: nil),
                    EnhancedExercise(id: "2", name: "Incline Dumbbell Press", sets: 3, reps: .int(10), weight: .string("60 lbs"), restSeconds: 60, notes: nil, duration: nil),
                    EnhancedExercise(id: "3", name: "Cable Flyes", sets: 3, reps: .int(12), weight: nil, restSeconds: 45, notes: nil, duration: nil),
                    EnhancedExercise(id: "4", name: "Tricep Pushdowns", sets: 3, reps: .int(15), weight: nil, restSeconds: 45, notes: nil, duration: nil),
                ],
                tags: ["strength", "push", "chest"],
                difficulty: "intermediate",
                totalDuration: 45,
                workoutType: "standard",
                structure: nil,
                aiEnhanced: true,
                aiNotes: ["Focus on controlled eccentric phase", "Keep chest up during all pressing movements"]
            ),
            quotaRemaining: 7
        ),
        originalText: "bench 4x8 185\nincline db 3x10 60\nflyes 3x12\ntri pushdown 3x15\noh ext 3x12",
        onAccept: { _, _ in },
        onDiscard: { }
    )
}
