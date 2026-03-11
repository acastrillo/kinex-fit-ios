import Foundation

final class ExerciseLibraryMatcher {

    // MARK: - Types

    struct MatchResolution: Equatable {
        var displayName: String
        var match: CaptionExerciseMatch
    }

    /// Inferred body-part focus of a workout caption, used to disambiguate ambiguous terms
    /// such as "press" (chest vs. shoulders vs. legs) or "row" (back vs. cardio).
    enum BodyPartContext: String, Equatable {
        case chest, back, legs, shoulders, arms, core, cardio, glutes, unspecified

        /// Extract context from the full caption text (heuristic keyword scan).
        static func extract(from text: String) -> BodyPartContext {
            let lowered = text.lowercased()

            if lowered.contains("chest") || lowered.contains("pec") || lowered.contains("bench day") {
                return .chest
            }
            if lowered.contains("back day") || lowered.contains("lats") || lowered.contains("rhomboid") ||
               lowered.contains("pull day") || lowered.contains("back workout") {
                return .back
            }
            if lowered.contains("leg day") || lowered.contains("quad") || lowered.contains("hamstring") ||
               lowered.contains("lower body") || lowered.contains("leg workout") {
                return .legs
            }
            if lowered.contains("shoulder") || lowered.contains("delt") || lowered.contains("push day") ||
               lowered.contains("shoulder day") {
                return .shoulders
            }
            if lowered.contains("arm day") || lowered.contains("bicep") || lowered.contains("tricep") ||
               lowered.contains("arm workout") {
                return .arms
            }
            if lowered.contains("core") || lowered.contains(" abs ") || lowered.contains("ab workout") ||
               lowered.contains("core day") {
                return .core
            }
            if lowered.contains("cardio") || lowered.contains("conditioning") || lowered.contains("hiit") ||
               lowered.contains("hyrox") || lowered.contains("crossfit") || lowered.contains("wod") {
                return .cardio
            }
            if lowered.contains("glute") || lowered.contains("booty") || lowered.contains("posterior") {
                return .glutes
            }
            return .unspecified
        }
    }

    // MARK: - Cache

    private var cache: [String: MatchResolution] = [:]
    private let cacheLock = NSLock()

    // MARK: - Additional catalog (runtime-merged, e.g. from free-exercise-db JSON)

    private let additionalAliases: [String: String]
    private let additionalCanonicalNames: Set<String>

    // MARK: - Init

    /// Create a matcher, optionally merging an external catalog (e.g. from free-exercise-db).
    /// The external catalog uses the same format as the built-in one:
    /// `[canonicalName: [alias, alias, ...]]`.
    init(additionalCatalog: [String: [String]] = [:]) {
        var aliases: [String: String] = [:]
        var canonicals: Set<String> = []

        for (canonical, aliasList) in additionalCatalog {
            let normalizedCanonical = Self.normalize(canonical)
            // Don't override the built-in catalog
            if Self.aliasToCanonical[normalizedCanonical] == nil {
                aliases[normalizedCanonical] = canonical
                canonicals.insert(canonical)
            }
            for alias in aliasList {
                let normalizedAlias = Self.normalize(alias)
                if aliases[normalizedAlias] == nil && Self.aliasToCanonical[normalizedAlias] == nil {
                    aliases[normalizedAlias] = canonical
                }
            }
        }

        self.additionalAliases = aliases
        self.additionalCanonicalNames = canonicals
    }

    // MARK: - Public API

    func matchExercise(name: String, authoritativeHints: [AuthoritativeExerciseHint]) -> CaptionExerciseMatch {
        resolveExercise(name: name, authoritativeHints: authoritativeHints).match
    }

    /// Resolve without body-part context (backward-compatible).
    func resolveExercise(name: String, authoritativeHints: [AuthoritativeExerciseHint]) -> MatchResolution {
        resolveExercise(name: name, authoritativeHints: authoritativeHints, captionContext: .unspecified)
    }

    /// Resolve with body-part context for smarter disambiguation.
    func resolveExercise(
        name: String,
        authoritativeHints: [AuthoritativeExerciseHint],
        captionContext: BodyPartContext
    ) -> MatchResolution {
        let normalized = Self.normalize(name)
        guard !normalized.isEmpty else {
            return MatchResolution(displayName: name, match: .unknown(closestMatches: []))
        }

        let cacheKey = makeCacheKey(normalized: normalized, hints: authoritativeHints, context: captionContext)
        if let cached = cachedValue(for: cacheKey) { return cached }

        let resolution = resolveUncached(
            normalized: normalized,
            originalName: name,
            authoritativeHints: authoritativeHints,
            captionContext: captionContext
        )
        storeCachedValue(resolution, for: cacheKey)
        return resolution
    }

