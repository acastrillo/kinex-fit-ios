import Foundation
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "VideoCache")

/// Manages local caching of demo videos for offline viewing
@MainActor
final class VideoCacheManager: NSObject, ObservableObject {
    @Published var cachedVideos: [String: CachedVideoInfo] = [:]
    @Published var downloadProgress: [String: Double] = [:]
    @Published var activeDownloads: Set<String> = []
    
    static let shared = VideoCacheManager()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let session: URLSession
    
    struct CachedVideoInfo: Codable {
        let videoId: String
        let title: String
        let url: String
        let cachedAt: Date
        let fileSize: Int64
        var isDeleted: Bool = false
        
        var formattedSize: String {
            let bytes = Double(fileSize)
            if bytes < 1_000_000 {
                return String(format: "%.1f MB", bytes / 1_000_000)
            } else {
                return String(format: "%.1f GB", bytes / 1_000_000_000)
            }
        }
    }
    
    override init() {
        // Create cache directory
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        self.cacheDirectory = paths[0].appendingPathComponent("com.kinex.fit.videos")
        
        // Create session with background config
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 3600 // 1 hour for large videos
        self.session = URLSession(configuration: config)
        
        super.init()
        
        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Load cached video metadata
        loadCachedVideos()
    }
    
    // MARK: - Cache Operations
    
    /// Download and cache a video
    func downloadVideo(id: String, title: String, url: String) async {
        // Check if already cached
        if cachedVideos[id] != nil && fileExists(id: id) {
            logger.debug("Video \(id) already cached")
            return
        }
        
        activeDownloads.insert(id)
        downloadProgress[id] = 0
        
        do {
            let (tempURL, response) = try await session.download(from: URL(string: url)!)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NSError(domain: "VideoCacheManager", code: -1)
            }
            
            // Move to cache directory
            let cachedURL = cacheDirectory.appendingPathComponent("\(id).mp4")
            try fileManager.moveItem(at: tempURL, to: cachedURL)
            
            // Get file size
            let attributes = try fileManager.attributesOfItem(atPath: cachedURL.path)
            let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            
            // Save metadata
            let info = CachedVideoInfo(
                videoId: id,
                title: title,
                url: url,
                cachedAt: Date(),
                fileSize: fileSize
            )
            cachedVideos[id] = info
            saveCachedVideoMetadata()
            
            logger.info("Cached video: \(id) (\(info.formattedSize))")
            downloadProgress[id] = 1.0
            
        } catch {
            logger.error("Failed to cache video \(id): \(error.localizedDescription)")
            downloadProgress.removeValue(forKey: id)
        }
        
        activeDownloads.remove(id)
    }
    
    /// Get local URL for cached video
    func getLocalURL(id: String) -> URL? {
        let url = cacheDirectory.appendingPathComponent("\(id).mp4")
        if fileManager.fileExists(atPath: url.path) {
            return url
        }
        return nil
    }
    
    /// Check if video is cached
    func isCached(id: String) -> Bool {
        guard let info = cachedVideos[id], !info.isDeleted else { return false }
        return fileExists(id: id)
    }
    
    /// Delete cached video
    func deleteVideo(id: String) async {
        let url = cacheDirectory.appendingPathComponent("\(id).mp4")
        try? fileManager.removeItem(at: url)
        
        // Mark as deleted in metadata
        if var info = cachedVideos[id] {
            info.isDeleted = true
            cachedVideos[id] = info
        } else {
            cachedVideos.removeValue(forKey: id)
        }
        
        saveCachedVideoMetadata()
        logger.info("Deleted cached video: \(id)")
    }
    
    /// Clear all cached videos
    func clearAllCache() async {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        cachedVideos.removeAll()
        downloadProgress.removeAll()
        activeDownloads.removeAll()
        
        saveCachedVideoMetadata()
        logger.info("Cleared all cached videos")
    }
    
    /// Get total cache size
    func getCacheSize() -> Int64 {
        cachedVideos.values
            .filter { !$0.isDeleted }
            .reduce(0) { $0 + $1.fileSize }
    }
    
    // MARK: - Persistence
    
    private func saveCachedVideoMetadata() {
        let encoder = JSONEncoder()
        let metadata = cachedVideos.values.filter { !$0.isDeleted }
        
        if let encoded = try? encoder.encode(Array(metadata)),
           let json = try? JSONSerialization.jsonObject(with: encoded) as? [[String: Any]] {
            let metadataURL = cacheDirectory.appendingPathComponent("metadata.json")
            try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted).write(to: metadataURL)
        }
    }
    
    private func loadCachedVideos() {
        let metadataURL = cacheDirectory.appendingPathComponent("metadata.json")
        guard let data = try? Data(contentsOf: metadataURL) else {
            return
        }
        
        let decoder = JSONDecoder()
        if let videos = try? decoder.decode([CachedVideoInfo].self, from: data) {
            for video in videos {
                cachedVideos[video.videoId] = video
            }
            logger.debug("Loaded \(videos.count) cached videos from metadata")
        }
    }
    
    private func fileExists(id: String) -> Bool {
        let url = cacheDirectory.appendingPathComponent("\(id).mp4")
        return fileManager.fileExists(atPath: url.path)
    }
}

// MARK: - Preview

#if DEBUG
extension VideoCacheManager {
    static var preview: VideoCacheManager {
        let manager = VideoCacheManager()
        manager.cachedVideos["demo1"] = CachedVideoInfo(
            videoId: "demo1",
            title: "Kettlebell Swing Demo",
            url: "https://example.com/demo1.mp4",
            cachedAt: Date(),
            fileSize: 52_428_800 // 50 MB
        )
        return manager
    }
}
#endif
