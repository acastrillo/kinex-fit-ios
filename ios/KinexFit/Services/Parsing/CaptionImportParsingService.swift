import Foundation
import OSLog

private let captionParserLogger = Logger(subsystem: "com.kinex.fit", category: "CaptionImportParsing")

final class CaptionImportParsingService {
    private let parser: CaptionParser
    private let matcher: ExerciseLibraryMatcher
    private let instagramFetchService: InstagramFetchService?
    private let backendTimeoutNanoseconds: UInt64

    init(
        apiClient: APIClient? = nil,
        parser: CaptionParser = CaptionParser(),
        matcher: ExerciseLibraryMatcher = ExerciseLibraryMatcher(),
        backendTimeoutNanoseconds: UInt64 = 450_000_000
    ) {
        self.parser = parser
        self.matcher = matcher
        self.instagramFetchService = apiClient.map { InstagramFetchService(apiClient: $0) }
        self.backendTimeoutNanoseconds = backendTimeoutNanoseconds
    }

    func parseImportText(_ text: String, sourceURL: String?) async -> CaptionParsedWorkout {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceType = inferredSourceType(from: sourceURL)

        guard !normalizedText.isEmpty else {
            return CaptionParsedWorkout(
                sourceType: sourceType,
                sourceURL: sourceURL,
                title: defaultTitle(for: sourceType),
                exercises: [],
                restBetweenSets: nil,
                notes: nil,
                parsingConfidence: 0,
                unparsedLines: [],
                rounds: nil
            )
        }

        let localDraft = parser.parseCaptionText(normalizedText)
        let localParsed = buildParsedWorkout(
            from: localDraft,
            sourceType: sourceType,
            sourceURL: sourceURL,
            authoritativeHints: []
        )

        guard let instagramFetchService else {
            return localParsed
        }

        guard let ingestResponse = await parseCaptionWithTimeout(
            service: instagramFetchService,
            caption: normalizedText,
            sourceURL: sourceURL
        ) else {
            return localParsed
        }

        let authoritativeHints = extractAuthoritativeHints(from: ingestResponse)
        guard !authoritativeHints.isEmpty else {
            return localParsed
        }

        let enrichedParsed = buildParsedWorkout(
            from: localDraft,
            sourceType: sourceType,
            sourceURL: sourceURL,
            authoritativeHints: authoritativeHints
        )

        if shouldUseEnriched(localParsed: localParsed, enrichedParsed: enrichedParsed) {
            return enrichedParsed
        }

        return localParsed
    }

    // MARK: - Mapping

    private func buildParsedWorkout(
        from draft: CaptionParseDraft,
        sourceType: WorkoutSource,
        sourceURL: String?,
        authoritativeHints: [AuthoritativeExerciseHint]
    ) -> CaptionParsedWorkout {
        let mappedExercises = draft.exercises
            .sorted { $0.position < $1.position }
            .map { exercise -> CaptionParsedExercise in
                let resolution = matcher.resolveExercise(name: exercise.name, authoritativeHints: authoritativeHints)
                return CaptionParsedExercise(
                    kinexExerciseID: resolution.match.kinexExerciseID,
                    exerciseName: resolution.displayName,
                    rawName: exercise.name,
                    sets: exercise.sets,
                    reps: exercise.reps,
                    duration: exercise.duration,
                    restAfter: draft.restBetweenSets,
                    notes: exercise.notes,
                    position: exercise.position,
                    match: resolution.match
                )
            }

        var confidence = draft.confidence
        let ambiguousCount = mappedExercises.filter {
            if case .ambiguous = $0.match { return true }
            return false
        }.count
        let unknownCount = mappedExercises.filter {
            if case .unknown = $0.match { return true }
            return false
        }.count

        confidence -= Double(ambiguousCount) * 0.08
        confidence -= Double(unknownCount) * 0.12

        if authoritativeHints.isEmpty == false {
            confidence += 0.04
        }

        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = title.isEmpty ? defaultTitle(for: sourceType) : title

        return CaptionParsedWorkout(
            sourceType: sourceType,
            sourceURL: sourceURL,
            title: finalTitle,
            exercises: mappedExercises,
            restBetweenSets: draft.restBetweenSets,
            notes: draft.notes,
            parsingConfidence: min(max(confidence, 0), 1),
            unparsedLines: draft.unparsedLines,
            rounds: draft.rounds
        )
    }

    private func extractAuthoritativeHints(from ingestResponse: WorkoutIngestResponse) -> [AuthoritativeExerciseHint] {
        ingestResponse.exercises.compactMap { exercise in
            guard let id = exercise.id?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
                return nil
            }

            let name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                return nil
            }

            return AuthoritativeExerciseHint(kinexExerciseID: id, displayName: name)
        }
    }

    private func shouldUseEnriched(localParsed: CaptionParsedWorkout, enrichedParsed: CaptionParsedWorkout) -> Bool {
        let localAuthoritativeCount = localParsed.exercises.filter { $0.kinexExerciseID != nil }.count
        let enrichedAuthoritativeCount = enrichedParsed.exercises.filter { $0.kinexExerciseID != nil }.count

        if enrichedAuthoritativeCount > localAuthoritativeCount {
            return true
        }

        return enrichedParsed.parsingConfidence >= localParsed.parsingConfidence
    }

    // MARK: - Backend enrichment

    private func parseCaptionWithTimeout(
        service: InstagramFetchService,
        caption: String,
        sourceURL: String?
    ) async -> WorkoutIngestResponse? {
        await withTaskGroup(of: WorkoutIngestResponse?.self) { group in
            group.addTask {
                do {
                    return try await service.parseCaption(caption, url: sourceURL)
                } catch {
                    captionParserLogger.debug("Backend parse failed: \(error.localizedDescription, privacy: .public)")
                    return nil
                }
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: self.backendTimeoutNanoseconds)
                return nil
            }

            let firstResult = await group.next() ?? nil
            group.cancelAll()
            return firstResult
        }
    }

    // MARK: - Source

    private func inferredSourceType(from sourceURL: String?) -> WorkoutSource {
        guard let sourceURL, !sourceURL.isEmpty else {
            return .instagram
        }
        return SocialPlatform.detect(from: sourceURL).workoutSource
    }

    private func defaultTitle(for sourceType: WorkoutSource) -> String {
        switch sourceType {
        case .tiktok:
            return "TikTok Workout"
        case .instagram:
            return "Instagram Workout"
        default:
            return "Imported Workout"
        }
    }
}
