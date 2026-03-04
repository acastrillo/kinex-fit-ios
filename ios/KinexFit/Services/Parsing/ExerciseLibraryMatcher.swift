import Foundation

final class ExerciseLibraryMatcher {
    struct MatchResolution: Equatable {
        var displayName: String
        var match: CaptionExerciseMatch
    }

    private var cache: [String: MatchResolution] = [:]
    private let cacheLock = NSLock()

    func matchExercise(name: String, authoritativeHints: [AuthoritativeExerciseHint]) -> CaptionExerciseMatch {
        resolveExercise(name: name, authoritativeHints: authoritativeHints).match
    }

    func resolveExercise(name: String, authoritativeHints: [AuthoritativeExerciseHint]) -> MatchResolution {
        let normalized = Self.normalize(name)
        guard !normalized.isEmpty else {
            return MatchResolution(displayName: name, match: .unknown(closestMatches: []))
        }

        let cacheKey = makeCacheKey(normalized: normalized, hints: authoritativeHints)
        if let cached = cachedValue(for: cacheKey) {
            return cached
        }

        let resolution = resolveUncached(normalized: normalized, originalName: name, authoritativeHints: authoritativeHints)
        storeCachedValue(resolution, for: cacheKey)
        return resolution
    }

    private func resolveUncached(
        normalized: String,
        originalName: String,
        authoritativeHints: [AuthoritativeExerciseHint]
    ) -> MatchResolution {
        if let hintMatch = authoritativeExactMatch(normalized: normalized, hints: authoritativeHints) {
            return MatchResolution(
                displayName: hintMatch.displayName,
                match: .exact(kinexExerciseID: hintMatch.kinexExerciseID)
            )
        }

        if let ambiguousOptions = ambiguousOptions(for: normalized, hints: authoritativeHints) {
            return MatchResolution(
                displayName: originalName,
                match: .ambiguous(ambiguousOptions)
            )
        }

        if let canonical = Self.aliasToCanonical[normalized] {
            return MatchResolution(displayName: canonical, match: .exact(kinexExerciseID: nil))
        }

        if let fuzzyAuthoritative = fuzzyAuthoritativeMatch(normalized: normalized, hints: authoritativeHints) {
            return MatchResolution(
                displayName: fuzzyAuthoritative.displayName,
                match: .fuzzy(
                    kinexExerciseID: fuzzyAuthoritative.kinexExerciseID,
                    confidence: fuzzyAuthoritative.confidence
                )
            )
        }

        if let fuzzyLocal = fuzzyLocalMatch(normalized: normalized) {
            return MatchResolution(
                displayName: fuzzyLocal.displayName,
                match: .fuzzy(
                    kinexExerciseID: nil,
                    confidence: fuzzyLocal.confidence
                )
            )
        }

        let suggestions = closestMatches(normalized: normalized, hints: authoritativeHints)
        return MatchResolution(
            displayName: originalName,
            match: .unknown(closestMatches: suggestions)
        )
    }

    // MARK: - Matching

    private func authoritativeExactMatch(
        normalized: String,
        hints: [AuthoritativeExerciseHint]
    ) -> (kinexExerciseID: String, displayName: String)? {
        for hint in hints {
            let normalizedDisplay = Self.normalize(hint.displayName)
            if normalized == normalizedDisplay {
                return (hint.kinexExerciseID, hint.displayName)
            }

            if hint.aliases.contains(where: { Self.normalize($0) == normalized }) {
                return (hint.kinexExerciseID, hint.displayName)
            }
        }

        return nil
    }

    private func ambiguousOptions(
        for normalized: String,
        hints: [AuthoritativeExerciseHint]
    ) -> [CaptionExerciseOption]? {
        guard let baseOptions = Self.ambiguousCatalog[normalized] else {
            return nil
        }

        var options: [CaptionExerciseOption] = []
        for displayName in baseOptions {
            if let hint = hints.first(where: { Self.normalize($0.displayName) == Self.normalize(displayName) }) {
                options.append(CaptionExerciseOption(kinexExerciseID: hint.kinexExerciseID, displayName: hint.displayName))
            } else {
                options.append(CaptionExerciseOption(kinexExerciseID: nil, displayName: displayName))
            }
        }

        return options.isEmpty ? nil : options
    }

