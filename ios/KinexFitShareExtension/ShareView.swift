import SwiftUI
import UniformTypeIdentifiers
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit.share-extension", category: "ShareView")

struct ShareView: View {
    let extensionContext: NSExtensionContext?
    let onComplete: () -> Void
    let onCancel: () -> Void

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?
    @State private var previewImage: UIImage?
    @State private var captionText: String?
    @State private var postURL: String?
    @State private var mediaType: String = "unknown"

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isLoading {
                    loadingView
                } else if let errorMessage = error {
                    errorView(message: errorMessage)
                } else {
                    contentView
                }
            }
            .padding()
            .navigationTitle("Save to Kinex Fit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveImport() }
                    }
                    .disabled(isLoading || isSaving)
                    .fontWeight(.semibold)
                }
            }
        }
        .task {
            await extractContent()
        }
    }

    // MARK: - Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading content...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Unable to Import")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task { await extractContent() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contentView: some View {
        VStack(spacing: 20) {
            // Preview
            if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .cornerRadius(12)
                    .shadow(radius: 4)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 150)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: mediaType == "video" ? "video" : "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text(mediaType.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            }

            // Info
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "camera.on.rectangle")
                        .foregroundStyle(.pink)
                    Text("Instagram Import")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                }

                if let caption = captionText, !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(12)

            // Saving indicator
            if isSaving {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Saving...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Instructions
            Text("The workout will be available in Kinex Fit for review")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Content Extraction

    private func extractContent() async {
        isLoading = true
        error = nil

        guard let extensionContext = extensionContext,
              let inputItems = extensionContext.inputItems as? [NSExtensionItem] else {
            error = "No content to import"
            isLoading = false
            return
        }

        for item in inputItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                // Try to get URL first (Instagram often shares URLs)
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                        postURL = url.absoluteString
                        logger.info("Found URL: \(url.absoluteString)")
                    }
                }

                // Try to get text (caption)
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                        captionText = text
                        logger.info("Found text: \(text.prefix(100))...")
                    }
                }

                // Try to get image
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    mediaType = "image"
                    if let imageData = try? await loadImageData(from: provider) {
                        previewImage = UIImage(data: imageData)
                        logger.info("Found image: \(imageData.count) bytes")
                    }
                }

                // Try to get video
                if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    mediaType = "video"
                    logger.info("Found video attachment")
                    // For video, we'll save the URL and process later
                }
            }
        }

        if postURL == nil && captionText == nil && previewImage == nil {
            error = "No supported content found. Try sharing an image or post."
        }

        isLoading = false
    }

    private func loadImageData(from provider: NSItemProvider) async throws -> Data? {
        return try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.image.identifier) { item, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                var imageData: Data?

                if let url = item as? URL {
                    imageData = try? Data(contentsOf: url)
                } else if let image = item as? UIImage {
                    imageData = image.jpegData(compressionQuality: 0.85)
                } else if let data = item as? Data {
                    imageData = data
                }

                continuation.resume(returning: imageData)
            }
        }
    }

    // MARK: - Save Import

    private func saveImport() async {
        isSaving = true

        let importId = UUID().uuidString
        var mediaPath = ""

        // Save image if available
        if let image = previewImage,
           let imageData = image.jpegData(compressionQuality: 0.85),
           let mediaDir = AppGroupShared.mediaDirectory {

            let fileName = "\(importId).jpg"
            let fileURL = mediaDir.appendingPathComponent(fileName)

            do {
                try imageData.write(to: fileURL)
                mediaPath = fileName
                logger.info("Saved image to: \(fileURL.path)")
            } catch {
                logger.error("Failed to save image: \(error.localizedDescription)")
            }
        }

        // Create import record
        let importItem = InstagramImportShared(
            id: importId,
            postURL: postURL,
            captionText: captionText,
            mediaType: mediaType,
            mediaLocalPath: mediaPath
        )

        // Save to App Group
        InstagramImportShared.saveToAppGroup(importItem)
        logger.info("Saved import to App Group: \(importId)")

        isSaving = false
        onComplete()
    }
}

// MARK: - Preview

#Preview {
    ShareView(
        extensionContext: nil,
        onComplete: { },
        onCancel: { }
    )
}
