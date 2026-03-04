import Foundation

struct CaptionParser {
    func parseCaptionText(_ caption: String) -> CaptionParseDraft {
        let normalizedCaption = caption
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedCaption.isEmpty else {
            return CaptionParseDraft(
                title: "Instagram Workout",
                exercises: [],
                restBetweenSets: nil,
                rounds: nil,
                unparsedLines: [],
                confidence: 0,
                notes: nil
            )
        }

        let rawLines = normalizedCaption
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var exercises: [CaptionDraftExercise] = []
        var unparsedLines: [CaptionUnparsedLine] = []
        var notes: [String] = []
        var restBetweenSets: String?
        var rounds: Int?

        var meaningfulLineCount = 0
        var parsedLineCount = 0
        var candidateTitle: String?

        for rawLine in rawLines {
            let line = normalizeLine(rawLine)
            guard !line.isEmpty else { continue }

            if rounds == nil {
                rounds = parseRounds(in: line)
            }

            if isNoiseLine(line) {
                continue
            }

            if let restValue = parseRest(in: line) {
                restBetweenSets = restBetweenSets ?? restValue
                meaningfulLineCount += 1
                continue
            }

            if let parsedExercise = parseExercise(from: line, position: exercises.count + 1) {
                exercises.append(parsedExercise)
                parsedLineCount += 1
                meaningfulLineCount += 1
                continue
            }

            let hasParsedWorkoutContent = !exercises.isEmpty || parsedLineCount > 0 || restBetweenSets != nil
            if candidateTitle == nil && !hasParsedWorkoutContent && isLikelyTitle(line) {
                candidateTitle = sanitizeTitle(line)
                continue
            }

            meaningfulLineCount += 1
            if shouldPreserveAsNote(line) {
                notes.append(line)
            }
            unparsedLines.append(
                CaptionUnparsedLine(
                    text: line,
                    reason: "Unsupported exercise format"
                )
            )
        }

        let title = sanitizeTitle(candidateTitle ?? inferFallbackTitle(from: rawLines))
        let denominator = max(meaningfulLineCount, 1)
        var confidence = Double(parsedLineCount) / Double(denominator)

        if !unparsedLines.isEmpty {
            confidence -= min(Double(unparsedLines.count) * 0.05, 0.25)
        }
        if exercises.isEmpty {
            confidence = 0
        }

        return CaptionParseDraft(
            title: title,
            exercises: exercises,
            restBetweenSets: restBetweenSets,
            rounds: rounds,
            unparsedLines: unparsedLines,
            confidence: min(max(confidence, 0), 1),
            notes: notes.isEmpty ? nil : notes.joined(separator: "\n")
        )
    }

    // MARK: - Parsing

    private func parseExercise(from line: String, position: Int) -> CaptionDraftExercise? {
        if let captures = capture(in: line, with: Patterns.leadingSetsReps),
           let sets = Int(captures[0]),
           let reps = Int(captures[1]) {
            let name = sanitizeExerciseName(captures[2])
            guard isReasonableExerciseName(name) else { return nil }

            return CaptionDraftExercise(
                sets: sets,
                reps: reps,
                duration: nil,
                name: name,
                notes: nil,
                position: position
            )
        }

        if let captures = capture(in: line, with: Patterns.trailingSetsReps),
           let sets = Int(captures[1]),
           let reps = Int(captures[2]) {
            let name = sanitizeExerciseName(captures[0])
            guard isReasonableExerciseName(name) else { return nil }

            return CaptionDraftExercise(
                sets: sets,
                reps: reps,
                duration: nil,
                name: name,
                notes: nil,
                position: position
            )
        }

        if let captures = capture(in: line, with: Patterns.leadingDuration),
           let rawValue = Int(captures[0]) {
            let duration = normalizeDuration(rawValue, unit: captures[1])
            let name = sanitizeExerciseName(captures[2])
            guard duration > 0, isReasonableExerciseName(name) else { return nil }

            return CaptionDraftExercise(
                sets: nil,
                reps: nil,
                duration: duration,
                name: name,
                notes: nil,
                position: position
            )
        }

        if let captures = capture(in: line, with: Patterns.trailingDuration),
           let rawValue = Int(captures[1]) {
            let duration = normalizeDuration(rawValue, unit: captures[2])
            let name = sanitizeExerciseName(captures[0])
            guard duration > 0, isReasonableExerciseName(name) else { return nil }

            return CaptionDraftExercise(
                sets: nil,
                reps: nil,
                duration: duration,
                name: name,
                notes: nil,
                position: position
            )
        }

        return nil
    }

    private func parseRest(in line: String) -> String? {
        if let captures = capture(in: line, with: Patterns.leadingRest),
           let value = Int(captures[0]) {
            return normalizedTime(value: value, unit: captures[1])
        }

        if let captures = capture(in: line, with: Patterns.trailingRest),
           let value = Int(captures[0]) {
            return normalizedTime(value: value, unit: captures[1])
        }

        return nil
    }

    private func parseRounds(in line: String) -> Int? {
        if let captures = capture(in: line, with: Patterns.rounds),
           let value = Int(captures[0]), value > 0 {
            return value
        }

        if let captures = capture(in: line, with: Patterns.repeatTimes),
           let value = Int(captures[0]), value > 0 {
            return value
        }

        return nil
    }

    // MARK: - Normalization

