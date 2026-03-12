import Foundation
import OSLog

private let captionParserLogger = Logger(subsystem: "com.kinex.fit", category: "CaptionImportParsing")

final class CaptionImportParsingService {
    private let parser: CaptionParser
    private let matcher: ExerciseLibraryMatcher
    private let apiClient: APIClient?
    private let instagramFetchService: InstagramFetchService?
    private let backendTimeoutNanoseconds: UInt64

    /// When true, backend enrichment calls (pass 2 & 3) are skipped entirely.
    /// Automatically set when the `APIClient` has no auth token (e.g. guest/onboarding mode).
    private let skipBackendCalls: Bool

    init(
        apiClient: APIClient? = nil,
        parser: CaptionParser = CaptionParser(),
        matcher: ExerciseLibraryMatcher = FreeExerciseDBLoader.sharedMatcher,
        backendTimeoutNanoseconds: UInt64 = 450_000_000
    ) {
        self.apiClient = apiClient
        self.parser = parser
        self.matcher = matcher
        self.instagramFetchService = apiClient.map { InstagramFetchService(apiClient: $0) }
        self.backendTimeoutNanoseconds = backendTimeoutNanoseconds
        self.skipBackendCalls = apiClient?.tokenStore.accessToken == nil
    }

    func parseImportText(_ text: String, sourceURL: String?) async -> CaptionParsedWorkout {
        let sourceType = inferredSourceType(from: sourceURL)

        let normalizedText: String
        let isTikTokLowConfidence: Bool
        if sourceType == .tiktok {
            normalizedText = TikTokCaptionPreprocessor.preprocess(text)
            isTikTokLowConfidence = TikTokCaptionPreprocessor.isLowConfidence(text)
        } else {
            normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            isTikTokLowConfidence = false
        }

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

        // Extract body-part context once — reused across all parsing passes.
        let bodyPartContext = ExerciseLibraryMatcher.BodyPartContext.extract(from: normalizedText)
        captionParserLogger.debug("Body-part context detected: \(bodyPartContext.rawValue, privacy: .public)")

        let localDraft = parser.parseCaptionText(normalizedText)
        var localParsed = buildParsedWorkout(
            from: localDraft,
            sourceType: sourceType,
            sourceURL: sourceURL,
            authoritativeHints: [],
            captionContext: bodyPartContext
        )

        if isTikTokLowConfidence {
            localParsed.parsingConfidence = min(localParsed.parsingConfidence, 0.3)
        }

        guard let instagramFetchService, !skipBackendCalls else {
            return localParsed
        }

        // Pass 2: backend LLM enrichment (existing flow, 450 ms timeout)
        guard let ingestResponse = await parseCaptionWithTimeout(
            service: instagramFetchService,
            caption: normalizedText,
            sourceURL: sourceURL
        ) else {
            // Even without backend enrichment, run the LLM unknown resolver for unknowns
            return await resolveUnknownsViaLLM(
                parsed: localParsed,
                captionContext: normalizedText,
                isTikTokLowConfidence: isTikTokLowConfidence
            )
        }

        let authoritativeHints = extractAuthoritativeHints(from: ingestResponse)
        guard !authoritativeHints.isEmpty else {
            return await resolveUnknownsViaLLM(
                parsed: localParsed,
                captionContext: normalizedText,
                isTikTokLowConfidence: isTikTokLowConfidence
            )
        }

        var enrichedParsed = buildParsedWorkout(
            from: localDraft,
            sourceType: sourceType,
            sourceURL: sourceURL,
            authoritativeHints: authoritativeHints,
            captionContext: bodyPartContext
        )

        if isTikTokLowConfidence {
            enrichedParsed.parsingConfidence = min(enrichedParsed.parsingConfidence, 0.3)
        }

        let bestParsed = shouldUseEnriched(localParsed: localParsed, enrichedParsed: enrichedParsed)
            ? enrichedParsed : localParsed

        // Pass 3: targeted LLM resolver for any exercises still marked .unknown
        return await resolveUnknownsViaLLM(
            parsed: bestParsed,
            captionContext: normalizedText,
            isTikTokLowConfidence: isTikTokLowConfidence
        )
    }

    // MARK: - Pass 3: LLM resolver for unknown exercises

