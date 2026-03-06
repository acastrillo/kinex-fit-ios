import Foundation
import OSLog

/// Represents a social media post import (Instagram or TikTok) pending processing
struct InstagramImport: Codable, Identifiable {
    let id: String
    let postURL: String?
    let captionText: String?
    let mediaType: MediaType
    let mediaLocalPath: String  // Relative path in App Group container
    let createdAt: Date
    var processingStatus: ProcessingStatus
    var extractedText: String?
    var sourcePlatform: SocialPlatform

    enum MediaType: String, Codable {
        case image
        case video
        case carousel
        case unknown
    }

    enum ProcessingStatus: String, Codable {
        case pending
        case processing
        case completed
        case failed
    }

    init(
        id: String = UUID().uuidString,
        postURL: String? = nil,
        captionText: String? = nil,
        mediaType: MediaType = .unknown,
        mediaLocalPath: String,
        createdAt: Date = Date(),
        processingStatus: ProcessingStatus = .pending,
        extractedText: String? = nil,
        sourcePlatform: SocialPlatform = .instagram
    ) {
        self.id = id
        self.postURL = postURL
        self.captionText = captionText
        self.mediaType = mediaType
        self.mediaLocalPath = mediaLocalPath
        self.createdAt = createdAt
        self.processingStatus = processingStatus
        self.extractedText = extractedText
        self.sourcePlatform = sourcePlatform
    }

    // Custom decoder to default sourcePlatform to .instagram for existing stored records
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        postURL = try container.decodeIfPresent(String.self, forKey: .postURL)
        captionText = try container.decodeIfPresent(String.self, forKey: .captionText)
        mediaType = try container.decode(MediaType.self, forKey: .mediaType)
        mediaLocalPath = try container.decode(String.self, forKey: .mediaLocalPath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        processingStatus = try container.decode(ProcessingStatus.self, forKey: .processingStatus)
        extractedText = try container.decodeIfPresent(String.self, forKey: .extractedText)
        sourcePlatform = try container.decodeIfPresent(SocialPlatform.self, forKey: .sourcePlatform) ?? .instagram
    }
}

/// Utility for App Group shared storage
enum AppGroup {
    private static let logger = Logger(subsystem: "com.kinex.fit", category: "AppGroup")
    static let identifier = "group.com.kinex.fit"

    static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        )
    }

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }

    static var importsDirectory: URL? {
        containerURL?.appendingPathComponent("InstagramImports", isDirectory: true)
    }

    static var mediaDirectory: URL? {
        importsDirectory?.appendingPathComponent("Media", isDirectory: true)
    }

    // MARK: - Keys

    static let pendingImportsKey = "pendingInstagramImports"

    // MARK: - Directory Setup

    static func ensureDirectoriesExist() {
        guard let importsDir = importsDirectory,
              let mediaDir = mediaDirectory else { return }

        do {
            try FileManager.default.createDirectory(
                at: importsDir,
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: mediaDir,
                withIntermediateDirectories: true
            )
        } catch {
            logger.error("Failed to ensure App Group directories: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Import Management

    /// Save a new import to the shared container
    static func saveImport(_ importItem: InstagramImport) {
        var imports = getPendingImports()
        imports.append(importItem)
        savePendingImports(imports)
    }

    /// Get all pending imports
    static func getPendingImports() -> [InstagramImport] {
        guard let defaults = sharedDefaults else {
            logger.error("Shared defaults unavailable for App Group identifier \(identifier, privacy: .public)")
            return []
        }
        guard let data = defaults.data(forKey: pendingImportsKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([InstagramImport].self, from: data)
        } catch {
            logger.error(
                "Failed to decode pending imports payload (bytes: \(data.count), key: \(pendingImportsKey, privacy: .public)): \(error.localizedDescription, privacy: .public)"
            )
            return []
        }
    }

    /// Save the pending imports array
    static func savePendingImports(_ imports: [InstagramImport]) {
        guard let defaults = sharedDefaults else {
            logger.error("Shared defaults unavailable for App Group identifier \(identifier, privacy: .public)")
            return
        }

        do {
            let data = try JSONEncoder().encode(imports)
            defaults.set(data, forKey: pendingImportsKey)
        } catch {
            logger.error("Failed to encode pending imports for save: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Update an existing import record in the shared container
    static func updateImport(_ importItem: InstagramImport) {
        var imports = getPendingImports()
        if let index = imports.firstIndex(where: { $0.id == importItem.id }) {
            imports[index] = importItem
            savePendingImports(imports)
        }
    }

    /// Remove a processed import
    static func removeImport(id: String) {
        var imports = getPendingImports()
        imports.removeAll { $0.id == id }
        savePendingImports(imports)

        // Also remove media file
        if let mediaDir = mediaDirectory {
            let possibleExtensions = ["jpg", "jpeg", "png", "mp4", "mov"]
            for ext in possibleExtensions {
                let fileURL = mediaDir.appendingPathComponent("\(id).\(ext)")
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    /// Clear all pending imports (for cleanup)
    static func clearAllImports() {
        sharedDefaults?.removeObject(forKey: pendingImportsKey)

        // Clear media directory
        if let mediaDir = mediaDirectory {
            try? FileManager.default.removeItem(at: mediaDir)
            try? FileManager.default.createDirectory(
                at: mediaDir,
                withIntermediateDirectories: true
            )
        }
    }
}
