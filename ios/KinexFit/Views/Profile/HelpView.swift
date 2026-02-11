import SwiftUI

struct HelpView: View {
    @State private var expandedSections: Set<String> = []

    var body: some View {
        List {
            // Getting Started Section
            Section("Getting Started") {
                FAQItem(
                    id: "add-workout",
                    question: "How do I add a workout?",
                    answer: "There are three ways to add workouts:\n\n1. Manual Entry: Tap the '+' tab and enter workout details manually.\n\n2. OCR Scan: Use the Scan tab to photograph workout screenshots or notes. The app will extract exercises automatically.\n\n3. Instagram Import: Share Instagram posts to Kinex Fit using the share button, and the app will parse the workout caption.",
                    expandedSections: $expandedSections
                )

                FAQItem(
                    id: "ocr-scan",
                    question: "How does OCR scanning work?",
                    answer: "OCR (Optical Character Recognition) uses your device's camera to scan workout photos or screenshots. The app extracts text from images and automatically creates a structured workout. For best results:\n\n• Use clear, well-lit photos\n• Avoid handwritten notes (typed text works best)\n• Make sure text is not blurry or tilted",
                    expandedSections: $expandedSections
                )

                FAQItem(
                    id: "ai-features",
                    question: "What are AI-powered features?",
                    answer: "Kinex Fit uses AI to:\n\n• Clean up messy OCR or Instagram text\n• Generate complete workouts based on your goals\n• Provide Workout of the Day and Workout of the Week recommendations\n\nAI features have usage quotas based on your subscription tier.",
                    expandedSections: $expandedSections
                )
            }

            // Subscription Section
            Section("Subscription & Billing") {
                FAQItem(
                    id: "upgrade-plan",
                    question: "How do I upgrade my subscription?",
                    answer: "To upgrade:\n\n1. Go to Profile tab\n2. Tap 'Upgrade to Pro' in the Subscription section\n3. Choose your preferred tier (Core, Pro, or Elite)\n4. Complete the purchase through the App Store\n\nYour new features will be available immediately after purchase.",
                    expandedSections: $expandedSections
                )

                FAQItem(
                    id: "cancel-subscription",
                    question: "How do I cancel my subscription?",
                    answer: "Subscriptions are managed through the App Store:\n\n1. Open iPhone Settings\n2. Tap your Apple ID at the top\n3. Tap 'Subscriptions'\n4. Select Kinex Fit\n5. Tap 'Cancel Subscription'\n\nYou'll retain access until the end of your billing period.",
                    expandedSections: $expandedSections
                )

                FAQItem(
                    id: "scan-limits",
                    question: "What are scan and AI quotas?",
                    answer: "Each subscription tier has monthly limits:\n\n• Free: 8 scans, 1 AI request\n• Core: 12 scans, 10 AI requests\n• Pro: 60 scans, 30 AI requests\n• Elite: 120 scans, 100 AI requests\n\nScans include both OCR and Instagram imports. Quotas reset monthly. Workout of the Week doesn't count toward AI limits.",
                    expandedSections: $expandedSections
                )
            }

            // Account Management Section
            Section("Account Management") {
                FAQItem(
                    id: "delete-account",
                    question: "How do I delete my account?",
                    answer: "To permanently delete your account:\n\n1. Go to Profile → Settings\n2. Scroll to 'Account' section\n3. Tap 'Delete Account'\n4. Type 'DELETE' to confirm\n\nWarning: This action cannot be undone. All your workouts, metrics, and data will be permanently deleted.",
                    expandedSections: $expandedSections
                )

                FAQItem(
                    id: "data-sync",
                    question: "How does data sync work?",
                    answer: "Kinex Fit uses offline-first sync:\n\n• All changes are saved locally first\n• When online, changes automatically sync to the cloud\n• You can use the app fully offline\n• Pull down to manually trigger sync\n\nIf there are conflicts (same workout edited on multiple devices), the most recent change wins.",
                    expandedSections: $expandedSections
                )
            }

            // Troubleshooting Section
            Section("Troubleshooting") {
                FAQItem(
                    id: "ocr-not-working",
                    question: "OCR isn't recognizing text",
                    answer: "Try these solutions:\n\n• Ensure good lighting when taking photos\n• Hold your device steady and avoid blur\n• Use typed text instead of handwriting\n• Make sure camera permissions are enabled (Settings → Kinex Fit → Camera)\n• Clean your camera lens",
                    expandedSections: $expandedSections
                )

                FAQItem(
                    id: "sync-issues",
                    question: "My data isn't syncing",
                    answer: "Check these items:\n\n• Ensure you have an internet connection\n• Pull down on the Workouts tab to manually sync\n• Check if sync indicator shows an error\n• Try signing out and signing back in\n\nIf issues persist, contact support.",
                    expandedSections: $expandedSections
                )
            }

            // Contact Support Section
            Section("Need More Help?") {
                Link(destination: URL(string: "mailto:support@kinexfit.com")!) {
                    HStack {
                        Label("Email Support", systemImage: "envelope.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Link(destination: URL(string: "https://kinexfit.com/support")!) {
                    HStack {
                        Label("Visit Support Center", systemImage: "lifepreserver.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - FAQ Item

struct FAQItem: View {
    let id: String
    let question: String
    let answer: String
    @Binding var expandedSections: Set<String>

    private var isExpanded: Bool {
        expandedSections.contains(id)
    }

    var body: some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { isExpanded },
                set: { newValue in
                    if newValue {
                        expandedSections.insert(id)
                    } else {
                        expandedSections.remove(id)
                    }
                }
            )
        ) {
            Text(answer)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        } label: {
            Text(question)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HelpView()
    }
}