    /// Sends exercises still marked `.unknown` to the backend for LLM resolution.
    /// Requires `/api/mobile/exercise/resolve` route on the Next.js backend.
    private func resolveUnknownsViaLLM(
        parsed: CaptionParsedWorkout,
        captionContext: String,
        isTikTokLowConfidence: Bool
    ) async -> CaptionParsedWorkout {
        guard let apiClient else { return parsed }

        let unknownExercises = parsed.exercises.filter {
            if case .unknown = $0.match { return true }
            return false
        }
        guard !unknownExercises.isEmpty else { return parsed }

        let rawNames = unknownExercises.map(\.rawName)
        captionParserLogger.debug("Resolving \(rawNames.count) unknown exercises via LLM: \(rawNames.joined(separator: ", "), privacy: .public)")

        do {
            let request = try APIRequest.resolveExercises(rawNames, captionContext: captionContext)
            let response: ExerciseResolveResponse = try await apiClient.send(request)

            // Build a lookup from rawName → resolved canonical name
            var resolutionMap: [String: ExerciseResolveResponse.Resolution] = [:]
            for resolution in response.resolutions {
                resolutionMap[resolution.rawName.lowercased()] = resolution
            }

            var updatedExercises = parsed.exercises
            for (index, exercise) in updatedExercises.enumerated() {
                guard case .unknown = exercise.match else { continue }
                guard let resolution = resolutionMap[exercise.rawName.lowercased()] else { continue }
                guard resolution.confidence >= 0.60 else { continue }

                updatedExercises[index].exerciseName = resolution.canonicalName
                if resolution.confidence >= 0.85 {
                    updatedExercises[index].match = .exact(kinexExerciseID: resolution.kinexExerciseID)
                } else {
                    updatedExercises[index].match = .fuzzy(
                        kinexExerciseID: resolution.kinexExerciseID,
                        confidence: resolution.confidence
                    )
                }
            }

            // Recalculate confidence with fewer unknowns
            let resolvedCount = updatedExercises.filter {
                if case .unknown = $0.match { return false }
                return true
            }.count
            let totalCount = max(updatedExercises.count, 1)
            let confidenceBonus = Double(resolvedCount) / Double(totalCount) * 0.1

            var result = parsed
            result.exercises = updatedExercises
            result.parsingConfidence = min(parsed.parsingConfidence + confidenceBonus, 1.0)
            if isTikTokLowConfidence {
                result.parsingConfidence = min(result.parsingConfidence, 0.3)
            }
            return result

        } catch {
            captionParserLogger.debug("LLM unknown resolver failed: \(error.localizedDescription, privacy: .public)")
            return parsed
        }
    }

    // MARK: - Mapping

    private func buildParsedWorkout(
        from draft: CaptionParseDraft,
        sourceType: WorkoutSource,
        sourceURL: String?,
        authoritativeHints: [AuthoritativeExerciseHint],
        captionContext: ExerciseLibraryMatcher.BodyPartContext
    ) -> CaptionParsedWorkout {
        let mappedExercises = draft.exercises
            .sorted { $0.position < $1.position }
            .map { exercise -> CaptionParsedExercise in
                let resolution = matcher.resolveExercise(
                    name: exercise.name,
                    authoritativeHints: authoritativeHints,
                    captionContext: captionContext
                )
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

        if !authoritativeHints.isEmpty {
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
            guard !name.isEmpty else { return nil }
            return AuthoritativeExerciseHint(kinexExerciseID: id, displayName: name)
        }
    }

    private func shouldUseEnriched(
        localParsed: CaptionParsedWorkout,
        enrichedParsed: CaptionParsedWorkout
    ) -> Bool {
        let localAuthoritativeCount = localParsed.exercises.filter { $0.kinexExerciseID != nil }.count
        let enrichedAuthoritativeCount = enrichedParsed.exercises.filter { $0.kinexExerciseID != nil }.count
        if enrichedAuthoritativeCount > localAuthoritativeCount { return true }
        return enrichedParsed.parsingConfidence >= localParsed.parsingConfidence
    }

    // MARK: - Backend enrichment (pass 2)

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

    // MARK: - Source helpers

    private func inferredSourceType(from sourceURL: String?) -> WorkoutSource {
        guard let sourceURL, !sourceURL.isEmpty else { return .instagram }
        return SocialPlatform.detect(from: sourceURL).workoutSource
    }

    private func defaultTitle(for sourceType: WorkoutSource) -> String {
        switch sourceType {
        case .tiktok: return "TikTok Workout"
        case .instagram: return "Instagram Workout"
        default: return "Imported Workout"
        }
    }
}

// MARK: - Exercise resolve API request & response

/// Request/response models for `/api/mobile/exercise/resolve`.
struct ExerciseResolveResponse: Decodable {
    struct Resolution: Decodable {
        let rawName: String
        let canonicalName: String
        let confidence: Double
        let kinexExerciseID: String?
    }
    let resolutions: [Resolution]
}

extension APIRequest {
    private struct ExerciseResolveBody: Encodable {
        let exercises: [String]
        let captionContext: String?
    }

    static func resolveExercises(_ names: [String], captionContext: String?) throws -> APIRequest {
        try .json(
            path: "/api/mobile/exercise/resolve",
            method: .post,
            body: ExerciseResolveBody(exercises: names, captionContext: captionContext)
        )
    }
}
