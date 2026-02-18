import Foundation
import OSLog
import UIKit

private let logger = Logger(subsystem: "com.kinex.fit", category: "OCRService")

// MARK: - OCR Response Models

struct OCRResponse: Codable {
    let text: String
    let confidence: Double?
    let quotaUsed: Int?
    let quotaLimit: Int?
    let isUnlimited: Bool?
}

struct OCRQuota: Codable {
    let used: Int
    let limit: Int?
    let isUnlimited: Bool

    var remaining: Int? {
        guard let limit = limit else { return nil }
        return max(0, limit - used)
    }

    var isExhausted: Bool {
        guard let limit = limit else { return false }
        return used >= limit
    }

    var displayText: String {
        if isUnlimited {
            return "Unlimited"
        }
        if let limit = limit {
            return "\(used)/\(limit) scans used"
        }
        return "\(used) scans used"
    }
}

// MARK: - OCR Error

enum OCRError: LocalizedError {
    case quotaExceeded(used: Int, limit: Int)
    case rateLimited(retryAfter: TimeInterval?)
    case invalidImage
    case fileTooLarge(maxSize: Int)
    case networkError(Error)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .quotaExceeded(let used, let limit):
            return "You've used all \(limit) scans this week (\(used)/\(limit)). Upgrade for more."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .invalidImage:
            return "The image couldn't be processed. Try a clearer photo."
        case .fileTooLarge(let maxSize):
            return "Image is too large. Maximum size is \(maxSize / 1024 / 1024)MB."
        case .networkError:
            return "Network error. Check your connection and try again."
        case .serverError(let message):
            return message
        }
    }
}

// MARK: - OCR Service

final class OCRService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Process an image through OCR to extract text
    /// - Parameter image: The UIImage to process
    /// - Returns: OCRResponse with extracted text and quota info
    func processImage(_ image: UIImage) async throws -> OCRResponse {
        // Compress and prepare image
        guard let imageData = prepareImageForUpload(image) else {
            throw OCRError.invalidImage
        }

        // Check file size (10MB limit)
        let maxSize = 10 * 1024 * 1024
        if imageData.count > maxSize {
            throw OCRError.fileTooLarge(maxSize: maxSize)
        }

        logger.info("Uploading image for OCR: \(imageData.count) bytes")

        let request = APIRequest.multipartFormData(
            path: "/api/ocr",
            fileData: imageData,
            fileName: "scan.jpg",
            mimeType: "image/jpeg"
        )

        do {
            let decoder = JSONDecoder()
            let response: OCRResponse = try await apiClient.send(request, decoder: decoder)
            logger.info("OCR completed: \(response.text.prefix(100))...")
            return response
        } catch let error as APIError {
            switch error {
            case .httpStatus(429):
                // Could be quota or rate limit - try to parse response
                throw OCRError.rateLimited(retryAfter: nil)
            case .httpStatus(let code):
                throw OCRError.serverError("Server error (code \(code))")
            default:
                throw OCRError.networkError(error)
            }
        } catch {
            throw OCRError.networkError(error)
        }
    }

    /// Prepare image for upload by resizing and compressing
    private func prepareImageForUpload(_ image: UIImage) -> Data? {
        // Resize if too large (max 2048px on longest side for good OCR quality)
        let maxDimension: CGFloat = 2048
        var processedImage = image

        if image.size.width > maxDimension || image.size.height > maxDimension {
            let scale = maxDimension / max(image.size.width, image.size.height)
            let newSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            processedImage = resizeImage(image, to: newSize) ?? image
        }

        // Compress as JPEG with good quality
        return processedImage.jpegData(compressionQuality: 0.85)
    }

    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// MARK: - Workout Text Parser

/// Parses OCR text to extract workout structure
struct WorkoutTextParser {
    /// Parse raw OCR text into a structured format
    /// This is a basic parser - the AI enhancement will do a better job
    static func parse(_ text: String) -> ParsedWorkout {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Try to find a title (first non-empty line that looks like a title)
        let title = lines.first ?? "Scanned Workout"

        // The rest becomes the content
        let content = lines.dropFirst().joined(separator: "\n")

        return ParsedWorkout(
            title: title,
            content: content.isEmpty ? text : content,
            rawText: text,
            confidence: nil
        )
    }
}

struct ParsedWorkout {
    var title: String
    var content: String
    let rawText: String
    let confidence: Double?

    /// Check if the parsed workout seems valid
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