    // MARK: - Core resolution

    private func resolveUncached(
        normalized: String,
        originalName: String,
        authoritativeHints: [AuthoritativeExerciseHint],
        captionContext: BodyPartContext
    ) -> MatchResolution {

        // 1. Authoritative exact match (highest trust)
        if let hintMatch = authoritativeExactMatch(normalized: normalized, hints: authoritativeHints) {
            return MatchResolution(
                displayName: hintMatch.displayName,
                match: .exact(kinexExerciseID: hintMatch.kinexExerciseID)
            )
        }

        // 2. Context-guided disambiguation (resolves ambiguous terms when we know the workout focus)
        if let contextResolution = contextGuidedMatch(
            normalized: normalized,
            context: captionContext,
            hints: authoritativeHints
        ) {
            return contextResolution
        }

        // 3. Ambiguous catalog (requires user selection)
        if let ambiguousOptions = ambiguousOptions(for: normalized, hints: authoritativeHints) {
            return MatchResolution(displayName: originalName, match: .ambiguous(ambiguousOptions))
        }

        // 4. Static built-in alias
        if let canonical = Self.aliasToCanonical[normalized] {
            return MatchResolution(displayName: canonical, match: .exact(kinexExerciseID: nil))
        }

        // 5. Additional (JSON-loaded) alias
        if let canonical = additionalAliases[normalized] {
            return MatchResolution(displayName: canonical, match: .exact(kinexExerciseID: nil))
        }

        // 6. Fuzzy authoritative match
        if let fuzzyAuthoritative = fuzzyAuthoritativeMatch(normalized: normalized, hints: authoritativeHints) {
            return MatchResolution(
                displayName: fuzzyAuthoritative.displayName,
                match: .fuzzy(kinexExerciseID: fuzzyAuthoritative.kinexExerciseID, confidence: fuzzyAuthoritative.confidence)
            )
        }

        // 7. Fuzzy built-in alias
        if let fuzzyLocal = fuzzyLocalMatch(normalized: normalized) {
            return MatchResolution(
                displayName: fuzzyLocal.displayName,
                match: .fuzzy(kinexExerciseID: nil, confidence: fuzzyLocal.confidence)
            )
        }

        // 8. Fuzzy additional (JSON-loaded) alias
        if let fuzzyAdditional = fuzzyAdditionalMatch(normalized: normalized) {
            return MatchResolution(
                displayName: fuzzyAdditional.displayName,
                match: .fuzzy(kinexExerciseID: nil, confidence: fuzzyAdditional.confidence)
            )
        }

        // 9. Unknown — return closest suggestions
        let suggestions = closestMatches(normalized: normalized, hints: authoritativeHints)
        return MatchResolution(displayName: originalName, match: .unknown(closestMatches: suggestions))
    }

    // MARK: - Matching helpers

    private func authoritativeExactMatch(
        normalized: String,
        hints: [AuthoritativeExerciseHint]
    ) -> (kinexExerciseID: String, displayName: String)? {
        for hint in hints {
            if normalized == Self.normalize(hint.displayName) {
                return (hint.kinexExerciseID, hint.displayName)
            }
            if hint.aliases.contains(where: { Self.normalize($0) == normalized }) {
                return (hint.kinexExerciseID, hint.displayName)
            }
        }
        return nil
    }

    /// Returns a context-resolved `.exact` match when the term is ambiguous but context is strong enough.
    private func contextGuidedMatch(
        normalized: String,
        context: BodyPartContext,
        hints: [AuthoritativeExerciseHint]
    ) -> MatchResolution? {
        guard context != .unspecified else { return nil }
        guard Self.ambiguousCatalog[normalized] != nil else { return nil }
        guard let preferences = Self.contextPreferences[normalized],
              let preferredName = preferences[context] else { return nil }

        let kinexID = hints.first(where: { Self.normalize($0.displayName) == Self.normalize(preferredName) })?.kinexExerciseID
        return MatchResolution(displayName: preferredName, match: .exact(kinexExerciseID: kinexID))
    }

    private func ambiguousOptions(
        for normalized: String,
        hints: [AuthoritativeExerciseHint]
    ) -> [CaptionExerciseOption]? {
        guard let baseOptions = Self.ambiguousCatalog[normalized] else { return nil }

        let options: [CaptionExerciseOption] = baseOptions.map { displayName in
            if let hint = hints.first(where: { Self.normalize($0.displayName) == Self.normalize(displayName) }) {
                return CaptionExerciseOption(kinexExerciseID: hint.kinexExerciseID, displayName: hint.displayName)
            }
            return CaptionExerciseOption(kinexExerciseID: nil, displayName: displayName)
        }
        return options.isEmpty ? nil : options
    }

