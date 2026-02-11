import SwiftUI
import UserNotifications

struct NotificationPermissionView: View {
    @EnvironmentObject private var notificationManager: NotificationManager
    @Environment(\.dismiss) private var dismiss

    @State private var isRequesting = false

    let onComplete: (Bool) -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Content
            VStack(spacing: 16) {
                Text("Stay On Track")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Get reminders for your scheduled workouts and track your progress")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Benefits
            VStack(alignment: .leading, spacing: 16) {
                BenefitRow(
                    icon: "clock.fill",
                    text: "Workout reminders at your preferred times"
                )

                BenefitRow(
                    icon: "flame.fill",
                    text: "Streak notifications to keep you motivated"
                )

                BenefitRow(
                    icon: "chart.line.uptrend.xyaxis",
                    text: "Weekly progress summaries"
                )

                BenefitRow(
                    icon: "sparkles",
                    text: "AI-powered workout suggestions"
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground).opacity(0.8))
            )
            .padding(.horizontal)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button {
                    Task {
                        await requestPermission()
                    }
                } label: {
                    HStack {
                        if isRequesting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Enable Notifications")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isRequesting)

                Button {
                    onComplete(false)
                } label: {
                    Text("Maybe Later")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    private func requestPermission() async {
        isRequesting = true
        defer { isRequesting = false }

        do {
            let granted = try await notificationManager.requestPermission()
            onComplete(granted)
        } catch {
            onComplete(false)
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

#Preview {
    NotificationPermissionView(onComplete: { _ in })
        .environmentObject(NotificationManager.preview)
}
