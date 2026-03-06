import SwiftUI

/// Social media URL import tab — supports Instagram and TikTok
struct SocialImportTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var instagramURL: String = ""
    @State private var fetchState: FetchStateView.FetchState = .idle
    @State private var showPaywall = false
    @State private var showTikTokComingSoonAlert = false

    private var instagramFetchService: InstagramFetchService {
        InstagramFetchService(apiClient: appState.environment.apiClient)
    }

    private var isValidURL: Bool {
        instagramFetchService.isValidSocialURL(instagramURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Source URL")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)

                HStack(spacing: 12) {
                    TextField("instagram.com/p/... or tiktok.com/@...", text: $instagramURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .disabled(isFetching)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(AppTheme.cardBackgroundElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        }
                        .foregroundStyle(AppTheme.primaryText)

                    Button(action: fetchWorkout) {
                        if isFetching {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        } else {
                            Text("Fetch")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(AppTheme.accent.opacity(canFetch ? 1 : 0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .disabled(!canFetch)
                }

                Text("Paste Instagram, TikTok, or other workout URLs")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            FetchStateView(
                state: fetchState,
                onProcessAndEdit: processAndEdit,
                onRetry: fetchWorkout,
                onShowPaywall: { showPaywall = true },
                onReauthenticate: handleReauthentication
            )

            Spacer()

            // Quota Indicator (if available)
            if let workout = fetchedWorkout,
               workout.hasQuotaInfo,
               let used = workout.quotaUsed,
               let limit = workout.quotaLimit {
                InstagramQuotaIndicator(used: used, limit: limit) {
                    showPaywall = true
                }
            }
        }
        .padding(2)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert("TikTok Coming Soon", isPresented: $showTikTokComingSoonAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Coming soon! Try an Instagram link or a screenshot.")
        }
    }

    // MARK: - Computed Properties

    private var isFetching: Bool {
        if case .fetching = fetchState {
            return true
        }
        return false
    }

    private var canFetch: Bool {
        isValidURL && !isFetching
    }

    private var fetchedWorkout: FetchedWorkout? {
        if case .fetched(let workout) = fetchState {
            return workout
        }
        return nil
    }

    // MARK: - Actions

    private func fetchWorkout() {
        guard isValidURL else {
            fetchState = .error(.invalidURL)
            return
        }

        let normalizedURL = instagramURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if SocialPlatform.detect(from: normalizedURL) == .tiktok {
            fetchState = .idle
            showTikTokComingSoonAlert = true
            return
        }

        fetchState = .fetching

        Task {
            do {
                let workout = try await instagramFetchService.fetchAndParse(url: instagramURL)

                // Persist server-reported scan quota to local user
                if let used = workout.quotaUsed, let limit = workout.quotaLimit {
                    try? await appState.environment.userRepository.updateScanQuota(used: used, limit: limit)
                }

                await MainActor.run {
                    fetchState = .fetched(workout)
                }
            } catch let error as InstagramFetchError {
                await MainActor.run {
                    fetchState = .error(error)
                }
            } catch {
                await MainActor.run {
                    fetchState = .error(.networkError(error))
                }
            }
        }
    }

    private func processAndEdit(_ workout: FetchedWorkout) {
        appState.navigateToInstagramEdit(workout)
    }

    private func handleReauthentication() {
        fetchState = .idle
        NotificationCenter.default.post(name: .authSessionInvalidated, object: nil)
    }
}

#Preview {
    NavigationStack {
        SocialImportTab()
            .environmentObject(AppState(environment: .preview))
    }
    .preferredColorScheme(.dark)
}
