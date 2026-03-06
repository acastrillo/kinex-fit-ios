import Foundation
import UIKit
import OSLog
import AVFoundation

private let logger = Logger(subsystem: "com.kinex.fit", category: "TikTokImport")

/// Service for managing TikTok imports from the Share Extension
@MainActor
final class TikTokImportService: ObservableObject {
    @Published private(set) var pendingImports: [InstagramImport] = []
    @Published private(set) var isProcessing = false

    private let textExtractor = TextExtractionService()
    private let urlExpander = URLExpansionService()
    private let apiClient: APIClient

    var hasPendingImports: Bool { !pendingImports.isEmpty }
    var pendingCount: Int { pendingImports.count }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
        refreshPendingImports()
    }

    // MARK: - Import Management

    func refreshPendingImports() {
        let allImports = AppGroup.getPendingImports()
        pendingImports = allImports.filter {
            $0.sourcePlatform == .tiktok &&
            ($0.processingStatus == .pending ||
             $0.processingStatus == .processing ||
             $0.processingStatus == .completed)
        }
        logger.info("Found \(self.pendingImports.count) pending TikTok imports")
    }

    func getImport(id: String) -> InstagramImport? {
        pendingImports.first { $0.id == id }
    }

    /// Process a pending TikTok import — resolve short URL, extract text, parse
    func processImport(_ importItem: InstagramImport) async throws -> InstagramImport {
        logger.info("Processing TikTok import: \(importItem.id)")
        isProcessing = true
        defer { isProcessing = false }

        var processed = importItem
        processed.processingStatus = .processing
        AppGroup.updateImport(processed)

        do {
            // Step 1: Resolve short URL if needed
            if let postURL = processed.postURL {
                let resolved = await urlExpander.expand(postURL)
                if resolved != postURL {
                    processed = InstagramImport(
                        id: processed.id,
                        postURL: resolved,
                        captionText: processed.captionText,
                        mediaType: processed.mediaType,
                        mediaLocalPath: processed.mediaLocalPath,
                        createdAt: processed.createdAt,
                        processingStatus: processed.processingStatus,
                        extractedText: processed.extractedText,
                        sourcePlatform: processed.sourcePlatform
                    )
                }
            }

            // Step 2: Get text — caption first, then OCR fallback
            if let caption = importItem.captionText, !caption.isEmpty {
                processed.extractedText = caption
                logger.info("Using caption text for TikTok import")
            } else if let mediaURL = getMediaURL(for: importItem) {
                let extractedText: String
                switch importItem.mediaType {
                case .video:
                    extractedText = try await textExtractor.extractText(fromVideoAt: mediaURL)
                default:
                    extractedText = try await textExtractor.extractText(from: mediaURL)
                }
                processed.extractedText = extractedText
                logger.info("Extracted text from TikTok media (length: \(extractedText.count))")
            }

            processed.processingStatus = .completed
            AppGroup.updateImport(processed)
            refreshPendingImports()
            return processed

        } catch {
            logger.error("Failed to process TikTok import: \(error.localizedDescription)")
            processed.processingStatus = .failed
            AppGroup.updateImport(processed)
            refreshPendingImports()
            throw error
        }
    }

    func removeImport(_ importItem: InstagramImport) {
        AppGroup.removeImport(id: importItem.id)
        refreshPendingImports()
        logger.info("Removed TikTok import: \(importItem.id)")
    }

    func removeImport(id: String) {
        AppGroup.removeImport(id: id)
        refreshPendingImports()
    }

    func getMediaImage(for importItem: InstagramImport) -> UIImage? {
        guard let url = getMediaURL(for: importItem) else { return nil }
        if importItem.mediaType == .video {
            return generateVideoThumbnail(url: url)
        }
        return UIImage(contentsOfFile: url.path)
    }

    // MARK: - Helpers

    private func getMediaURL(for importItem: InstagramImport) -> URL? {
        guard let mediaDir = AppGroup.mediaDirectory else { return nil }
        let extensions = ["jpg", "jpeg", "png", "mp4", "mov"]
        for ext in extensions {
            let url = mediaDir.appendingPathComponent("\(importItem.id).\(ext)")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        if !importItem.mediaLocalPath.isEmpty {
            let url = mediaDir.appendingPathComponent(importItem.mediaLocalPath)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
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
