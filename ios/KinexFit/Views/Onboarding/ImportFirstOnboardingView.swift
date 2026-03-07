import SwiftUI

/// Top-level container for the new import-first onboarding flow shown to unauthenticated users.
/// Replaces the existing 8-step OnboardingCoordinator for new (guest) users.
struct ImportFirstOnboardingView: View {
    let onCompleted: () -> Void
    let onSignInTapped: () -> Void

    @EnvironmentObject private var guestModeManager: GuestModeManager

    private enum Step {
        case importPrompt
        case quickProfile(importedWorkout: CaptionParsedWorkout?)
    }

    @State private var step: Step = .importPrompt
    @State private var onboardingStartTime = Date()

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .importPrompt:
                    ImportPromptStep(
                        onImportCompleted: { workout in
                            step = .quickProfile(importedWorkout: workout)
                        },
                        onSkip: {
                            OnboardingAnalytics.shared.track(.skipped(step: "import_prompt"))
                            step = .quickProfile(importedWorkout: nil)
                        }
                    )
                    .transition(.asymmetric(insertion: .opacity, removal: .opacity))

                case .quickProfile(let importedWorkout):
                    QuickProfileStep(
                        onComplete: { goal in
                            completeOnboarding(importedWorkout: importedWorkout, goal: goal)
                        }
                    )
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: stepTag)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign In") {
                        OnboardingAnalytics.shared.track(.signupPrompted(context: "onboarding_toolbar"))
                        OnboardingAnalytics.shared.track(.signupStarted(source: "onboarding_toolbar"))
                        onSignInTapped()
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .onAppear {
            onboardingStartTime = Date()
            OnboardingAnalytics.shared.track(.started(source: "direct"))
        }
    }

    // MARK: - Helpers

    private var stepTag: Int {
        switch step {
        case .importPrompt: return 0
        case .quickProfile: return 1
        }
    }

    private func completeOnboarding(importedWorkout: CaptionParsedWorkout?, goal: TrainingGoal?) {
        let timeTaken = Int(Date().timeIntervalSince(onboardingStartTime))
        OnboardingAnalytics.shared.track(
            .completed(importCompleted: importedWorkout != nil, timeTakenSeconds: timeTaken)
        )

        // Mark as seen so future launches skip this flow
        UserDefaults.standard.set(true, forKey: "hasSeenImportOnboarding")

        onCompleted()
    }
}
