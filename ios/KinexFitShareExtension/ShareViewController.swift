import UIKit
import SwiftUI
import UniformTypeIdentifiers
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit.share-extension", category: "ShareViewController")

/// Main view controller for the Share Extension
/// Wraps SwiftUI content in a UIHostingController
class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Ensure App Group directories exist
        AppGroupShared.ensureDirectoriesExist()

        // Create SwiftUI view
        let shareView = ShareView(
            extensionContext: extensionContext,
            onComplete: { [weak self] in
                self?.completeRequest()
            },
            onCancel: { [weak self] in
                self?.cancelRequest()
            }
        )

        // Embed in hosting controller
        let hostingController = UIHostingController(rootView: shareView)
        addChild(hostingController)
        view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        hostingController.didMove(toParent: self)
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func cancelRequest() {
        extensionContext?.cancelRequest(withError: NSError(domain: "com.kinex.fit", code: 0))
    }
}

// MARK: - App Group Shared (Duplicate for Extension)
// Note: Share Extension is a separate target, so we need to duplicate or share this code

enum AppGroupShared {
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

    static let pendingImportsKey = "pendingInstagramImports"

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
}

// MARK: - Instagram Import Model (Duplicate for Extension)

struct InstagramImportShared: Codable {
    let id: String
    let postURL: String?
    let captionText: String?
    let mediaType: String
    let mediaLocalPath: String
    let createdAt: Date
    var processingStatus: String
    var extractedText: String?

    init(
        id: String = UUID().uuidString,
        postURL: String? = nil,
        captionText: String? = nil,
        mediaType: String = "unknown",
        mediaLocalPath: String,
        createdAt: Date = Date(),
        processingStatus: String = "pending",
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

    static func saveToAppGroup(_ item: InstagramImportShared) {
        guard let defaults = AppGroupShared.sharedDefaults else { return }

        var imports = getAllFromAppGroup()
        imports.append(item)

        if let data = try? JSONEncoder().encode(imports) {
            defaults.set(data, forKey: AppGroupShared.pendingImportsKey)
        }
    }

    static func getAllFromAppGroup() -> [InstagramImportShared] {
        guard let defaults = AppGroupShared.sharedDefaults,
              let data = defaults.data(forKey: AppGroupShared.pendingImportsKey),
              let imports = try? JSONDecoder().decode([InstagramImportShared].self, from: data) else {
            return []
        }
        return imports
    }
}
