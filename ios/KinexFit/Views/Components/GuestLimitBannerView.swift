import SwiftUI

// MARK: - Inline warning strip (2/3 saves)

struct GuestSaveWarningBanner: View {
    let remainingSaves: Int
    let onSignUpTapped: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)

            Text("\(remainingSaves) save\(remainingSaves == 1 ? "" : "s") left — ")
                .font(.footnote)
                .foregroundStyle(AppTheme.primaryText)
            + Text("Sign up free")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.accent)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.12))
        .onTapGesture {
            OnboardingAnalytics.shared.track(.signupPrompted(context: "save_warning_banner"))
            onSignUpTapped()
        }
    }
}

// MARK: - Full limit modal (3/3 saves or 1/1 AI)

enum GuestLimitType {
    case workoutSave
    case aiGeneration

    var title: String {
        switch self {
        case .workoutSave: return "You've saved 3 workouts"
        case .aiGeneration: return "You've used your free AI workout"
        }
    }

    var message: String {
        switch self {
        case .workoutSave: return "Unlock unlimited saves — sign up free in 30 seconds."
        case .aiGeneration: return "Unlock unlimited AI workouts — sign up free in 30 seconds."
        }
    }

    var icon: String {
        switch self {
        case .workoutSave: return "tray.full.fill"
        case .aiGeneration: return "sparkles"
        }
    }

    var analyticsContext: String {
        switch self {
        case .workoutSave: return "guest_save_limit"
        case .aiGeneration: return "guest_ai_limit"
        }
    }
}

struct GuestLimitModal: View {
    let limitType: GuestLimitType
    let onSignUpTapped: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(AppTheme.secondaryText.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)

            Image(systemName: limitType.icon)
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.accent)

            VStack(spacing: 8) {
                Text(limitType.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.center)

                Text(limitType.message)
                    .font(.body)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button(action: {
                    OnboardingAnalytics.shared.track(.signupStarted(source: "guest_limit_modal"))
                    onSignUpTapped()
                }) {
                    Text("Sign Up Free")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button(action: {
                    let action = "dismissed"
                    switch limitType {
                    case .workoutSave:
                        OnboardingAnalytics.shared.track(.guestSaveLimitReached(action: action))
                    case .aiGeneration:
                        OnboardingAnalytics.shared.track(.guestAILimitReached(action: action))
                    }
                    onDismiss()
                }) {
                    Text("Maybe Later")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .onAppear {
            OnboardingAnalytics.shared.track(.signupPrompted(context: limitType.analyticsContext))
        }
    }
}

// MARK: - View modifier convenience

struct GuestLimitSheet: ViewModifier {
    @Binding var isPresented: Bool
    let limitType: GuestLimitType
    let onSignUpTapped: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                GuestLimitModal(
                    limitType: limitType,
                    onSignUpTapped: {
                        isPresented = false
                        onSignUpTapped()
                    },
                    onDismiss: {
                        isPresented = false
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
            }
    }
}

extension View {
    func guestLimitSheet(
        isPresented: Binding<Bool>,
        limitType: GuestLimitType,
        onSignUpTapped: @escaping () -> Void
    ) -> some View {
        modifier(GuestLimitSheet(isPresented: isPresented, limitType: limitType, onSignUpTapped: onSignUpTapped))
    }
}
