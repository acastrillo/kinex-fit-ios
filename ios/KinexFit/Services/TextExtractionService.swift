import Foundation
import Vision
import UIKit
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "TextExtraction")

/// Service for extracting text from images using Vision framework
final class TextExtractionService {

    enum ExtractionError: LocalizedError {
        case imageLoadFailed
        case noTextFound
        case processingFailed(Error)

        var errorDescription: String? {
            switch self {
            case .imageLoadFailed:
                return "Failed to load image for text extraction"
            case .noTextFound:
                return "No text was found in the image"
            case .processingFailed(let error):
                return "Text extraction failed: \(error.localizedDescription)"
            }
        }
    }

    /// Extract text from a UIImage
    func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw ExtractionError.imageLoadFailed
        }

        return try await extractText(from: cgImage)
    }

    /// Extract text from image data
    func extractText(from imageData: Data) async throws -> String {
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage else {
            throw ExtractionError.imageLoadFailed
        }

        return try await extractText(from: cgImage)
    }

    /// Extract text from a file URL
    func extractText(from url: URL) async throws -> String {
        guard let image = UIImage(contentsOfFile: url.path),
              let cgImage = image.cgImage else {
            throw ExtractionError.imageLoadFailed
        }

        return try await extractText(from: cgImage)
    }

    /// Core extraction method using Vision framework
    private func extractText(from cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: ExtractionError.processingFailed(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    continuation.resume(throwing: ExtractionError.noTextFound)
                    return
                }

                // Extract text from observations, sorted by position (top to bottom)
                let sortedObservations = observations.sorted { obs1, obs2 in
                    // Sort by Y position (top to bottom), then X (left to right)
                    if abs(obs1.boundingBox.midY - obs2.boundingBox.midY) < 0.02 {
                        return obs1.boundingBox.minX < obs2.boundingBox.minX
                    }
                    return obs1.boundingBox.midY > obs2.boundingBox.midY
                }

                let text = sortedObservations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                if text.isEmpty {
                    continuation.resume(throwing: ExtractionError.noTextFound)
                } else {
                    logger.info("Extracted \(text.count) characters from image")
                    continuation.resume(returning: text)
                }
            }

            // Configure for best accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ExtractionError.processingFailed(error))
            }
        }
    }

    /// Extract text from video by sampling frames
    func extractText(fromVideoAt url: URL, sampleInterval: TimeInterval = 3.0) async throws -> String {
        // For now, we'll use AVAsset to extract frames
        // This is a simplified implementation - full video OCR would sample multiple frames
        logger.info("Video text extraction requested - using first frame")

        // Try to get thumbnail from video
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try await imageGenerator.image(at: .zero).image
            return try await extractText(from: cgImage)
        } catch {
            throw ExtractionError.processingFailed(error)
        }
    }
}

import AVFoundation