    private func fuzzyAuthoritativeMatch(
        normalized: String,
        hints: [AuthoritativeExerciseHint]
    ) -> (kinexExerciseID: String, displayName: String, confidence: Double)? {
        var best: (distance: Int, confidence: Double, hint: AuthoritativeExerciseHint)?

        for hint in hints {
            let candidates = [hint.displayName] + hint.aliases
            for candidate in candidates {
                let normalizedCandidate = Self.normalize(candidate)
                guard !normalizedCandidate.isEmpty else { continue }

                let distance = Self.levenshtein(normalized, normalizedCandidate)
                let confidence = Self.confidence(distance: distance, input: normalized, candidate: normalizedCandidate)

                if distance <= 2 {
                    if let current = best {
                        if confidence > current.confidence {
                            best = (distance, confidence, hint)
                        }
                    } else {
                        best = (distance, confidence, hint)
                    }
                }
            }
        }

        guard let best, best.confidence >= 0.72 else {
            return nil
        }

        return (
            kinexExerciseID: best.hint.kinexExerciseID,
            displayName: best.hint.displayName,
            confidence: best.confidence
        )
    }

    private func fuzzyLocalMatch(normalized: String) -> (displayName: String, confidence: Double)? {
        var best: (distance: Int, alias: String, canonical: String)?

        for (alias, canonical) in Self.aliasToCanonical {
            let distance = Self.levenshtein(normalized, alias)
            guard distance <= 2 else { continue }

            if let current = best {
                if distance < current.distance {
                    best = (distance, alias, canonical)
                }
            } else {
                best = (distance, alias, canonical)
            }
        }

        guard let best else {
            return nil
        }

        let confidence = Self.confidence(distance: best.distance, input: normalized, candidate: best.alias)
        guard confidence >= 0.7 else {
            return nil
        }

        return (displayName: best.canonical, confidence: confidence)
    }

    private func closestMatches(
        normalized: String,
        hints: [AuthoritativeExerciseHint]
    ) -> [String] {
        var candidates = Set(Self.canonicalNames)
        for hint in hints {
            candidates.insert(hint.displayName)
        }

        let scored = candidates.map { candidate -> (String, Int) in
            let distance = Self.levenshtein(normalized, Self.normalize(candidate))
            return (candidate, distance)
        }
        .sorted { lhs, rhs in
            if lhs.1 == rhs.1 {
                return lhs.0 < rhs.0
            }
            return lhs.1 < rhs.1
        }

        return Array(scored.prefix(3).map(\.0))
    }

    // MARK: - Cache

    private func makeCacheKey(normalized: String, hints: [AuthoritativeExerciseHint]) -> String {
        let hintsKey = hints
            .map { "\($0.kinexExerciseID):\(Self.normalize($0.displayName))" }
            .sorted()
            .joined(separator: ",")
        return normalized + "|" + hintsKey
    }

