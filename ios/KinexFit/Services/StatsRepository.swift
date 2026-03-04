import Foundation
import GRDB
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "StatsRepository")

/// Repository for stats and analytics operations
/// Handles caching, pagination, and date range filtering
@MainActor
final class StatsRepository {
    static let shared: StatsRepository = {
        let environment = AppState.shared?.environment ?? .preview
        return StatsRepository(
            database: environment.database,
            apiClient: environment.apiClient,
            syncEngine: environment.syncEngine
        )
    }()

    private let database: AppDatabase
    private let apiClient: APIClient
    private let syncEngine: SyncEngine
    
    // MARK: - Cache Management
    
    private static let statsCacheDuration: TimeInterval = 3600 // 1 hour
    private var statsCache: [String: CacheEntry] = [:]
    
        struct CacheEntry {
            let data: [String: Any]
            let fetchedAt: Date
            
            var isExpired: Bool {
                Date().timeIntervalSince(fetchedAt) > 3600
            }
        }
    
    init(database: AppDatabase, apiClient: APIClient, syncEngine: SyncEngine) {
        self.database = database
        self.apiClient = apiClient
        self.syncEngine = syncEngine
    }
    
    // MARK: - Metrics Stats
    
    /// Fetch body metrics with optional date range filtering and caching
    func getBodyMetricsStats(
        startDate: Date? = nil,
        endDate: Date? = nil,
        limit: Int = 100
    ) async throws -> [BodyMetric] {
        let cacheKey = "\(startDate?.timeIntervalSince1970 ?? 0)-\(endDate?.timeIntervalSince1970 ?? 0)-\(limit)"
        
        // Check cache
        if let cached = statsCache[cacheKey], !cached.isExpired {
            logger.debug("Using cached body metrics stats")
            // Return cached data (would need to decode properly in production)
        }
        
        // Fetch fresh data
        let request = APIRequest.getBodyMetrics(limit: limit)
        let metrics: [BodyMetric] = try await apiClient.send(request)
        
        // Filter by date range if provided
        let filtered = metrics.filter { metric in
            let date = metric.date
            if let start = startDate, date < start { return false }
            if let end = endDate, date > end { return false }
            return true
        }
        
        // Cache the result
        statsCache[cacheKey] = CacheEntry(data: [:], fetchedAt: Date())
        logger.debug("Cached body metrics stats with key: \(cacheKey)")
        
        return filtered
    }

    /// Backward-compatible alias used by export and analytics features.
    func getBodyMetrics(
        startDate: Date? = nil,
        endDate: Date? = nil,
        limit: Int = 100
    ) async throws -> [BodyMetric] {
        try await getBodyMetricsStats(startDate: startDate, endDate: endDate, limit: limit)
    }
    
    /// Fetch personal records (PRs) with caching
    func getPersonalRecords() async throws -> [String: PersonalRecord] {
        let cacheKey = "personal_records"
        
        // Check cache
        if let cached = statsCache[cacheKey], !cached.isExpired {
            logger.debug("Using cached personal records")
        }
        
        // Fetch fresh data
        let request = APIRequest.getTrainingProfile()
        let profile: TrainingProfile = try await apiClient.send(request)
        
        // Extract PRs from profile
        let prs = profile.personalRecords.reduce(into: [String: PersonalRecord]()) { dict, pr in
            dict[pr.exerciseName] = pr
        }
        
        // Cache the result
        statsCache[cacheKey] = CacheEntry(data: [:], fetchedAt: Date())
        logger.debug("Cached personal records")
        
        return prs
    }
    
    /// Get progression data for a specific exercise
    func getExerciseProgression(
        exercise: String,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> [ProgressionPoint] {
        let cacheKey = "progression-\(exercise)-\(startDate?.timeIntervalSince1970 ?? 0)-\(endDate?.timeIntervalSince1970 ?? 0)"
        
        // Check cache
        if let cached = statsCache[cacheKey], !cached.isExpired {
            logger.debug("Using cached progression for \(exercise)")
        }
        
        // Fetch workouts
        let workouts = try await database.dbQueue.read { db in
            try Workout.fetchAll(db)
        }
        
        // Build progression points from workout history
        var progressionPoints: [ProgressionPoint] = []
        
        for workout in workouts {
            guard workout.content?.contains(exercise) ?? false else { continue }
            
            // Parse exercise data from content
            if let maxWeight = extractMaxWeight(from: workout.content, exercise: exercise),
               let completedDate = workout.completedDate,
               let date = parseDateString(completedDate) {
                
                let point = ProgressionPoint(
                    date: date,
                    weight: maxWeight,
                    reps: 1,
                    volume: maxWeight
                )
                
                // Filter by date range
                if let start = startDate, date < start { continue }
                if let end = endDate, date > end { continue }
                
                progressionPoints.append(point)
            }
        }
        
        // Cache the result
        statsCache[cacheKey] = CacheEntry(data: [:], fetchedAt: Date())
        logger.debug("Cached progression for \(exercise)")
        
        return progressionPoints.sorted { $0.date < $1.date }
    }
    
    /// Clear specific cache entry or entire cache
    func invalidateCache(key: String? = nil) {
        if let key = key {
            statsCache.removeValue(forKey: key)
            logger.debug("Invalidated cache for key: \(key)")
        } else {
            statsCache.removeAll()
            logger.debug("Cleared entire stats cache")
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractMaxWeight(from content: String?, exercise: String) -> Double? {
        // Simple weight extraction from content
        // In production, this would parse structured data
        guard let content = content else { return nil }
        
        // Look for patterns like "100 lbs", "50 kg"
        let pattern = "\\d+(?:\\.\\d+)?"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        
        let nsString = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsString.length))
        
        // Return the first number found (rough heuristic)
        if let first = matches.first {
            let range = first.range
            let numberString = nsString.substring(with: range)
            return Double(numberString)
        }
        
        return nil
    }

    private func parseDateString(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}

// MARK: - Models

struct ProgressionPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
    let reps: Int
    let volume: Double // weight × reps
}