    private func fuzzyAuthoritativeMatch(
        normalized: String,
        hints: [AuthoritativeExerciseHint]
    ) -> (kinexExerciseID: String, displayName: String, confidence: Double)? {
        var best: (distance: Int, confidence: Double, hint: AuthoritativeExerciseHint)?

        for hint in hints {
            for candidate in ([hint.displayName] + hint.aliases) {
                let normalizedCandidate = Self.normalize(candidate)
                guard !normalizedCandidate.isEmpty else { continue }

                let distance = Self.levenshtein(normalized, normalizedCandidate)
                let confidence = Self.confidence(distance: distance, input: normalized, candidate: normalizedCandidate)

                if distance <= 2 {
                    if let current = best {
                        if confidence > current.confidence { best = (distance, confidence, hint) }
                    } else {
                        best = (distance, confidence, hint)
                    }
                }
            }
        }

        guard let best, best.confidence >= 0.72 else { return nil }
        return (kinexExerciseID: best.hint.kinexExerciseID, displayName: best.hint.displayName, confidence: best.confidence)
    }

    private func fuzzyLocalMatch(normalized: String) -> (displayName: String, confidence: Double)? {
        var best: (distance: Int, alias: String, canonical: String)?

        for (alias, canonical) in Self.aliasToCanonical {
            let distance = Self.levenshtein(normalized, alias)
            guard distance <= 2 else { continue }
            if let current = best {
                if distance < current.distance { best = (distance, alias, canonical) }
            } else {
                best = (distance, alias, canonical)
            }
        }

        guard let best else { return nil }
        let confidence = Self.confidence(distance: best.distance, input: normalized, candidate: best.alias)
        guard confidence >= 0.70 else { return nil }
        return (displayName: best.canonical, confidence: confidence)
    }

    private func fuzzyAdditionalMatch(normalized: String) -> (displayName: String, confidence: Double)? {
        var best: (distance: Int, alias: String, canonical: String)?

        for (alias, canonical) in additionalAliases {
            let distance = Self.levenshtein(normalized, alias)
            guard distance <= 2 else { continue }
            if let current = best {
                if distance < current.distance { best = (distance, alias, canonical) }
            } else {
                best = (distance, alias, canonical)
            }
        }

        guard let best else { return nil }
        let confidence = Self.confidence(distance: best.distance, input: normalized, candidate: best.alias)
        guard confidence >= 0.70 else { return nil }
        return (displayName: best.canonical, confidence: confidence)
    }

    private func closestMatches(
        normalized: String,
        hints: [AuthoritativeExerciseHint]
    ) -> [String] {
        var candidates = Set(Self.canonicalNames).union(additionalCanonicalNames)
        for hint in hints { candidates.insert(hint.displayName) }

        let scored = candidates
            .map { ($0, Self.levenshtein(normalized, Self.normalize($0))) }
            .sorted {
                if $0.1 == $1.1 { return $0.0 < $1.0 }
                return $0.1 < $1.1
            }
        return Array(scored.prefix(3).map(\.0))
    }

    // MARK: - Cache

    private func makeCacheKey(
        normalized: String,
        hints: [AuthoritativeExerciseHint],
        context: BodyPartContext = .unspecified
    ) -> String {
        let hintsKey = hints
            .map { "\($0.kinexExerciseID):\(Self.normalize($0.displayName))" }
            .sorted()
            .joined(separator: ",")
        return "\(normalized)|\(hintsKey)|\(context.rawValue)"
    }

    private func cachedValue(for key: String) -> MatchResolution? {
        cacheLock.lock(); defer { cacheLock.unlock() }
        return cache[key]
    }

    private func storeCachedValue(_ value: MatchResolution, for key: String) {
        cacheLock.lock(); defer { cacheLock.unlock() }
        cache[key] = value
    }

    // MARK: - Static catalog