    private func cachedValue(for key: String) -> MatchResolution? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cache[key]
    }

    private func storeCachedValue(_ value: MatchResolution, for key: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache[key] = value
    }

    // MARK: - Static data

    private static let exerciseCatalog: [String: [String]] = [
        "Air Squat": ["squat", "squats", "bodyweight squat", "body weight squat", "air squat", "air squats"],
        "Barbell Back Squat": ["barbell squat", "back squat", "bb squat"],
        "Front Squat": ["front squat", "barbell front squat"],
        "Goblet Squat": ["goblet squat", "db goblet squat"],
        "Bulgarian Split Squat": ["bulgarian split squat", "bss", "rear foot elevated split squat"],
        "Walking Lunge": ["walking lunge", "walking lunges"],
        "Reverse Lunge": ["reverse lunge", "reverse lunges"],
        "Step-Up": ["step up", "step-up", "stepups"],
        "Hip Thrust": ["hip thrust", "barbell hip thrust"],
        "Glute Bridge": ["glute bridge", "bridges"],
        "Romanian Deadlift": ["romanian deadlift", "rdl", "rom deadlift"],
        "Deadlift": ["deadlift", "deadlifts", "conventional deadlift", "deads"],
        "Sumo Deadlift": ["sumo deadlift"],
        "Trap Bar Deadlift": ["trap bar deadlift", "hex bar deadlift"],
        "Good Morning": ["good morning", "good mornings"],
        "Leg Press": ["leg press"],
        "Leg Extension": ["leg extension", "extensions"],
        "Leg Curl": ["leg curl", "hamstring curl", "ham curls"],
        "Calf Raise": ["calf raise", "calf raises", "standing calf raise", "seated calf raise"],
        "Bench Press": ["bench", "bench press", "bb bench", "barbell bench"],
        "Incline Bench Press": ["incline bench", "incline bench press"],
        "Dumbbell Bench Press": ["db bench", "dumbbell bench", "dumbbell bench press"],
        "Push-Up": ["push up", "pushups", "push-up", "push ups"],
        "Chest Fly": ["chest fly", "pec fly", "fly"],
        "Dip": ["dip", "dips", "tricep dip", "parallel bar dip"],
        "Overhead Press": ["overhead press", "ohp", "shoulder press", "military press"],
        "Dumbbell Shoulder Press": ["db shoulder press", "dumbbell shoulder press"],
        "Arnold Press": ["arnold press"],
        "Lateral Raise": ["lateral raise", "side raise", "lateral raises"],
        "Front Raise": ["front raise", "front raises"],
        "Rear Delt Fly": ["rear delt fly", "reverse fly", "rear fly"],
        "Upright Row": ["upright row", "upright rows"],
        "Barbell Row": ["barbell row", "bent over row", "bb row", "rows"],
        "Dumbbell Row": ["dumbbell row", "db row", "one arm row", "single arm row"],
        "Seated Cable Row": ["cable row", "seated row", "machine row"],
        "Lat Pulldown": ["lat pulldown", "pull down", "pulldown"],
        "Pull-Up": ["pull up", "pull-up", "pullups", "pull ups"],
        "Chin-Up": ["chin up", "chin-up", "chinups", "chin ups"],
        "Face Pull": ["face pull", "face pulls"],
        "Shrug": ["shrug", "shrugs"],
        "Biceps Curl": ["bicep curl", "biceps curl", "curl", "curls"],
        "Hammer Curl": ["hammer curl", "hammer curls"],
        "Preacher Curl": ["preacher curl", "preacher curls"],
        "Triceps Pushdown": ["tricep pushdown", "triceps pushdown", "pushdown", "rope pushdown"],
        "Skull Crusher": ["skull crusher", "lying triceps extension"],
        "Overhead Triceps Extension": ["overhead tricep extension", "overhead triceps extension"],
        "Plank": ["plank", "front plank", "planks"],
        "Side Plank": ["side plank", "side planks"],
        "Hollow Hold": ["hollow hold"],
        "Dead Bug": ["dead bug", "dead bugs"],
        "Mountain Climber": ["mountain climber", "mountain climbers"],
        "Russian Twist": ["russian twist", "russian twists"],
        "Sit-Up": ["sit up", "sit-up", "situps"],
        "Crunch": ["crunch", "crunches"],
        "Bicycle Crunch": ["bicycle crunch", "bicycle crunches"],
        "Hanging Knee Raise": ["hanging knee raise", "knee raise", "leg raise"],
        "Burpee": ["burpee", "burpees"],
        "Jumping Jack": ["jumping jack", "jumping jacks"],
        "High Knees": ["high knees", "high knee"],
        "Jump Rope": ["jump rope", "skipping"],
        "Box Jump": ["box jump", "box jumps"],
        "Broad Jump": ["broad jump", "broad jumps"],
        "Kettlebell Swing": ["kettlebell swing", "kb swing", "kettlebell swings"],
        "Thruster": ["thruster", "thrusters"],
        "Wall Ball": ["wall ball", "wall balls"],
        "Farmer Carry": ["farmer carry", "farmers carry", "farmer walk"],
        "Sled Push": ["sled push", "prowler push"],
        "Battle Rope": ["battle rope", "battle ropes"],
        "Row Erg": ["row", "rowing", "erg", "row erg"],
        "Bike Erg": ["bike", "air bike", "assault bike", "bike erg"],
        "Run": ["run", "running", "sprint", "jog"],
        "Walk": ["walk", "walking"],
        "Bear Crawl": ["bear crawl", "bear crawls"],
        "Inchworm": ["inchworm", "inchworms"],
        "Bird Dog": ["bird dog", "bird dogs"],
        "Superman": ["superman", "supermans"],
        "Glute Kickback": ["glute kickback", "kickback"],
        "Clamshell": ["clamshell", "clam shell"],
        "Hip Abduction": ["hip abduction", "abduction"],
        "Hip Adduction": ["hip adduction", "adduction"],
        "Cable Pull Through": ["pull through", "cable pull through"],
        "Nordic Curl": ["nordic curl", "nordic hamstring curl"],
        "Split Jerk": ["split jerk", "jerk"],
        "Push Press": ["push press"],
        "Power Clean": ["power clean", "clean"],
        "Hang Clean": ["hang clean"],
        "Snatch": ["snatch", "power snatch"],
        "Clean and Jerk": ["clean and jerk", "c&j"]
    ]

    private static let ambiguousCatalog: [String: [String]] = [
        "row": ["Barbell Row", "Dumbbell Row", "Seated Cable Row", "Row Erg"],
        "rows": ["Barbell Row", "Dumbbell Row", "Seated Cable Row", "Row Erg"],
        "press": ["Bench Press", "Overhead Press", "Leg Press", "Push Press"],
        "curl": ["Biceps Curl", "Hammer Curl", "Leg Curl"],
        "fly": ["Chest Fly", "Rear Delt Fly"],
        "pulldown": ["Lat Pulldown", "Triceps Pushdown"],
        "raise": ["Lateral Raise", "Front Raise", "Hanging Knee Raise"]
    ]

    private static let canonicalNames: [String] = Array(exerciseCatalog.keys).sorted()

    private static let aliasToCanonical: [String: String] = {
        var mapping: [String: String] = [:]

        for (canonical, aliases) in exerciseCatalog {
            mapping[normalize(canonical)] = canonical
            for alias in aliases {
                mapping[normalize(alias)] = canonical
            }
        }

        return mapping
    }()

    // MARK: - String helpers

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func confidence(distance: Int, input: String, candidate: String) -> Double {
        let baseline = Double(max(input.count, candidate.count, 1))
        let raw = 1.0 - (Double(distance) / baseline)
        return min(max(raw, 0), 1)
    }

    private static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)

        if lhsChars.isEmpty { return rhsChars.count }
        if rhsChars.isEmpty { return lhsChars.count }

        var previous = Array(0...rhsChars.count)
        var current = Array(repeating: 0, count: rhsChars.count + 1)

        for (i, lhsChar) in lhsChars.enumerated() {
            current[0] = i + 1

            for (j, rhsChar) in rhsChars.enumerated() {
                let cost = lhsChar == rhsChar ? 0 : 1
                current[j + 1] = min(
                    current[j] + 1,
                    previous[j + 1] + 1,
                    previous[j] + cost
                )
            }

            swap(&previous, &current)
        }

        return previous[rhsChars.count]
    }
}
