import Foundation
import XCTest
@testable import Kinex_Fit

final class CaptionParserTests: XCTestCase {
    private let parser = CaptionParser()

    func testParsesStructuredSetsRepsAndRest() {
        let caption = """
        Full Body Workout 💪
        🔴 4x8 Squats
        🔴 3x10 Deadlifts
        🔴 5x5 Bench Press
        ⏱️ Rest 90s between
        💬 Tag a workout buddy!
        """

        let parsed = parser.parseCaptionText(caption)

        XCTAssertEqual(parsed.exercises.count, 3)
        XCTAssertEqual(parsed.exercises[0].sets, 4)
        XCTAssertEqual(parsed.exercises[0].reps, 8)
        XCTAssertEqual(parsed.exercises[0].name, "Squats")
        XCTAssertEqual(parsed.restBetweenSets, "90s")
        XCTAssertEqual(parsed.title, "Full Body Workout")
        XCTAssertFalse(parsed.unparsedLines.contains(where: { $0.text.lowercased().contains("tag") }))
    }

    func testParsesTikTokNumberedDurationStyle() {
        let caption = """
        1️⃣ Jumping Jacks - 30s
        2️⃣ Burpees - 30s
        3️⃣ Mountain Climbers - 30s
        Rest 30s - Repeat 3x
        #FitnessTok
        """

        let parsed = parser.parseCaptionText(caption)

        XCTAssertEqual(parsed.exercises.count, 3)
        XCTAssertEqual(parsed.exercises[0].duration, 30)
        XCTAssertEqual(parsed.exercises[0].name, "Jumping Jacks")
        XCTAssertEqual(parsed.rounds, 3)
        XCTAssertEqual(parsed.restBetweenSets, "30s")
    }

    func testKeepsMeaningfulUnparsedLinesButDropsNoise() {
        let caption = """
        Leg Day 🔥
        3x10 Squats
        Some cardio at the end
        4x8 Deadlifts
        Follow for more workouts!
        """

        let parsed = parser.parseCaptionText(caption)

        XCTAssertEqual(parsed.exercises.count, 2)
        XCTAssertTrue(parsed.unparsedLines.contains(where: { $0.text == "Some cardio at the end" }))
        XCTAssertFalse(parsed.unparsedLines.contains(where: { $0.text.lowercased().contains("follow") }))
    }
}

final class ExerciseLibraryMatcherTests: XCTestCase {
    private let matcher = ExerciseLibraryMatcher()

    func testExactAliasMatch() {
        let result = matcher.resolveExercise(name: "squats", authoritativeHints: [])
        XCTAssertEqual(result.displayName, "Air Squat")

        switch result.match {
        case .exact:
            XCTAssertTrue(true)
        default:
            XCTFail("Expected exact match")
        }
    }

    func testFuzzyTypoMatch() {
        let result = matcher.resolveExercise(name: "squatz", authoritativeHints: [])

        switch result.match {
        case .fuzzy(_, let confidence):
            XCTAssertGreaterThanOrEqual(confidence, 0.7)
        default:
            XCTFail("Expected fuzzy match")
        }
    }

    func testAmbiguousMatchReturnsOptions() {
        let result = matcher.resolveExercise(name: "rows", authoritativeHints: [])

        switch result.match {
        case .ambiguous(let options):
            XCTAssertGreaterThanOrEqual(options.count, 3)
        default:
            XCTFail("Expected ambiguous match")
        }
    }

    func testUnknownMatchReturnsSuggestions() {
        let result = matcher.resolveExercise(name: "dragon flag hold", authoritativeHints: [])

        switch result.match {
        case .unknown(let closest):
            XCTAssertFalse(closest.isEmpty)
        default:
            XCTFail("Expected unknown match")
        }
    }

    func testRepeatedMatchUsesStableOutput() {
        let first = matcher.resolveExercise(name: "deadlifts", authoritativeHints: [])
        let second = matcher.resolveExercise(name: "deadlifts", authoritativeHints: [])
        XCTAssertEqual(first, second)
    }
}