    // swiftlint:disable line_length
    private static let exerciseCatalog: [String: [String]] = [

        // ──────────────────────────────────────────────────────────────────────────────
        // LOWER BODY — QUADS
        // ──────────────────────────────────────────────────────────────────────────────
        "Air Squat": ["squat", "squats", "bodyweight squat", "body weight squat", "air squat", "air squats", "bw squat"],
        "Barbell Back Squat": ["barbell squat", "back squat", "bb squat", "high bar squat", "low bar squat",
                               "hb squat", "lb squat", "pause squat", "tempo squat", "barbell back squat"],
        "Front Squat": ["front squat", "barbell front squat", "fs"],
        "Goblet Squat": ["goblet squat", "db goblet squat", "goblet squats", "kettle bell goblet"],
        "Bulgarian Split Squat": ["bulgarian split squat", "bss", "rear foot elevated split squat", "rfess",
                                  "bulgarians", "split squats", "db bulgarian", "barbell bulgarian"],
        "Split Squat": ["split squat", "dumbbell split squat", "db split squat"],
        "Hack Squat": ["hack squat", "machine squat", "hack squats"],
        "Box Squat": ["box squat", "box squats", "paused box squat"],
        "Sissy Squat": ["sissy squat", "sissy squats"],
        "Zercher Squat": ["zercher squat", "zercher squats"],
        "Safety Bar Squat": ["safety bar squat", "ssb squat", "safety squat", "ssb"],
        "Walking Lunge": ["walking lunge", "walking lunges", "db walking lunge", "barbell lunge"],
        "Reverse Lunge": ["reverse lunge", "reverse lunges", "db reverse lunge", "step back lunge"],
        "Lateral Lunge": ["lateral lunge", "side lunge", "lateral lunges", "side lunge"],
        "Curtsy Lunge": ["curtsy lunge", "curtsy lunges"],
        "Step-Up": ["step up", "step-up", "stepups", "step ups", "db step up", "barbell step up", "step-ups"],

        // ──────────────────────────────────────────────────────────────────────────────
        // LOWER BODY — POSTERIOR CHAIN
        // ──────────────────────────────────────────────────────────────────────────────
        "Hip Thrust": ["hip thrust", "barbell hip thrust", "hip thrusts", "banded hip thrust",
                       "smith machine hip thrust", "db hip thrust", "glute thrust"],
        "Glute Bridge": ["glute bridge", "bridges", "single leg glute bridge", "banded glute bridge", "glute bridges"],
        "Romanian Deadlift": ["romanian deadlift", "rdl", "rdls", "rom deadlift", "db rdl", "dumbbell rdl",
                              "single leg rdl", "sl rdl", "b stance rdl", "staggered stance rdl", "hip hinge"],
        "Deadlift": ["deadlift", "deadlifts", "conventional deadlift", "deads", "conventional dl",
                     "dl", "barbell deadlift", "trap bar deadlift"],
        "Sumo Deadlift": ["sumo deadlift", "sumo dl", "sumo deads", "wide stance deadlift"],
        "Trap Bar Deadlift": ["trap bar deadlift", "hex bar deadlift", "trap bar dl", "hex bar dl",
                              "hex bar", "trap bar"],
        "Stiff Leg Deadlift": ["stiff leg deadlift", "sldl", "stiff legged deadlift", "straight leg deadlift",
                               "straight leg dl"],
        "Deficit Deadlift": ["deficit deadlift", "deficit dl", "deficit deads"],
        "Single Leg Deadlift": ["single leg deadlift", "sl deadlift", "single leg dl", "single leg hip hinge"],
        "Good Morning": ["good morning", "good mornings", "barbell good morning"],
        "Nordic Curl": ["nordic curl", "nordic hamstring curl", "nh curl", "nordic hamstring",
                        "natural glute ham", "natural leg curl", "nordic", "ham curl nordic"],
        "Glute Ham Raise": ["glute ham raise", "ghr", "natural ghr", "glute ham developer"],
        "Reverse Hyper": ["reverse hyper", "reverse hyperextension"],
        "Back Extension": ["back extension", "back extensions", "45 degree back extension", "hyperextension",
                           "hypers", "roman chair"],
        "Cable Pull Through": ["pull through", "cable pull through", "cable pull-through"],

        // ──────────────────────────────────────────────────────────────────────────────
        // LOWER BODY — MACHINES & ISOLATION
        // ──────────────────────────────────────────────────────────────────────────────
        "Leg Press": ["leg press", "leg presses", "45 degree leg press", "machine leg press"],
        "Leg Extension": ["leg extension", "extensions", "leg extensions", "quad extension", "knee extension"],
        "Leg Curl": ["leg curl", "hamstring curl", "ham curls", "prone leg curl", "seated leg curl",
                     "lying leg curl", "ham curl"],
        "Calf Raise": ["calf raise", "calf raises", "standing calf raise", "seated calf raise",
                       "donkey calf raise", "calf raises standing"],
        "Hip Abduction": ["hip abduction", "abduction", "cable hip abduction", "machine hip abduction",
                          "hip abductor"],
        "Hip Adduction": ["hip adduction", "adduction", "cable hip adduction", "machine hip adduction",
                          "hip adductor", "inner thigh"],

        // ──────────────────────────────────────────────────────────────────────────────
        // UPPER BODY — CHEST
        // ──────────────────────────────────────────────────────────────────────────────
        "Bench Press": ["bench", "bench press", "bb bench", "barbell bench", "flat bench",
                        "bb bench press", "barbell bench press", "pause bench", "spoto press"],
        "Incline Bench Press": ["incline bench", "incline bench press", "incline bb bench",
                                "incline barbell bench"],
        "Decline Bench Press": ["decline bench press", "decline bench", "decline bb bench"],
        "Dumbbell Bench Press": ["db bench", "dumbbell bench", "dumbbell bench press",
                                 "flat db press", "db flat bench"],
        "Incline Dumbbell Press": ["incline dumbbell press", "incline db press", "incline db bench",
                                   "incline db"],
        "Decline Dumbbell Press": ["decline dumbbell press", "decline db press"],
        "Close Grip Bench Press": ["close grip bench press", "cgbp", "close grip bench",
                                   "narrow grip bench", "close grip bp"],
        "Floor Press": ["floor press", "barbell floor press", "db floor press", "dumbbell floor press"],
        "Push-Up": ["push up", "pushups", "push-up", "push ups", "push-ups", "bodyweight push up"],
        "Diamond Push-Up": ["diamond push up", "diamond pushup", "close grip push up",
                            "tricep push up", "triangle push up"],
        "Pike Push-Up": ["pike push up", "pike pushup", "pike push-up"],
        "Decline Push-Up": ["decline push up", "decline pushup"],
        "Handstand Push-Up": ["handstand push up", "handstand pushup", "hspu", "wall handstand push up"],
        "Ring Push-Up": ["ring push up", "ring pushup"],
        "Chest Fly": ["chest fly", "pec fly", "fly", "cable chest fly", "dumbbell fly",
                      "cable fly", "pec deck", "machine fly"],
        "Incline Dumbbell Fly": ["incline fly", "incline dumbbell fly", "incline db fly",
                                 "incline chest fly"],
        "Dumbbell Pullover": ["dumbbell pullover", "db pullover", "pullover", "straight arm pullover"],
        "Dip": ["dip", "dips", "tricep dip", "parallel bar dip", "chest dip", "weighted dip", "ring dip"],

        // ──────────────────────────────────────────────────────────────────────────────
        // UPPER BODY — SHOULDERS
        // ──────────────────────────────────────────────────────────────────────────────
        "Overhead Press": ["overhead press", "ohp", "shoulder press", "military press", "strict press",
                           "standing press", "bb ohp", "barbell ohp", "seated ohp", "seated barbell press",
                           "press overhead", "standing ohp"],
        "Dumbbell Shoulder Press": ["db shoulder press", "dumbbell shoulder press", "seated db press",
                                    "seated dumbbell press"],
        "Arnold Press": ["arnold press", "arnolds"],
        "Z-Press": ["z press", "z-press", "floor ohp", "seated floor press"],
        "Landmine Press": ["landmine press", "landmine shoulder press", "landmine push press"],
        "Push Press": ["push press", "push presses", "barbell push press"],
        "Behind the Neck Press": ["behind the neck press", "btn press", "btn ohp", "btn"],
        "Lateral Raise": ["lateral raise", "side raise", "lateral raises", "db lateral raise",
                          "cable lateral raise", "machine lateral raise", "lat raise",
                          "side lateral raise", "side lateral", "cable side raise"],
        "Front Raise": ["front raise", "front raises", "db front raise", "cable front raise",
                        "plate front raise"],
        "Rear Delt Fly": ["rear delt fly", "reverse fly", "rear fly", "bent over fly",
                          "cable rear delt fly", "machine rear delt", "pec deck reverse",
                          "rear delt raise", "bent over rear delt"],
        "Band Pull-Apart": ["band pull apart", "band pull-apart", "bpa", "band pull aparts"],
        "Face Pull": ["face pull", "face pulls", "rope face pull", "cable face pull"],
        "Upright Row": ["upright row", "upright rows", "bb upright row", "db upright row",
                        "cable upright row"],
        "Cuban Press": ["cuban press", "cuban rotation", "shoulder horn"],
        "External Rotation": ["external rotation", "cable external rotation",
                              "band external rotation", "er rotation"],
        "Shrug": ["shrug", "shrugs", "barbell shrug", "dumbbell shrug", "db shrug", "trap shrug"],

        // ──────────────────────────────────────────────────────────────────────────────
        // UPPER BODY — BACK
        // ──────────────────────────────────────────────────────────────────────────────
        "Pull-Up": ["pull up", "pull-up", "pullups", "pull ups", "bodyweight pull up",
                    "weighted pull up", "wide grip pull up", "neutral grip pull up",
                    "overhand pull up"],
        "Chin-Up": ["chin up", "chin-up", "chinups", "chin ups", "bodyweight chin up",
                    "weighted chin up", "supinated pull up", "underhand pull up"],
        "Muscle-Up": ["muscle up", "muscle-up", "ring muscle up", "bar muscle up"],
        "Lat Pulldown": ["lat pulldown", "pull down", "pulldown", "cable pulldown",
                         "wide grip pulldown", "close grip pulldown", "straight arm pulldown",
                         "lat pull down"],
        "Barbell Row": ["barbell row", "bent over row", "bb row", "bb bent over row",
                        "yates row", "overhand row", "pronated row", "pendlay row",
                        "barbell bent over row", "bent over barbell row"],
        "Dumbbell Row": ["dumbbell row", "db row", "one arm row", "single arm row",
                         "db bent over row", "meadows row", "kroc row",
                         "single arm dumbbell row"],
        "Seated Cable Row": ["cable row", "seated row", "machine row", "cable seated row",
                             "close grip row", "wide grip cable row", "low cable row"],
        "T-Bar Row": ["t bar row", "t-bar row", "landmine row", "tbar row",
                      "t bar bent over row"],
        "Chest Supported Row": ["chest supported row", "chest supported dumbbell row",
                                "incline row", "chest supported db row", "prone row"],
        "Inverted Row": ["inverted row", "body row", "trx row", "ring row",
                         "horizontal pull up", "bodyweight row"],
        "Seal Row": ["seal row", "prone barbell row"],
        "Straight Arm Pulldown": ["straight arm pulldown", "straight arm pull down", "lat prayer",
                                  "cable straight arm"],

        // ──────────────────────────────────────────────────────────────────────────────
        // UPPER BODY — BICEPS
        // ──────────────────────────────────────────────────────────────────────────────
        "Biceps Curl": ["bicep curl", "biceps curl", "curl", "curls", "bb curl", "barbell curl",
                        "ez bar curl", "ez curl", "dumbbell curl", "db curl", "standing curl",
                        "standing bb curl"],
        "Hammer Curl": ["hammer curl", "hammer curls", "neutral grip curl", "cross body curl",
                        "cross body hammer curl"],
        "Preacher Curl": ["preacher curl", "preacher curls", "scott curl", "machine curl",
                          "ez preacher curl"],
        "Concentration Curl": ["concentration curl", "concentration curls"],
        "Cable Curl": ["cable curl", "cable bicep curl"],
        "Reverse Curl": ["reverse curl", "reverse barbell curl", "reverse ez bar curl"],
        "Zottman Curl": ["zottman curl", "zottmans", "zottman"],
        "Incline Dumbbell Curl": ["incline curl", "incline dumbbell curl", "incline db curl"],

        // ──────────────────────────────────────────────────────────────────────────────
        // UPPER BODY — TRICEPS
        // ──────────────────────────────────────────────────────────────────────────────
        "Triceps Pushdown": ["tricep pushdown", "triceps pushdown", "pushdown", "rope pushdown",
                             "cable pushdown", "bar pushdown", "v-bar pushdown", "v bar pushdown",
                             "tricep cable pushdown"],
        "Skull Crusher": ["skull crusher", "lying triceps extension", "jhc",
                          "ez bar skull crusher", "skull crushers"],
        "Overhead Triceps Extension": ["overhead tricep extension", "overhead triceps extension",
                                       "cable overhead tricep", "db overhead tricep",
                                       "french press", "seated french press", "ote"],
        "Tricep Kickback": ["tricep kickback", "triceps kickback", "dumbbell kickback",
                            "db kickback"],
        "JM Press": ["jm press"],
        "Tate Press": ["tate press"],

        // ──────────────────────────────────────────────────────────────────────────────
        // CORE
        // ──────────────────────────────────────────────────────────────────────────────
        "Plank": ["plank", "front plank", "planks", "plank hold", "forearm plank"],
        "Side Plank": ["side plank", "side planks"],
        "Hollow Hold": ["hollow hold", "hollow body", "hollow body hold"],
        "Hollow Rock": ["hollow rock", "hollow body rock"],
        "Dead Bug": ["dead bug", "dead bugs"],
        "Mountain Climber": ["mountain climber", "mountain climbers"],
        "Russian Twist": ["russian twist", "russian twists", "weighted russian twist"],
        "Sit-Up": ["sit up", "sit-up", "situps", "sit-ups", "ghr sit up"],
        "Crunch": ["crunch", "crunches", "cable crunch", "machine crunch"],
        "Bicycle Crunch": ["bicycle crunch", "bicycle crunches", "bike crunch"],
        "Hanging Knee Raise": ["hanging knee raise", "knee raise", "hanging knee"],
        "Hanging Leg Raise": ["hanging leg raise", "hinging leg raise", "leg lift"],
        "Toes to Bar": ["toes to bar", "toes-to-bar", "ttb", "t2b", "knees to chest"],
        "Ab Wheel Rollout": ["ab wheel", "ab rollout", "wheel rollout", "ab wheel rollout",
                             "ab roller"],
        "V-Up": ["v up", "v-up", "v ups"],
        "L-Sit": ["l sit", "l-sit"],
        "Dragon Flag": ["dragon flag", "dragon flags"],
        "Cable Crunch": ["cable crunch", "kneeling cable crunch"],
        "Pallof Press": ["pallof press", "anti rotation press", "anti-rotation press",
                         "cable anti rotation"],
        "Wood Chop": ["wood chop", "cable woodchop", "cable chop", "cable wood chop",
                      "rotational woodchop"],
        "Copenhagen Adductor Plank": ["copenhagen plank", "copenhagen", "copenhagen adductor",
                                      "cop plank", "copenhagen hip adduction", "copen plank"],
        "Jefferson Curl": ["jefferson curl", "jefferson curls"],
        "Bird Dog": ["bird dog", "bird dogs"],
        "Superman": ["superman", "supermans", "back extension hold"],
        "Glute Kickback": ["glute kickback", "kickback", "cable kickback", "donkey kick"],
        "Clamshell": ["clamshell", "clam shell", "clamshells", "banded clamshell"],

        // ──────────────────────────────────────────────────────────────────────────────
        // CARDIO & CONDITIONING
        // ──────────────────────────────────────────────────────────────────────────────
        "Burpee": ["burpee", "burpees", "burpee pull up", "no push up burpee"],
        "Burpee Broad Jump": ["burpee broad jump", "burpee to broad jump", "burpee long jump"],
        "Jumping Jack": ["jumping jack", "jumping jacks", "star jump", "star jumps"],
        "High Knees": ["high knees", "high knee", "running high knees", "running man"],
        "Jump Rope": ["jump rope", "skipping", "double under", "single under", "du",
                      "double unders", "jump rope skipping"],
        "Box Jump": ["box jump", "box jumps", "step up box jump"],
        "Broad Jump": ["broad jump", "broad jumps", "standing broad jump", "standing long jump"],
        "Sprint": ["sprint", "sprints", "100m", "200m", "400m", "200 meter", "400 meter",
                   "100 meter"],
        "Run": ["run", "running", "jog", "jogging", "1km run", "1 mile run", "400m run"],
        "Walk": ["walk", "walking"],
        "Row Erg": ["row", "rowing", "erg", "row erg", "concept2", "c2 rower",
                    "rowing machine", "rower", "erging", "500m row", "1000m row"],
        "Bike Erg": ["bike", "air bike", "assault bike", "bike erg", "echo bike",
                     "airdyne", "concept2 bike"],
        "Ski Erg": ["ski erg", "skierg", "ski ergometer", "concept2 ski", "c2 ski",
                    "skiing erg", "ski machine", "1000m ski", "500m ski"],
        "Sled Push": ["sled push", "prowler push", "sled sprint", "prowler sled",
                      "sled pushing", "prowler"],
        "Sled Pull": ["sled pull", "sled drag", "sled dragging", "prowler pull"],
        "Battle Rope": ["battle rope", "battle ropes", "rope slams"],

        // ──────────────────────────────────────────────────────────────────────────────
        // FUNCTIONAL & KETTLEBELL
        // ──────────────────────────────────────────────────────────────────────────────
        "Kettlebell Swing": ["kettlebell swing", "kb swing", "kettlebell swings", "american swing",
                             "russian swing", "american kb swing", "kb swings"],
        "Thruster": ["thruster", "thrusters", "barbell thruster", "db thruster",
                     "dumbbell thruster"],
        "Wall Ball": ["wall ball", "wall balls", "wall ball shot", "wall balls shot"],
        "Farmer Carry": ["farmer carry", "farmers carry", "farmer walk", "farmers walk",
                         "dumbbell carry", "kettlebell carry", "dual carry"],
        "Suitcase Carry": ["suitcase carry", "single arm carry", "suitcase walk",
                           "single arm farmer carry"],
        "Sandbag Lunge": ["sandbag lunge", "sandbag lunges", "sandbag carry lunge"],
        "Bear Crawl": ["bear crawl", "bear crawls"],
        "Inchworm": ["inchworm", "inchworms", "inchworm walkout", "walk out"],
        "Turkish Get-Up": ["turkish get up", "tgu", "kettlebell get up", "turkish getup"],

        // ──────────────────────────────────────────────────────────────────────────────
        // OLYMPIC LIFTS
        // ──────────────────────────────────────────────────────────────────────────────
        "Split Jerk": ["split jerk", "jerk", "barbell split jerk"],
        "Power Clean": ["power clean", "clean", "pc", "barbell clean"],
        "Hang Clean": ["hang clean", "barbell hang clean"],
        "Hang Power Clean": ["hang power clean", "hpc"],
        "Snatch": ["snatch", "power snatch", "squat snatch", "barbell snatch"],
        "Clean and Jerk": ["clean and jerk", "c&j", "cj"],
        "Hang Snatch": ["hang snatch"],
        "Clean Pull": ["clean pull"],
        "Snatch Pull": ["snatch pull"],

        // ──────────────────────────────────────────────────────────────────────────────
        // MOBILITY & ACCESSORY
        // ──────────────────────────────────────────────────────────────────────────────
        "Hip Circle": ["hip circle", "hip circles", "hip rotation"],
        "Deep Squat Hold": ["deep squat hold", "squat hold", "deep squat", "asian squat hold"],
        "Knee Hug": ["knee hug", "knee hugs", "single knee hug"],
        "Hip Flexor Stretch": ["hip flexor stretch", "hip flexor", "lunge stretch"],
        "Cat-Cow": ["cat cow", "cat-cow", "cat camel"],
        "World's Greatest Stretch": ["worlds greatest stretch", "world's greatest stretch", "wgs"],
    ]
    // swiftlint:enable line_length

