import SwiftUI

/// View for generating workouts from natural language prompts
struct WorkoutGeneratorView: View {
    let onWorkoutGenerated: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var prompt = ""
    @State private var isGenerating = false
    @State private var generatedResponse: GenerateWorkoutResponse?
    @State private var error: AIError?
    @State private var showingError = false
    @State private var quota: AIQuota?

    @FocusState private var isPromptFocused: Bool

    private var aiService: AIService {
        AIService(apiClient: appState.environment.apiClient)
    }

    private var canGenerate: Bool {
        !prompt.trimmingCharacters(in: .whitespaces).isEmpty &&
        !isGenerating &&
        !(quota?.isExhausted ?? false)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        headerSection

                        // Prompt input
                        promptInputSection

                        // Example prompts
                        if prompt.isEmpty {
                            examplePromptsSection
                        }

                        // Generated result
                        if let response = generatedResponse {
                            generatedResultSection(response)
                        }
                    }
                    .padding()
                }

                // Bottom action bar
                if generatedResponse == nil {
                    generateButton
                }
            }
            .navigationTitle("Generate Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if generatedResponse != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Use This") {
                            if let response = generatedResponse {
                                onWorkoutGenerated(
                                    response.workout.title,
                                    response.workout.content
                                )
                                dismiss()
                            }
                        }
                        .fontWeight(.semibold)
                    }
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            isPromptFocused = false
                        }
                    }
                }
            }
            .alert("Generation Failed", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(error?.localizedDescription ?? "Unknown error")
            }
        }
        .task {
            quota = try? await aiService.getQuota()
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.purple)

                Text("AI Workout Generator")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Text("Describe the workout you want and AI will create it for you")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Quota indicator
            if let quota = quota {
                AIQuotaBadge(quota: quota)
            }
        }
    }

    private var promptInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What kind of workout?")
                .font(.headline)

            TextEditor(text: $prompt)
                .focused($isPromptFocused)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .overlay(alignment: .topLeading) {
                    if prompt.isEmpty {
                        Text("e.g., 30 minute upper body with dumbbells only...")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 16)
                            .padding(.leading, 12)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var examplePromptsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try these examples")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(examplePrompts, id: \.self) { example in
                Button {
                    prompt = example
                } label: {
                    HStack {
                        Text(example)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "arrow.right.circle")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func generatedResultSection(_ response: GenerateWorkoutResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Workout Generated")
                    .font(.headline)

                Spacer()

                Button("Regenerate") {
                    generatedResponse = nil
                }
                .font(.caption)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(response.workout.title)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(response.workout.content)
                    .font(.body)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)

            // Rationale
            if let rationale = response.rationale {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Why this workout?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(rationale)
                        .font(.caption)
                }
            }

            // Timer suggestion
            if let timer = response.timerSuggestion, timer.type != .none {
                HStack {
                    Image(systemName: timer.type.icon)
                        .foregroundStyle(.orange)
                    Text("Suggested: \(timer.type.displayName)")
                        .font(.caption)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    private var generateButton: some View {
        VStack(spacing: 8) {
            Button {
                Task { await generate() }
            } label: {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isGenerating ? "Generating..." : "Generate Workout")
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(!canGenerate)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Actions

    private func generate() async {
        isPromptFocused = false
        isGenerating = true

        do {
            let response = try await aiService.generateWorkout(prompt: prompt)
            await MainActor.run {
                generatedResponse = response
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

        isGenerating = false
    }

    // MARK: - Data

    private let examplePrompts = [
        "30 minute full body workout with no equipment",
        "Leg day focusing on squats and deadlifts, intermediate level",
        "Quick 15 minute HIIT for cardio",
        "Upper body push workout with dumbbells, 45 minutes"
    ]
}

// MARK: - Preview

#Preview {
    WorkoutGeneratorView { title, content in
        print("Generated: \(title)")
    }
    .environmentObject(AppState(environment: .preview))
}
