import Foundation
import XCTest
@testable import Kinex_Fit

final class AppDatabaseTests: XCTestCase {
    func testApplyFileProtectionRequestsProtectionForDatabaseAndSidecars() throws {
        let databaseURL = URL(fileURLWithPath: "/tmp/\(UUID().uuidString)/kinex-fit.sqlite")
        let fileManager = RecordingFileManager(existingPaths: Set(AppDatabase.databaseFileURLs(for: databaseURL).map(\.path)))

        try AppDatabase.applyFileProtection(toDatabaseFilesAt: databaseURL, fileManager: fileManager)

        XCTAssertEqual(Set(fileManager.protectedPaths), Set(AppDatabase.databaseFileURLs(for: databaseURL).map(\.path)))
        XCTAssertTrue(fileManager.protectionTypes.allSatisfy { $0 == AppDatabase.databaseFileProtection })
    }

    func testInitWithDatabaseURLRequestsProtectionForDatabaseFiles() throws {
        let recordingFileManager = RecordingFileManager()
        let tempDirectory = recordingFileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? recordingFileManager.removeItem(at: tempDirectory) }

        let databaseURL = tempDirectory.appendingPathComponent("kinex-fit.sqlite")
        _ = try AppDatabase(databaseURL: databaseURL, fileManager: recordingFileManager)

        XCTAssertTrue(recordingFileManager.fileExists(atPath: databaseURL.path))
        XCTAssertTrue(recordingFileManager.protectedPaths.contains(databaseURL.path))
        XCTAssertTrue(recordingFileManager.protectionTypes.allSatisfy { $0 == AppDatabase.databaseFileProtection })
    }
}

private final class RecordingFileManager: FileManager {
    private let backingFileManager = FileManager.default
    private let stubbedExistingPaths: Set<String>?

    private(set) var protectedPaths: [String] = []
    private(set) var protectionTypes: [FileProtectionType] = []

    init(existingPaths: Set<String>? = nil) {
        self.stubbedExistingPaths = existingPaths
        super.init()
    }

    override func fileExists(atPath path: String) -> Bool {
        if let stubbedExistingPaths {
            return stubbedExistingPaths.contains(path)
        }

        return backingFileManager.fileExists(atPath: path)
    }

    override func createDirectory(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey : Any]? = nil
    ) throws {
        try backingFileManager.createDirectory(
            at: url,
            withIntermediateDirectories: createIntermediates,
            attributes: attributes
        )
    }

    override func createFile(
        atPath path: String,
        contents data: Data?,
        attributes attr: [FileAttributeKey : Any]? = nil
    ) -> Bool {
        backingFileManager.createFile(atPath: path, contents: data, attributes: attr)
    }

    override func removeItem(at URL: URL) throws {
        try backingFileManager.removeItem(at: URL)
    }

    override func setAttributes(
        _ attributes: [FileAttributeKey : Any],
        ofItemAtPath path: String
    ) throws {
        if let protectionType = attributes[.protectionKey] as? FileProtectionType {
            protectedPaths.append(path)
            protectionTypes.append(protectionType)
        }

        if stubbedExistingPaths == nil {
            try backingFileManager.setAttributes(attributes, ofItemAtPath: path)
        }
    }
}
