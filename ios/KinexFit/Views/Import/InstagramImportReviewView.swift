import SwiftUI

struct InstagramImportReviewView: View {
    let importItem: InstagramImport
    let onSave: (String, String?) async throws -> Void
    let onDiscard: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var mediaImage: UIImage?
    @State private var isProcessing = false
    @State private var isSaving = false
    @State private var error: Error?
    @State private var showingError = false
    @State private var showingRawText = false

    private var importService: InstagramImportService {
        appState.instagramImportService
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Media preview
                    if let image = mediaImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                    } else {
                        placeholderImage
                    }

                    // Source info
                    sourceInfoSection

                    if isProcessing {
                        processingView
                    } else {
                        // Editable fields
                        editableFieldsSection

                        // Raw text disclosure
                        if let extractedText = importItem.extractedText, !extractedText.isEmpty {
                            rawTextSection(text: extractedText)
                        }
                    }

                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Import from Instagram")
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
                    .disabled(!isValid || isSaving || isProcessing)
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
                Text(error?.localizedDescription ?? "An error occurred")
            }
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Subviews

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemBackground))
            .frame(height: 150)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No preview available")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
    }

    private var sourceInfoSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.on.rectangle")
                .foregroundStyle(.pink)

            VStack(alignment: .leading, spacing: 2) {
                Text("Instagram Import")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let url = importItem.postURL {
                    Text(url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(importItem.mediaType.rawValue.capitalized)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(4)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }

    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Extracting text from media...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var editableFieldsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Workout Details")
                .font(.headline)

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Title")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Workout Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

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
        }
    }

    private func rawTextSection(text: String) -> some View {
        DisclosureGroup("View Extracted Text", isExpanded: $showingRawText) {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
        }
    }

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

    // MARK: - Data Loading

    private func loadData() async {
        // Load media image
        mediaImage = importService.getMediaImage(for: importItem)

        // Process import if not already done
        if importItem.extractedText == nil && importItem.processingStatus == .pending {
            isProcessing = true
            do {
                let processed = try await importService.processImport(importItem)
                await MainActor.run {
                    parseExtractedText(processed.extractedText)
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    showingError = true
                    isProcessing = false
                    // Use caption or empty
                    parseExtractedText(importItem.captionText)
                }
            }
        } else {
            // Use already extracted text
            parseExtractedText(importItem.extractedText ?? importItem.captionText)
        }
    }

    private func parseExtractedText(_ text: String?) {
        guard let text = text, !text.isEmpty else {
            title = "Instagram Workout"
            content = ""
            return
        }

        let parsed = WorkoutTextParser.parse(text)
        title = parsed.title
        content = parsed.content
    }

    // MARK: - Actions

    private func save() async {
        isSaving = true

        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedContent = content.trimmingCharacters(in: .whitespaces)

        do {
            try await onSave(trimmedTitle, trimmedContent.isEmpty ? nil : trimmedContent)
            importService.removeImport(importItem)
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
    InstagramImportReviewView(
        importItem: InstagramImport(
            postURL: "https://instagram.com/p/abc123",
            captionText: "Push Day\n\nBench Press 4x8\nOverhead Press 3x10",
            mediaType: .image,
            mediaLocalPath: "test.jpg",
            extractedText: "Push Day\n\nBench Press 4x8\nOverhead Press 3x10"
        ),
        onSave: { _, _ in },
        onDiscard: { }
    )
    .environmentObject(AppState(environment: .preview))
}
