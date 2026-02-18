import Foundation

/// Represents an Instagram post import pending processing
struct InstagramImport: Codable, Identifiable {
    let id: String
    let postURL: String?
    let captionText: String?
    let mediaType: MediaType
    let mediaLocalPath: String  // Relative path in App Group container
    let createdAt: Date
    var processingStatus: ProcessingStatus
    var extractedText: String?

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
        extractedText: String? = nil
    ) {
        self.id = id
        self.postURL = postURL
        self.captionText = captionText
        self.mediaType = mediaType
        self.mediaLocalPath = mediaLocalPath
        self.createdAt = createdAt
        self.processingStatus = processingStatus
        self.extractedText = extractedText
    }
}

/// Utility for App Group shared storage
enum AppGroup {
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

        try? FileManager.default.createDirectory(
            at: importsDir,
            withIntermediateDirectories: true
        )
        try? FileManager.default.createDirectory(
            at: mediaDir,
            withIntermediateDirectories: true
        )
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
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: pendingImportsKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([InstagramImport].self, from: data)
        } catch {
            return []
        }
    }

    /// Save the pending imports array
    static func savePendingImports(_ imports: [InstagramImport]) {
        guard let defaults = sharedDefaults else { return }

        do {
            let data = try JSONEncoder().encode(imports)
            defaults.set(data, forKey: pendingImportsKey)
        } catch {
            // Handle error silently
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
