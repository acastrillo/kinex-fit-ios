import Foundation
import UIKit
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "InstagramImport")

/// Service for managing Instagram imports from Share Extension
@MainActor
final class InstagramImportService: ObservableObject {
    @Published private(set) var pendingImports: [InstagramImport] = []
    @Published private(set) var isProcessing = false

    private let textExtractor = TextExtractionService()

    var hasPendingImports: Bool {
        !pendingImports.isEmpty
    }

    var pendingCount: Int {
        pendingImports.count
    }

    // MARK: - Initialization

    init() {
        // Check for imports on init
        refreshPendingImports()
    }

    // MARK: - Import Management

    /// Refresh the list of pending imports from App Group
    func refreshPendingImports() {
        pendingImports = AppGroup.getPendingImports()
            .filter { $0.processingStatus == .pending || $0.processingStatus == .processing }
        logger.info("Found \(self.pendingImports.count) pending imports")
    }

    /// Get a specific import by ID
    func getImport(id: String) -> InstagramImport? {
        pendingImports.first { $0.id == id }
    }

    /// Process a pending import - extract text from media
    func processImport(_ importItem: InstagramImport) async throws -> InstagramImport {
        logger.info("Processing import: \(importItem.id)")
        isProcessing = true
        defer { isProcessing = false }

        var processed = importItem
        processed.processingStatus = .processing

        // Update status in App Group
        updateImportInAppGroup(processed)

        do {
            // If we have caption text, use that
            if let caption = importItem.captionText, !caption.isEmpty {
                processed.extractedText = caption
                logger.info("Using caption text for import")
            }
            // Otherwise, try to extract from media
            else if let mediaURL = getMediaURL(for: importItem) {
                let extractedText: String

                switch importItem.mediaType {
                case .image:
                    extractedText = try await textExtractor.extractText(from: mediaURL)
                case .video:
                    extractedText = try await textExtractor.extractText(fromVideoAt: mediaURL)
                default:
                    // Try image extraction as fallback
                    extractedText = try await textExtractor.extractText(from: mediaURL)
                }

                processed.extractedText = extractedText
                logger.info("Extracted text from media (length: \(extractedText.count))")
            }

            processed.processingStatus = .completed
            updateImportInAppGroup(processed)
            refreshPendingImports()

            return processed

        } catch {
            logger.error("Failed to process import: \(error.localizedDescription)")
            processed.processingStatus = .failed
            updateImportInAppGroup(processed)
            refreshPendingImports()
            throw error
        }
    }

    /// Remove a processed import
    func removeImport(_ importItem: InstagramImport) {
        AppGroup.removeImport(id: importItem.id)
        refreshPendingImports()
        logger.info("Removed import: \(importItem.id)")
    }

    /// Remove import by ID
    func removeImport(id: String) {
        AppGroup.removeImport(id: id)
        refreshPendingImports()
    }

    /// Clear all pending imports
    func clearAllImports() {
        AppGroup.clearAllImports()
        refreshPendingImports()
        logger.info("Cleared all imports")
    }

    // MARK: - Helpers

    private func getMediaURL(for importItem: InstagramImport) -> URL? {
        guard let mediaDir = AppGroup.mediaDirectory else { return nil }

        // Try common extensions
        let extensions = ["jpg", "jpeg", "png", "mp4", "mov"]
        for ext in extensions {
            let url = mediaDir.appendingPathComponent("\(importItem.id).\(ext)")
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // Try the stored path
        if !importItem.mediaLocalPath.isEmpty {
            let url = mediaDir.appendingPathComponent(importItem.mediaLocalPath)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        return nil
    }

    private func updateImportInAppGroup(_ importItem: InstagramImport) {
        var imports = AppGroup.getPendingImports()
        if let index = imports.firstIndex(where: { $0.id == importItem.id }) {
            imports[index] = importItem
        }
        AppGroup.savePendingImports(imports)
    }

    /// Get the media image for display (if available)
    func getMediaImage(for importItem: InstagramImport) -> UIImage? {
        guard let url = getMediaURL(for: importItem) else { return nil }

        if importItem.mediaType == .video {
            // Generate thumbnail for video
            return generateVideoThumbnail(url: url)
        } else {
            return UIImage(contentsOfFile: url.path)
        }
    }

    private func generateVideoThumbnail(url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}

import AVFoundation