    /// Terms that map to multiple exercises and require disambiguation.
    private static let ambiguousCatalog: [String: [String]] = [
        "row": ["Barbell Row", "Dumbbell Row", "Seated Cable Row", "Row Erg"],
        "rows": ["Barbell Row", "Dumbbell Row", "Seated Cable Row", "Row Erg"],
        "press": ["Bench Press", "Overhead Press", "Leg Press", "Push Press"],
        "curl": ["Biceps Curl", "Hammer Curl", "Leg Curl"],
        "fly": ["Chest Fly", "Rear Delt Fly"],
        "pulldown": ["Lat Pulldown", "Triceps Pushdown"],
        "raise": ["Lateral Raise", "Front Raise", "Hanging Leg Raise"],
        "extension": ["Leg Extension", "Overhead Triceps Extension"],
        "kickback": ["Glute Kickback", "Tricep Kickback"],
        "lunge": ["Walking Lunge", "Reverse Lunge", "Lateral Lunge"],
        "pull": ["Pull-Up", "Lat Pulldown", "Barbell Row"],
    ]

    /// When a term is ambiguous but context is known, prefer a specific exercise.
    private static let contextPreferences: [String: [BodyPartContext: String]] = [
        "press": [
            .chest: "Bench Press",
            .shoulders: "Overhead Press",
            .legs: "Leg Press",
        ],
        "row": [
            .back: "Barbell Row",
            .cardio: "Row Erg",
        ],
        "rows": [
            .back: "Barbell Row",
            .cardio: "Row Erg",
        ],
        "curl": [
            .legs: "Leg Curl",
            .arms: "Biceps Curl",
        ],
        "fly": [
            .chest: "Chest Fly",
            .back: "Rear Delt Fly",
            .shoulders: "Rear Delt Fly",
        ],
        "raise": [
            .shoulders: "Lateral Raise",
            .legs: "Hanging Leg Raise",
            .back: "Hanging Leg Raise",
        ],
        "pulldown": [
            .back: "Lat Pulldown",
            .arms: "Triceps Pushdown",
        ],
        "extension": [
            .legs: "Leg Extension",
            .arms: "Overhead Triceps Extension",
        ],
        "kickback": [
            .glutes: "Glute Kickback",
            .arms: "Tricep Kickback",
        ],
        "lunge": [
            .legs: "Walking Lunge",
            .glutes: "Reverse Lunge",
        ],
        "pull": [
            .back: "Pull-Up",
        ],
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

    static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func confidence(distance: Int, input: String, candidate: String) -> Double {
        let baseline = Double(max(input.count, candidate.count, 1))
        return min(max(1.0 - (Double(distance) / baseline), 0), 1)
    }

    private static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let lhsChars = Array(lhs), rhsChars = Array(rhs)
        if lhsChars.isEmpty { return rhsChars.count }
        if rhsChars.isEmpty { return lhsChars.count }

        var previous = Array(0...rhsChars.count)
        var current = Array(repeating: 0, count: rhsChars.count + 1)

        for (i, lhsChar) in lhsChars.enumerated() {
            current[0] = i + 1
            for (j, rhsChar) in rhsChars.enumerated() {
                let cost = lhsChar == rhsChar ? 0 : 1
                current[j + 1] = min(current[j] + 1, previous[j + 1] + 1, previous[j] + cost)
            }
            swap(&previous, &current)
        }
        return previous[rhsChars.count]
    }
}