final class CaptionImportParsingServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testLocalOnlyParseBuildsWorkout() async {
        let service = CaptionImportParsingService(apiClient: nil)

        let result = await service.parseImportText(
            "3x10 Squats\n3x10 Deadlifts\nRest 60s",
            sourceURL: "https://www.instagram.com/p/abc123"
        )

        XCTAssertEqual(result.sourceType, .instagram)
        XCTAssertEqual(result.exercises.count, 2)
        XCTAssertEqual(result.restBetweenSets, "60s")
        XCTAssertGreaterThan(result.parsingConfidence, 0)
        XCTAssertLessThanOrEqual(result.parsingConfidence, 1)
    }

    func testBackendEnrichmentAddsAuthoritativeExerciseIDs() async {
        let apiClient = makeMockedAPIClient { request in
            guard let url = request.url else {
                throw TestError("Missing URL")
            }

            XCTAssertEqual(url.path, "/api/ingest")

            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            let payload = """
            {
              "title": "From Backend",
              "workoutType": "standard",
              "exercises": [
                {"id": "kinex_squat", "name": "Squats"},
                {"id": "kinex_deadlift", "name": "Deadlifts"}
              ]
            }
            """

            return (response, Data(payload.utf8))
        }

        let service = CaptionImportParsingService(apiClient: apiClient)
        let result = await service.parseImportText(
            "3x10 Squats\n3x10 Deadlifts",
            sourceURL: "https://www.instagram.com/p/abc123"
        )

        XCTAssertEqual(result.exercises.count, 2)
        XCTAssertTrue(result.exercises.contains(where: { $0.kinexExerciseID == "kinex_squat" }))
        XCTAssertTrue(result.exercises.contains(where: { $0.kinexExerciseID == "kinex_deadlift" }))
    }

    func testBackendTimeoutFallsBackToLocalParse() async {
        let apiClient = makeMockedAPIClient { request in
            guard let url = request.url else {
                throw TestError("Missing URL")
            }

            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            Thread.sleep(forTimeInterval: 1.0)

            let payload = """
            {
              "title": "Late Backend",
              "workoutType": "standard",
              "exercises": [
                {"id": "late_id", "name": "Squats"}
              ]
            }
            """

            return (response, Data(payload.utf8))
        }

        let service = CaptionImportParsingService(apiClient: apiClient)

        let startedAt = Date()
        let result = await service.parseImportText(
            "3x10 Squats",
            sourceURL: "https://www.instagram.com/p/abc123"
        )
        let elapsed = Date().timeIntervalSince(startedAt)

        XCTAssertLessThan(elapsed, 1.0)
        XCTAssertEqual(result.exercises.count, 1)
        XCTAssertNil(result.exercises.first?.kinexExerciseID)
    }

    func testTikTokURLMapsToTikTokSourceType() async {
        let service = CaptionImportParsingService(apiClient: nil)

        let result = await service.parseImportText(
            "3x10 Squats",
            sourceURL: "https://www.tiktok.com/@user/video/123456"
        )

        XCTAssertEqual(result.sourceType, .tiktok)
    }

    func testAmbiguousExerciseReturnsAmbiguousMatch() async {
        let service = CaptionImportParsingService(apiClient: nil)

        let result = await service.parseImportText(
            "3x10 Rows",
            sourceURL: "https://www.instagram.com/p/abc123"
        )

        XCTAssertEqual(result.exercises.count, 1)
        guard let first = result.exercises.first else {
            XCTFail("Expected parsed exercise")
            return
        }

        switch first.match {
        case .ambiguous(let options):
            XCTAssertGreaterThanOrEqual(options.count, 2)
        default:
            XCTFail("Expected ambiguous match for rows")
        }
    }

    func testUnparsedLinesAreExposedForManualAdd() async {
        let service = CaptionImportParsingService(apiClient: nil)

        let result = await service.parseImportText(
            "3x10 Squats\nSome cardio at the end",
            sourceURL: "https://www.instagram.com/p/abc123"
        )

        XCTAssertEqual(result.exercises.count, 1)
        XCTAssertTrue(result.unparsedLines.contains(where: { $0.text == "Some cardio at the end" }))
    }

    // MARK: - TikTok Preprocessor Tests

    func testTikTokPreprocessorStripsHashtags() {
        let raw = "Squats 5x10 #legday #HYROX #fitness"
        let result = TikTokCaptionPreprocessor.preprocess(raw)
        XCTAssertFalse(result.contains("#"), "Hashtags should be stripped")
        XCTAssertTrue(result.contains("Squats"), "Exercise name should remain")
    }

    func testTikTokPreprocessorStripsAtMentions() {
        let raw = "Great workout by @kinexfit - Squats 3x10"
        let result = TikTokCaptionPreprocessor.preprocess(raw)
        XCTAssertFalse(result.contains("@"), "@mentions should be stripped")
        XCTAssertTrue(result.contains("Squats"), "Exercise name should remain")
    }

    func testTikTokPreprocessorSplitsOnWorkoutEmojis() {
        let raw = "🔥 Squats 5x10 💪 Deadlifts 3x8"
        let result = TikTokCaptionPreprocessor.preprocess(raw)
        let lines = result.components(separatedBy: .newlines).filter { !$0.isEmpty }
        XCTAssertGreaterThanOrEqual(lines.count, 2, "Emojis should become line breaks")
    }

    func testTikTokParsesTerseFormat() async {
        let service = CaptionImportParsingService(apiClient: nil)
        let result = await service.parseImportText(
            "5x10 squats 3x8 deadlifts",
            sourceURL: "https://www.tiktok.com/@user/video/123"
        )
        XCTAssertEqual(result.sourceType, .tiktok)
        XCTAssertGreaterThanOrEqual(result.exercises.count, 1)
    }

    func testTikTokLowConfidencePatternCapsConfidence() async {
        let service = CaptionImportParsingService(apiClient: nil)
        let result = await service.parseImportText(
            "Workout breakdown in comments! 🔥",
            sourceURL: "https://www.tiktok.com/@user/video/456"
        )
        XCTAssertLessThanOrEqual(result.parsingConfidence, 0.3,
            "Low-confidence TikTok captions should have confidence capped at 0.3")
    }

    func testTikTokEmojiDelimitedParsesExercises() async {
        let service = CaptionImportParsingService(apiClient: nil)
        let result = await service.parseImportText(
            "🔥 Squats 5x10 💪 Deadlifts 3x8",
            sourceURL: "https://www.tiktok.com/@user/video/789"
        )
        XCTAssertEqual(result.sourceType, .tiktok)
        XCTAssertGreaterThanOrEqual(result.exercises.count, 1)
    }

    // MARK: - Helpers

    private func makeMockedAPIClient(
        requestHandler: @escaping MockURLProtocol.RequestHandler
    ) -> APIClient {
        MockURLProtocol.requestHandler = requestHandler

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        return APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: InMemoryTokenStore(),
            session: session
        )
    }
}

final class ShareImportSourceMappingTests: XCTestCase {
    func testTikTokURLMapsToTikTokWorkoutSource() {
        let source = WorkoutsTab.sourceTypeForImportedPostURL("https://www.tiktok.com/@kinex/video/12345")
        XCTAssertEqual(source, .tiktok)
    }

    func testInstagramURLMapsToInstagramWorkoutSource() {
        let source = WorkoutsTab.sourceTypeForImportedPostURL("https://www.instagram.com/reel/abc123/")
        XCTAssertEqual(source, .instagram)
    }

    func testUnknownURLMapsToImportedWorkoutSource() {
        let source = WorkoutsTab.sourceTypeForImportedPostURL("https://example.com/workout")
        XCTAssertEqual(source, .imported)
    }

    func testEmptyURLDefaultsToInstagramForShareExtensionFlow() {
        let source = WorkoutsTab.sourceTypeForImportedPostURL(nil)
        XCTAssertEqual(source, .instagram)
    }
}

private final class MockURLProtocol: URLProtocol {
    typealias RequestHandler = (URLRequest) throws -> (HTTPURLResponse, Data)

    static var requestHandler: RequestHandler?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: TestError("Handler not set"))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() { }
}

private struct TestError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