    private func normalizeLine(_ line: String) -> String {
        var output = line
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        output = output.replacingOccurrences(of: Patterns.leadingListPrefix, with: "", options: .regularExpression)
        output = output.replacingOccurrences(of: Patterns.leadingEmojiPrefix, with: "", options: .regularExpression)
        output = output.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sanitizeExerciseName(_ rawName: String) -> String {
        rawName
            .replacingOccurrences(of: #"\([^)]*\)$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " .,:;-_").union(.whitespacesAndNewlines))
    }

    private func normalizeDuration(_ value: Int, unit: String) -> Int {
        let lowered = unit.lowercased()
        if lowered.hasPrefix("m") {
            return value * 60
        }
        return value
    }

    private func normalizedTime(value: Int, unit: String) -> String {
        let lowered = unit.lowercased()
        if lowered.hasPrefix("m") {
            return "\(value) min"
        }
        return "\(value)s"
    }

    private func inferFallbackTitle(from lines: [String]) -> String {
        for line in lines {
            let normalized = normalizeLine(line)
            guard !normalized.isEmpty else { continue }
            if isLikelyTitle(normalized) {
                return sanitizeTitle(normalized)
            }
        }
        return "Instagram Workout"
    }

    private func sanitizeTitle(_ rawTitle: String) -> String {
        let trimmed = rawTitle
            .replacingOccurrences(of: #"[\p{So}\p{Sk}\p{Sm}\p{Sc}]+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Instagram Workout" : trimmed
    }

    // MARK: - Heuristics

    private func isNoiseLine(_ line: String) -> Bool {
        let lowered = line.lowercased()

        if lowered.contains("http://") || lowered.contains("https://") || lowered.contains("www.") {
            return true
        }
        if lowered.hasPrefix("#") || lowered.contains(" #") {
            return true
        }
        if lowered.hasPrefix("@") {
            return true
        }
        if lowered.range(of: Patterns.ctaKeywords, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    private func isLikelyTitle(_ line: String) -> Bool {
        let lowered = line.lowercased()
        if lowered.hasSuffix(":") { return false }
        if lowered.range(of: Patterns.exerciseMarker, options: .regularExpression) != nil {
            return false
        }

        let wordCount = line.split(separator: " ").count
        return wordCount >= 2 && wordCount <= 7 && line.contains(where: { $0.isLetter })
    }

    private func shouldPreserveAsNote(_ line: String) -> Bool {
        let wordCount = line.split(separator: " ").count
        return wordCount <= 14
    }

    private func isReasonableExerciseName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        guard name.count <= 80 else { return false }
        guard name.contains(where: { $0.isLetter }) else { return false }

        let lowered = name.lowercased()
        if lowered.range(of: Patterns.ctaKeywords, options: .regularExpression) != nil {
            return false
        }

        return true
    }

    // MARK: - Regex

    private func capture(in source: String, with regex: NSRegularExpression) -> [String]? {
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        guard let match = regex.firstMatch(in: source, options: [], range: range) else {
            return nil
        }

        var values: [String] = []
        for idx in 1..<match.numberOfRanges {
            let nsRange = match.range(at: idx)
            guard let swiftRange = Range(nsRange, in: source) else {
                values.append("")
                continue
            }
            values.append(String(source[swiftRange]))
        }

        return values
    }

    private enum Patterns {
        static let leadingSetsReps = try! NSRegularExpression(
            pattern: #"(?i)^\s*(\d{1,2})\s*(?:sets?)?\s*[x×]\s*(\d{1,3})\s*(?:reps?)?\s+(.+)$"#
        )

        static let trailingSetsReps = try! NSRegularExpression(
            pattern: #"(?i)^(.+?)\s+(\d{1,2})\s*(?:sets?)?\s*[x×]\s*(\d{1,3})\s*(?:reps?)?\s*$"#
        )

        static let leadingDuration = try! NSRegularExpression(
            pattern: #"(?i)^\s*(\d{1,3})\s*(s|sec|secs|second|seconds|min|mins|minute|minutes)\s+(.+)$"#
        )

        static let trailingDuration = try! NSRegularExpression(
            pattern: #"(?i)^(.+?)\s*(?:-|–|:)?\s*(\d{1,3})\s*(s|sec|secs|second|seconds|min|mins|minute|minutes)\s*$"#
        )

        static let leadingRest = try! NSRegularExpression(
            pattern: #"(?i)\b(?:rest|wait|pause|break)\b[^0-9]{0,12}(\d{1,3})\s*(s|sec|secs|second|seconds|min|mins|minute|minutes)\b"#
        )

        static let trailingRest = try! NSRegularExpression(
            pattern: #"(?i)\b(\d{1,3})\s*(s|sec|secs|second|seconds|min|mins|minute|minutes)\s*(?:rest|wait|pause|break)\b"#
        )

        static let rounds = try! NSRegularExpression(
            pattern: #"(?i)\b(\d{1,2})\s*rounds?\b"#
        )

        static let repeatTimes = try! NSRegularExpression(
            pattern: #"(?i)\brepeat\s+(\d{1,2})\s*x\b"#
        )

        static let ctaKeywords = #"(?i)\b(?:follow|comment|tag|share|subscribe|save this|link in bio|dm)\b"#
        static let exerciseMarker = #"(?i)(?:\d\s*[x×]\s*\d|\d+\s*(?:sec|min)|\bsets?\b|\breps?\b|\brest\b)"#

        static let leadingListPrefix = #"^\s*(?:\d+\s*[\.)-]\s*|\d+️⃣\s*|[\-*•●▪︎▫︎]+\s*)"#
        static let leadingEmojiPrefix = #"^\s*[\p{So}\p{Sk}\p{Sm}\p{Sc}]+\s*"#
    }
}
