import SwiftUI

struct OCRResultView: View {
    let image: UIImage
    let ocrResponse: OCRResponse
    let onSave: (String, String?) async throws -> Void
    let onDiscard: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var title: String
    @State private var content: String
    @State private var isSaving = false
    @State private var showingRawText = false
    @State private var showingEnhancementResult = false
    @State private var enhancementResponse: EnhanceWorkoutResponse?
    @State private var error: Error?
    @State private var showingError = false

    init(
        image: UIImage,
        ocrResponse: OCRResponse,
        onSave: @escaping (String, String?) async throws -> Void,
        onDiscard: @escaping () -> Void
    ) {
        self.image = image
        self.ocrResponse = ocrResponse
        self.onSave = onSave
        self.onDiscard = onDiscard

        // Parse the OCR text
        let parsed = WorkoutTextParser.parse(ocrResponse.text)
        _title = State(initialValue: parsed.title)
        _content = State(initialValue: parsed.content)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Image preview
                    imagePreview

                    // Confidence indicator
                    if let confidence = ocrResponse.confidence {
                        confidenceIndicator(confidence: confidence)
                    }

                    // Quota info
                    if let used = ocrResponse.quotaUsed {
                        quotaInfo(used: used, limit: ocrResponse.quotaLimit)
                    }

                    // AI Enhancement button
                    EnhanceWithAIButton(text: ocrResponse.text) { response in
                        title = response.workout.title
                        content = response.workout.content
                        enhancementResponse = response
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // Editable workout fields
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Edit Workout Details")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            // Title field
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Title")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                TextField("Workout Title", text: $title)
                                    .textFieldStyle(.roundedBorder)
                            }

                            // Content field
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Exercises & Details")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                TextEditor(text: $content)
                                    .frame(minHeight: 200)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(.systemGray4), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Show raw text toggle
                    DisclosureGroup("View Raw OCR Text", isExpanded: $showingRawText) {
                        Text(ocrResponse.text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 100)
                }
                .padding(.vertical)
            }
            .navigationTitle("Review Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        onDiscard()
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(!isValid || isSaving)
                    .fontWeight(.semibold)
                }
            }
            .overlay {
                if isSaving {
                    savingOverlay
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(error?.localizedDescription ?? "Failed to save workout")
            }
        }
    }

    // MARK: - Image Preview

    private var imagePreview: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxHeight: 200)
            .cornerRadius(12)
            .shadow(radius: 4)
            .padding(.horizontal)
    }

    // MARK: - Confidence Indicator

    private func confidenceIndicator(confidence: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: confidenceIcon(for: confidence))
                .foregroundStyle(confidenceColor(for: confidence))

            Text("OCR Confidence: \(Int(confidence))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(confidenceColor(for: confidence).opacity(0.1))
        .cornerRadius(8)
    }

    private func confidenceIcon(for confidence: Double) -> String {
        if confidence >= 90 { return "checkmark.circle.fill" }
        if confidence >= 70 { return "exclamationmark.circle.fill" }
        return "xmark.circle.fill"
    }

    private func confidenceColor(for confidence: Double) -> Color {
        if confidence >= 90 { return .green }
        if confidence >= 70 { return .orange }
        return .red
    }

    // MARK: - Quota Info

    private func quotaInfo(used: Int, limit: Int?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text.viewfinder")
                .foregroundStyle(.secondary)

            if let limit = limit {
                Text("\(used)/\(limit) scans used this week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if ocrResponse.isUnlimited == true {
                Text("Unlimited scans")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Saving Overlay

    private var savingOverlay: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                Text("Saving workout...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func save() async {
        isSaving = true

        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedContent = content.trimmingCharacters(in: .whitespaces)

        do {
            try await onSave(trimmedTitle, trimmedContent.isEmpty ? nil : trimmedContent)
            dismiss()
        } catch {
            self.error = error
            showingError = true
        }

        isSaving = false
    }
}

// MARK: - Preview

#Preview {
    OCRResultView(
        image: UIImage(systemName: "photo")!,
        ocrResponse: OCRResponse(
            text: """
            Push Day Workout

            Bench Press
            4 sets x 8 reps @ 185 lbs

            Incline Dumbbell Press
            3 sets x 10 reps @ 60 lbs

            Cable Flyes
            3 sets x 12 reps
            """,
            confidence: 94.5,
            quotaUsed: 3,
            quotaLimit: 8,
            isUnlimited: false
        ),
        onSave: { _, _ in },
        onDiscard: { }
    )
}
