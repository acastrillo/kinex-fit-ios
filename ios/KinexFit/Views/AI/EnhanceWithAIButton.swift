import SwiftUI

/// Button to enhance a workout with AI
struct EnhanceWithAIButton: View {
    let text: String
    let onEnhanced: (EnhanceWorkoutResponse) -> Void

    @EnvironmentObject private var appState: AppState
    @State private var isEnhancing = false
    @State private var error: AIError?
    @State private var showingError = false
    @State private var quota: AIQuota?

    private var aiService: AIService {
        AIService(apiClient: appState.environment.apiClient)
    }

    private var isDisabled: Bool {
        isEnhancing || (quota?.isExhausted ?? false)
    }

    var body: some View {
        Button {
            Task { await enhance() }
        } label: {
            HStack(spacing: 8) {
                if isEnhancing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(isEnhancing ? "Enhancing..." : "Enhance with AI")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.purple)
        .disabled(isDisabled)
        .opacity(isDisabled && !isEnhancing ? 0.6 : 1)
        .alert("Enhancement Failed", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(error?.localizedDescription ?? "Unknown error")
        }
        .task {
            await loadQuota()
        }
    }

    private func loadQuota() async {
        if let q = try? await aiService.getQuota() {
            quota = q
            try? await appState.environment.userRepository.updateAIQuota(used: q.used, limit: q.limit)
        }
    }

    private func enhance() async {
        isEnhancing = true

        do {
            let response = try await aiService.enhanceWorkout(text: text)
            if let remaining = response.quotaRemaining {
                try? await appState.environment.userRepository.updateAIQuotaFromRemaining(remaining)
            }
            await MainActor.run {
                onEnhanced(response)
            }
        } catch let aiError as AIError {
            await MainActor.run {
                error = aiError
                showingError = true
            }
        } catch {
            await MainActor.run {
                self.error = .networkError(error)
                showingError = true
            }
        }

        isEnhancing = false
    }
}

/// Compact version for inline use
struct EnhanceWithAIButtonCompact: View {
    let text: String
    let onEnhanced: (EnhanceWorkoutResponse) -> Void

    @EnvironmentObject private var appState: AppState
    @State private var isEnhancing = false
    @State private var error: AIError?
    @State private var showingError = false

    private var aiService: AIService {
        AIService(apiClient: appState.environment.apiClient)
    }

    var body: some View {
        Button {
            Task { await enhance() }
        } label: {
            HStack(spacing: 4) {
                if isEnhancing {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "sparkles")
                }
                Text("AI")
            }
            .font(.caption)
            .fontWeight(.medium)
        }
        .buttonStyle(.bordered)
        .tint(.purple)
        .disabled(isEnhancing)
        .alert("Enhancement Failed", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(error?.localizedDescription ?? "Unknown error")
        }
    }

    private func enhance() async {
        isEnhancing = true

        do {
            let response = try await AIService(apiClient: appState.environment.apiClient)
                .enhanceWorkout(text: text)
            if let remaining = response.quotaRemaining {
                try? await appState.environment.userRepository.updateAIQuotaFromRemaining(remaining)
            }
            await MainActor.run {
                onEnhanced(response)
            }
        } catch let aiError as AIError {
            await MainActor.run {
                error = aiError
                showingError = true
            }
        } catch {
            await MainActor.run {
                self.error = .networkError(error)
                showingError = true
            }
        }

        isEnhancing = false
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        EnhanceWithAIButton(
            text: "Bench Press 4x8\nSquats 3x10",
            onEnhanced: { _ in }
        )

        EnhanceWithAIButtonCompact(
            text: "Bench Press 4x8",
            onEnhanced: { _ in }
        )
    }
    .padding()
    .environmentObject(AppState(environment: .preview))
}
