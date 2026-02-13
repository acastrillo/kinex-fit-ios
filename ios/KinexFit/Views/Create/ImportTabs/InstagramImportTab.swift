import SwiftUI

/// Instagram URL import tab with fetch and parse functionality
struct InstagramImportTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var instagramURL: String = ""
    @State private var fetchState: FetchStateView.FetchState = .idle
    @State private var showingError = false
    @State private var errorMessage: String = ""

    private var instagramFetchService: InstagramFetchService {
        InstagramFetchService(apiClient: appState.environment.apiClient)
    }

    private var isValidURL: Bool {
        instagramFetchService.isValidInstagramURL(instagramURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // URL Input Section
            VStack(alignment: .leading, spacing: 8) {
                Label("Source URL", systemImage: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    TextField("https://www.instagram.com/p/...", text: $instagramURL)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .disabled(isFetching)

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
                    .buttonStyle(.borderedProminent)
                    .disabled(!canFetch)
                }

                Text("Paste Instagram, TikTok, or other workout URLs")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Fetch State Display
            FetchStateView(
                state: fetchState,
                onProcessAndEdit: processAndEdit,
                onRetry: fetchWorkout
            )

            Spacer()

            // Quota Indicator (if available)
            if let workout = fetchedWorkout,
               workout.hasQuotaInfo,
               let used = workout.quotaUsed,
               let limit = workout.quotaLimit {
                InstagramQuotaIndicator(used: used, limit: limit) {
                    // TODO: Show subscription/upgrade screen
                    print("Show upgrade screen")
                }
            }
        }
        .padding()
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
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

        fetchState = .fetching

        Task {
            do {
                let workout = try await instagramFetchService.fetchAndParse(url: instagramURL)
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
}

#Preview {
    NavigationStack {
        InstagramImportTab()
            .environmentObject(AppState(environment: .preview))
    }
    .preferredColorScheme(.dark)
}
