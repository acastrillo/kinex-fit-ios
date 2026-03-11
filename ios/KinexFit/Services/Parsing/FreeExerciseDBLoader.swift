import Foundation
import OSLog

private let freeExerciseDBLogger = Logger(subsystem: "com.kinex.fit", category: "FreeExerciseDBLoader")

/// Loads the bundled `free-exercise-db.json` (https://github.com/yuhonas/free-exercise-db)
/// and converts it into an `ExerciseLibraryMatcher`-compatible catalog.
///
/// ## Setup
/// 1. Download `exercises.json` from https://github.com/yuhonas/free-exercise-db/raw/main/dist/exercises.json
/// 2. Rename it to `free-exercise-db.json`
/// 3. Drag it into your Xcode project (ensure "Add to target: KinexFit" is checked)
///
/// The loader is a no-op (returns an empty catalog) when the file is absent, so the
/// built-in `ExerciseLibraryMatcher` catalog always works as the fallback.
enum FreeExerciseDBLoader {

    // MARK: - JSON model

    private struct Entry: Decodable {
        let name: String
        let aliases: [String]?
        let primaryMuscles: [String]?
        let secondaryMuscles: [String]?
        let category: String?
        let equipment: String?
        let force: String?       // "push" | "pull" | "static"
        let mechanic: String?    // "compound" | "isolation"
        let level: String?       // "beginner" | "intermediate" | "expert"

        // free-exercise-db doesn't always have an "aliases" field —
        // sometimes it's spelled "alternativeNames"
        enum CodingKeys: String, CodingKey {
            case name, aliases, primaryMuscles, secondaryMuscles
            case category, equipment, force, mechanic, level
        }
    }

    // MARK: - Public API

    /// Returns an alias catalog suitable for `ExerciseLibraryMatcher(additionalCatalog:)`.
    /// Returns an empty dictionary if the JSON file is not found in the bundle.
    static func loadCatalog() -> [String: [String]] {
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else {
            freeExerciseDBLogger.info("exercises.json not found in bundle — using built-in catalog only.")
            return [:]
        }

        do {
            let data = try Data(contentsOf: url)
            let entries = try JSONDecoder().decode([Entry].self, from: data)
            freeExerciseDBLogger.info("Loaded \(entries.count) exercises from exercises.json")
            return buildCatalog(from: entries)
        } catch {
            freeExerciseDBLogger.error("Failed to load free-exercise-db.json: \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }

    // MARK: - Private

    private static func buildCatalog(from entries: [Entry]) -> [String: [String]] {
        var catalog: [String: [String]] = [:]

        for entry in entries {
            let canonical = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !canonical.isEmpty else { continue }

            var aliases: [String] = entry.aliases?.compactMap {
                let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            } ?? []

            // Build additional aliases from the exercise name itself
            // e.g. "3/4 Sit-Up" → ["3 4 Sit-Up", "Three Quarter Sit Up"] etc.
            aliases += derivedAliases(for: canonical)

            catalog[canonical] = aliases
        }

        return catalog
    }

    /// Generates a small set of additional aliases from a canonical name.
    private static func derivedAliases(for name: String) -> [String] {
        var derived: [String] = []

        // Strip leading ordinals like "3/4 " or "1/2 "
        let noFraction = name
            .replacingOccurrences(of: #"\d+/\d+\s+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if noFraction != name, !noFraction.isEmpty {
            derived.append(noFraction)
        }

        // Lowercase variant without punctuation
        let simplified = name
            .replacingOccurrences(of: #"[^a-zA-Z0-9\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if simplified != name.lowercased(), !simplified.isEmpty {
            derived.append(simplified)
        }

        return derived
    }
}
