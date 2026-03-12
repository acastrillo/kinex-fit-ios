import SwiftUI

// MARK: - Importing Steps View

private struct ImportingStepsView: View {
    let progress: Double

    private var stepLabel: String {
        if progress >= 0.6 { return "Parsing exercises..." }
        if progress >= 0.3 { return "Extracting workout..." }
        return "Reading content..."
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.accent)
                .symbolEffect(.pulse, options: .repeating)

            Text(stepLabel)
                .font(.headline)
                .foregroundStyle(AppTheme.primaryText)
                .animation(.easeInOut, value: stepLabel)

            VStack(spacing: 14) {
                parseStepRow("Reading content", isDone: progress >= 0.3, isActive: progress < 0.3)
                parseStepRow("Extracting workout", isDone: progress >= 0.6, isActive: progress >= 0.3 && progress < 0.6)
                parseStepRow("Parsing exercises", isDone: progress >= 1.0, isActive: progress >= 0.6 && progress < 1.0)
            }
            .padding(.horizontal, 32)
        }
    }

    private func parseStepRow(_ label: String, isDone: Bool, isActive: Bool) -> some View {
        HStack(spacing: 10) {
            Group {
                if isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if isActive {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(AppTheme.accent)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }
            .frame(width: 20)

            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isDone || isActive ? AppTheme.primaryText : AppTheme.tertiaryText)

            Spacer()
        }
    }
}

struct ImportProgressView: View {
    let parsedWorkout: CaptionParsedWorkout?
    let progress: Double // 0.0 – 1.0
    let onCreateWorkout: () -> Void
    let onCancel: () -> Void

    private var exercises: [CaptionParsedExercise] {
        parsedWorkout?.exercises ?? []
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(progress < 1 ? "Analyzing workout..." : "Analysis complete")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                        Spacer()
                        if progress < 1 {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }

                    ProgressView(value: progress)
                        .tint(AppTheme.accent)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()

                if exercises.isEmpty && progress < 1 {
                    Spacer()
                    ImportingStepsView(progress: progress)
                    Spacer()
                } else if exercises.isEmpty && progress >= 1 {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "doc.questionmark")
                            .font(.system(size: 40))
                            .foregroundStyle(AppTheme.secondaryText)
                        Text("No exercises detected")
                            .font(.headline)
                            .foregroundStyle(AppTheme.primaryText)
                        Text("Try a clearer image or add exercises manually.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    Spacer()
                } else {
                    // Detected exercises list
                    List {
                        Section {
                            ForEach(exercises) { exercise in
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.system(size: 18))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exercise.exerciseName)
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundStyle(AppTheme.primaryText)

                                        if let sets = exercise.sets, let reps = exercise.reps {
                                            Text("\(sets) × \(reps)")
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.secondaryText)
                                        } else if let sets = exercise.sets {
                                            Text("\(sets) sets")
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.secondaryText)
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        } header: {
                            Text("\(exercises.count) exercise\(exercises.count == 1 ? "" : "s") detected")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.secondaryText)
                                .textCase(nil)
                        }
                    }
                    .listStyle(.insetGrouped)
                }

                // CTA
                if progress >= 1 && !exercises.isEmpty {
                    VStack(spacing: 12) {
                        Button(action: onCreateWorkout) {
                            Text("Create Workout")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .accessibilityLabel("Create workout from \(exercises.count) detected exercises")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Import Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}
