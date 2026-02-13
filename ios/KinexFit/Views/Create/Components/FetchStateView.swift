import SwiftUI

/// Displays different states for Instagram fetch operation
struct FetchStateView: View {
    let state: FetchState
    let onProcessAndEdit: (FetchedWorkout) -> Void
    let onRetry: () -> Void

    enum FetchState {
        case idle
        case fetching
        case fetched(FetchedWorkout)
        case error(InstagramFetchError)
    }

    var body: some View {
        Group {
            switch state {
            case .idle:
                idleView
            case .fetching:
                fetchingView
            case .fetched(let workout):
                successView(workout: workout)
            case .error(let error):
                errorView(error: error)
            }
        }
    }

    // MARK: - State Views

    private var idleView: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)

            Text("Ready to import")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Text("Enter Instagram URL and click Fetch")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var fetchingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Fetching from Instagram...")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("This may take a few seconds")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func successView(workout: FetchedWorkout) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Success badge
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Workout fetched successfully")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }

            // Preview card
            VStack(alignment: .leading, spacing: 12) {
                // Author info
                if let author = workout.author {
                    HStack(spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(.pink)
                        Text("@\(author.username)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Caption preview
                if !workout.content.isEmpty {
                    Text(workout.shortContent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                // Exercise count badge
                if workout.exerciseCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.caption2)
                        Text("\(workout.exerciseCount) exercises detected")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .cornerRadius(6)
                }
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(12)

            // Process & Edit button
            Button(action: { onProcessAndEdit(workout) }) {
                HStack {
                    Image(systemName: "square.and.pencil")
                    Text("Process & Edit")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
        }
    }

    private func errorView(error: InstagramFetchError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text(error.errorDescription ?? "An error occurred")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            if let recoverySuggestion = error.recoverySuggestion {
                Text(recoverySuggestion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if error.isRetryable {
                Button(action: onRetry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            if error.shouldShowUpgradePrompt {
                Button("View Subscription Plans") {
                    // TODO: Show paywall
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
    }
}

#Preview("Idle") {
    FetchStateView(
        state: .idle,
        onProcessAndEdit: { _ in },
        onRetry: { }
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Fetching") {
    FetchStateView(
        state: .fetching,
        onProcessAndEdit: { _ in },
        onRetry: { }
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Success") {
    let mockWorkout = FetchedWorkout(
        from: InstagramFetchResponse(
            url: "https://instagram.com/p/test",
            title: "Push Day",
            content: "Bench Press 4x8\nOverhead Press 3x10\nTricep Dips 3x12",
            author: AuthorInfo(username: "fitness_coach", fullName: "Fitness Coach"),
            stats: nil,
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
            title: "Push Day",
            workoutType: "standard",
            exercises: [
                ExerciseData(id: "1", name: "Bench Press", sets: 4, reps: "8", weight: nil, unit: "reps", notes: nil, restSeconds: nil),
                ExerciseData(id: "2", name: "Overhead Press", sets: 3, reps: "10", weight: nil, unit: "reps", notes: nil, restSeconds: nil),
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

    FetchStateView(
        state: .fetched(mockWorkout),
        onProcessAndEdit: { _ in print("Process & Edit") },
        onRetry: { }
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Error - Invalid URL") {
    FetchStateView(
        state: .error(.invalidURL),
        onProcessAndEdit: { _ in },
        onRetry: { print("Retry") }
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Error - Quota Exceeded") {
    FetchStateView(
        state: .error(.quotaExceeded(used: 10, limit: 10)),
        onProcessAndEdit: { _ in },
        onRetry: { }
    )
    .padding()
    .preferredColorScheme(.dark)
}
