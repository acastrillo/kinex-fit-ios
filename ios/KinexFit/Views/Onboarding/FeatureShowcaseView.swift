import SwiftUI

// MARK: - Data Model

private struct FeaturePage {
    let icon: String
    let gradientColors: [Color]
    let title: String
    let subtitle: String
    let badge: String?
}

private let showcasePages: [FeaturePage] = [
    FeaturePage(
        icon: "arrow.down.doc.fill",
        gradientColors: [Color(red: 0.25, green: 0.55, blue: 1.0), Color(red: 0.55, green: 0.25, blue: 1.0)],
        title: "Import Any Workout",
        subtitle: "Paste an Instagram link, scan any photo with OCR, or type it in — Kinex Fit pulls out every exercise instantly.",
        badge: "Instagram • OCR • Manual"
    ),
    FeaturePage(
        icon: "stopwatch.fill",
        gradientColors: [Color(red: 1.0, green: 0.55, blue: 0.15), Color(red: 1.0, green: 0.25, blue: 0.35)],
        title: "Follow Along",
        subtitle: "Step through your workout set by set with a built-in timer. Rest timers keep you on pace so you can focus on lifting.",
        badge: "Set Tracker • Rest Timer"
    ),
    FeaturePage(
        icon: "chart.line.uptrend.xyaxis",
        gradientColors: [Color(red: 0.15, green: 0.80, blue: 0.55), Color(red: 0.10, green: 0.60, blue: 0.90)],
        title: "Track Your Progress",
        subtitle: "Every set you log builds your personal records and progress charts. Watch your strength compound over time.",
        badge: "PRs • Charts • History"
    ),
    FeaturePage(
        icon: "wand.and.stars",
        gradientColors: [Color(red: 1.0, green: 0.42, blue: 0.21), Color(red: 1.0, green: 0.20, blue: 0.60)],
        title: "Powered by AI",
        subtitle: "Clean up messy imports in one tap and generate personalized workout programs tailored to your goals and schedule.",
        badge: "Smart Cleanup • Custom Programs"
    )
]

// MARK: - Main View

struct FeatureShowcaseView: View {
    let onGetStarted: () -> Void

    @State private var currentPage = 0
    @State private var iconScale: CGFloat = 1.0
    @State private var iconOpacity: Double = 1.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Paged content
                TabView(selection: $currentPage) {
                    ForEach(Array(showcasePages.enumerated()), id: \.offset) { index, page in
                        FeaturePageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Bottom controls
                bottomControls
            }
            .background(AppTheme.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign In") {
                        onGetStarted()
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 24) {
            // Page dots
            HStack(spacing: 7) {
                ForEach(0..<showcasePages.count, id: \.self) { index in
                    Capsule()
                        .fill(currentPage == index ? AppTheme.accent : AppTheme.secondaryText.opacity(0.3))
                        .frame(width: currentPage == index ? 24 : 8, height: 8)
                        .animation(.spring(duration: 0.35), value: currentPage)
                }
            }

            // CTA
            Button(action: advancePage) {
                Text(currentPage < showcasePages.count - 1 ? "Next" : "Get Started")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .animation(.none, value: currentPage)
        }
        .padding(.top, 16)
        .padding(.bottom, 44)
    }

    // MARK: - Helpers

    private func advancePage() {
        if currentPage < showcasePages.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage += 1
            }
        } else {
            onGetStarted()
        }
    }
}

// MARK: - Feature Page

private struct FeaturePageView: View {
    let page: FeaturePage

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [page.gradientColors[0].opacity(0.25), .clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)

                // Icon background circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: page.gradientColors.map { $0.opacity(0.18) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: page.gradientColors.map { $0.opacity(0.4) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .frame(width: 130, height: 130)

                // Icon
                Image(systemName: page.icon)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: page.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(appeared ? 1.0 : 0.75)
            .opacity(appeared ? 1.0 : 0.0)

            Spacer().frame(height: 40)

            // Badge
            if let badge = page.badge {
                Text(badge)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(page.gradientColors[0])
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(page.gradientColors[0].opacity(0.12))
                    .clipShape(Capsule())
                    .offset(y: appeared ? 0 : 10)
                    .opacity(appeared ? 1.0 : 0.0)
            }

            Spacer().frame(height: 20)

            // Text
            VStack(spacing: 14) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 32)
            .offset(y: appeared ? 0 : 20)
            .opacity(appeared ? 1.0 : 0.0)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(duration: 0.55, bounce: 0.35)) {
                appeared = true
            }
        }
        .onDisappear {
            appeared = false
        }
    }
}

// MARK: - Preview

#Preview {
    FeatureShowcaseView(onGetStarted: {})
        .environmentObject(AppState(environment: .preview))
}
