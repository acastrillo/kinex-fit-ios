import SwiftUI

/// Displays different states for Instagram fetch operation
struct FetchStateView: View {
    let state: FetchState
    let onProcessAndEdit: (FetchedWorkout) -> Void
    let onRetry: () -> Void
    let onShowPaywall: (() -> Void)?
    let onReauthenticate: (() -> Void)?

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
                .foregroundStyle(AppTheme.accent)

            Text("Ready to import")
                .font(.system(size: 20, weight: .semibold))
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.primaryText)

            Text("Enter a workout URL and tap Fetch")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 12)
        .kinexCard(cornerRadius: 14, fill: AppTheme.background)
    }

    private var fetchingView: some View {
        FetchingProgressCard()
    }

    private func successView(workout: FetchedWorkout) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Success badge
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Workout fetched successfully")
                    .font(.system(size: 18, weight: .semibold))
                    .fontWeight(.medium)
                    .foregroundStyle(AppTheme.primaryText)
            }

            // Preview card
            VStack(alignment: .leading, spacing: 12) {
                // Author info
                if let author = workout.author {
                    HStack(spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(.pink)
                        Text("@\(author.username)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }

                // Caption preview
                if !workout.content.isEmpty {
                    Text(workout.shortContent)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(3)
                }

                // Exercise count badge
                if workout.exerciseCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.caption2)
                        Text("\(workout.exerciseCount) exercises detected")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .cornerRadius(6)
                }
            }
            .padding()
            .kinexCard(cornerRadius: 12, fill: AppTheme.cardBackgroundElevated)

            // Process & Edit button
            Button(action: { onProcessAndEdit(workout) }) {
                HStack {
                    Image(systemName: "square.and.pencil")
                    Text("Process & Edit")
                }
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .kinexCard(cornerRadius: 14, fill: AppTheme.background)
    }

    private func errorView(error: InstagramFetchError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.warning)

            Text(error.errorDescription ?? "An error occurred")
                .font(.system(size: 17, weight: .semibold))
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.primaryText)
                .multilineTextAlignment(.center)

            if let recoverySuggestion = error.recoverySuggestion {
                Text(recoverySuggestion)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if error.isRetryable {
                Button(action: onRetry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppTheme.cardBackgroundElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if case .unauthorized = error {
                Button(action: { onReauthenticate?() }) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                        Text("Sign In Again")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppTheme.cardBackgroundElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if error.shouldShowUpgradePrompt {
                Button("View Subscription Plans") {
                    onShowPaywall?()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 20)
        .kinexCard(cornerRadius: 14, fill: AppTheme.background)
    }
}

// MARK: - Fetching Progress Card

private struct FetchingProgressCard: View {
    @State private var currentStep = 0

    private let steps: [(String, String)] = [
        ("network", "Connecting to source"),
        ("doc.text.magnifyingglass", "Fetching workout"),
        ("list.bullet.clipboard", "Parsing exercises"),
    ]

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: steps[currentStep].0)
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.accent)
                .symbolEffect(.pulse, options: .repeating)
                .animation(.easeInOut(duration: 0.3), value: currentStep)

            Text("Fetching workout...")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)

            VStack(spacing: 12) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 10) {
                        Group {
                            if index < currentStep {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else if index == currentStep {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(AppTheme.accent)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(AppTheme.tertiaryText)
                            }
                        }
                        .frame(width: 20)

                        Text(step.1)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(index <= currentStep ? AppTheme.primaryText : AppTheme.tertiaryText)

                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .kinexCard(cornerRadius: 14, fill: AppTheme.background)
        .task {
            for i in 1..<steps.count {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                withAnimation(.easeInOut(duration: 0.4)) {
                    currentStep = i
                }
            }
        }
    }
}

#Preview("Fetching Progress") {
    FetchingProgressCard()
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Idle") {
    FetchStateView(
        state: .idle,
        onProcessAndEdit: { _ in },
        onRetry: { },
        onShowPaywall: nil,
        onReauthenticate: nil
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Fetching") {
    FetchStateView(
        state: .fetching,
        onProcessAndEdit: { _ in },
        onRetry: { },
        onShowPaywall: nil,
        onReauthenticate: nil
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
        onProcessAndEdit: { _ in },
        onRetry: { },
        onShowPaywall: nil,
        onReauthenticate: nil
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Error - Invalid URL") {
    FetchStateView(
        state: .error(.invalidURL),
        onProcessAndEdit: { _ in },
        onRetry: { },
        onShowPaywall: nil,
        onReauthenticate: nil
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Error - Quota Exceeded") {
    FetchStateView(
        state: .error(.quotaExceeded(used: 10, limit: 10)),
        onProcessAndEdit: { _ in },
        onRetry: { },
        onShowPaywall: { },
        onReauthenticate: nil
    )
    .padding()
    .preferredColorScheme(.dark)
}
