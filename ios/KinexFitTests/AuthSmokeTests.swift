import Foundation
import XCTest
@testable import Kinex_Fit

final class AuthSmokeTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testGoogleSignInAndRefreshHappyPath() async throws {
        let database = try AppDatabase.inMemory()
        let tokenStore = InMemoryTokenStore()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore,
            session: session
        )
        let authService = AuthService(
            apiClient: apiClient,
            tokenStore: tokenStore,
            database: database
        )

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }

            switch url.path {
            case "/api/mobile/auth/signin":
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))

                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!

                let payload = """
                {
                  "accessToken": "access-1",
                  "refreshToken": "refresh-1",
                  "expiresIn": 900,
                  "tokenType": "Bearer",
                  "user": {
                    "id": "user-smoke-1",
                    "email": "smoke@kinexfit.com",
                    "firstName": "Smoke",
                    "lastName": "Tester",
                    "subscriptionTier": "free",
                    "onboardingCompleted": false
                  },
                  "isNewUser": true
                }
                """

                return (response, Data(payload.utf8))

            case "/api/mobile/auth/refresh":
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))

                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!

                let payload = """
                {
                  "accessToken": "access-2",
                  "refreshToken": "refresh-2",
                  "expiresIn": 900,
                  "tokenType": "Bearer"
                }
                """

                return (response, Data(payload.utf8))

            default:
                throw TestFailure("Unexpected path: \(url.path)")
            }
        }

        let user = try await authService.signIn(
            provider: .google,
            identityToken: "mock-id-token",
            firstName: "Smoke",
            lastName: "Tester"
        )

        XCTAssertEqual(user.id, "user-smoke-1")
        XCTAssertEqual(user.email, "smoke@kinexfit.com")
        XCTAssertEqual(tokenStore.accessToken, "access-1")
        XCTAssertEqual(tokenStore.refreshToken, "refresh-1")

        let didRefresh = try await authService.refreshTokens()

        XCTAssertTrue(didRefresh)
        XCTAssertEqual(tokenStore.accessToken, "access-2")
        XCTAssertEqual(tokenStore.refreshToken, "refresh-2")

        let persistedUser = try await authService.getCurrentUser()
        XCTAssertEqual(persistedUser?.id, "user-smoke-1")
    }

    func testGetWorkoutDatesReturnsSortedDatesWithoutDecodingCrash() async throws {
        let database = try AppDatabase.inMemory()
        let tokenStore = InMemoryTokenStore()
        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore,
            session: URLSession(configuration: .ephemeral)
        )
        let syncEngine = SyncEngine(database: database, apiClient: apiClient)
        let repository = WorkoutRepository(
            database: database,
            apiClient: apiClient,
            syncEngine: syncEngine
        )

        let older = Date(timeIntervalSince1970: 1_700_000_000)
        let newer = Date(timeIntervalSince1970: 1_700_003_600)

        try await database.dbQueue.write { db in
            try Workout(
                id: "workout-old",
                title: "Old Workout",
                source: .manual,
                createdAt: older,
                updatedAt: older
            ).insert(db)

            try Workout(
                id: "workout-new",
                title: "New Workout",
                source: .manual,
                createdAt: newer,
                updatedAt: newer
            ).insert(db)
        }

        let dates = try await repository.getWorkoutDates()

        XCTAssertEqual(dates.count, 2)
        XCTAssertEqual(dates[0], newer)
        XCTAssertEqual(dates[1], older)
    }

    func testImportFromServerAcceptsIDFieldFromBackend() async throws {
        let database = try AppDatabase.inMemory()
        let tokenStore = InMemoryTokenStore()
        try tokenStore.setAccessToken("access-import-id")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore,
            session: session
        )
        let syncEngine = SyncEngine(database: database, apiClient: apiClient)
        let repository = WorkoutRepository(
            database: database,
            apiClient: apiClient,
            syncEngine: syncEngine
        )

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }

            switch url.path {
            case "/api/mobile/workouts":
                XCTAssertEqual(request.httpMethod, "GET")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-import-id")

                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!

                let payload = """
                {
                  "workouts": [
                    {
                      "id": "workout-web-id",
                      "title": "Web Workout",
                      "content": "Saved from web",
                      "source": "manual",
                      "createdAt": "2026-02-20T10:00:00Z",
                      "updatedAt": "2026-02-20T10:15:00Z"
                    }
                  ],
                  "nextCursor": null
                }
                """

                return (response, Data(payload.utf8))

            default:
                throw TestFailure("Unexpected path: \(url.path)")
            }
        }

        let imported = try await repository.importFromServer()
        XCTAssertEqual(imported, 1)

        let workout = try await repository.fetch(id: "workout-web-id")
        XCTAssertEqual(workout?.title, "Web Workout")
        XCTAssertEqual(workout?.content, "Saved from web")
    }

    func testImportFromServerAcceptsSnakeCaseAndWorkoutIDFields() async throws {
        let database = try AppDatabase.inMemory()
        let tokenStore = InMemoryTokenStore()
        try tokenStore.setAccessToken("access-import-snake")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore,
            session: session
        )
        let syncEngine = SyncEngine(database: database, apiClient: apiClient)
        let repository = WorkoutRepository(
            database: database,
            apiClient: apiClient,
            syncEngine: syncEngine
        )

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }

            switch url.path {
            case "/api/mobile/workouts":
                XCTAssertEqual(request.httpMethod, "GET")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-import-snake")

                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!

                let payload = """
                {
                  "items": [
                    {
                      "workout_id": "workout-web-snake",
                      "title": "Snake Workout",
                      "description": "Description fallback",
                      "source": "instagram",
                      "created_at": "2026-02-20T10:00:00.123Z",
                      "updated_at": "2026-02-20T10:10:00.123Z"
                    }
                  ],
                  "next_cursor": null
                }
                """

                return (response, Data(payload.utf8))

            default:
                throw TestFailure("Unexpected path: \(url.path)")
            }
        }

        let imported = try await repository.importFromServer()
        XCTAssertEqual(imported, 1)

        let workout = try await repository.fetch(id: "workout-web-snake")
        XCTAssertEqual(workout?.title, "Snake Workout")
        XCTAssertEqual(workout?.content, "Description fallback")
        XCTAssertEqual(workout?.source, .instagram)
    }

    func testImportFromServerMapsSchedulingFields() async throws {
        let database = try AppDatabase.inMemory()
        let tokenStore = InMemoryTokenStore()
        try tokenStore.setAccessToken("access-import-scheduled")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore,
            session: session
        )
        let syncEngine = SyncEngine(database: database, apiClient: apiClient)
        let repository = WorkoutRepository(
            database: database,
            apiClient: apiClient,
            syncEngine: syncEngine
        )

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }

            switch url.path {
            case "/api/mobile/workouts":
                XCTAssertEqual(request.httpMethod, "GET")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-import-scheduled")

                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!

                let payload = """
                {
                  "workouts": [
                    {
                      "id": "workout-scheduled-1",
                      "title": "Scheduled Workout",
                      "content": "Leg day",
                      "source": "manual",
                      "scheduledDate": "2026-03-05",
                      "scheduledTime": "07:30",
                      "status": "completed",
                      "completedDate": "2026-03-05",
                      "completedAt": "2026-03-05T08:05:00Z",
                      "durationSeconds": 2100,
                      "completionCount": 4,
                      "createdAt": "2026-03-01T10:00:00Z",
                      "updatedAt": "2026-03-01T10:15:00Z"
                    }
                  ],
                  "nextCursor": null
                }
                """

                return (response, Data(payload.utf8))

            default:
                throw TestFailure("Unexpected path: \(url.path)")
            }
        }

        let imported = try await repository.importFromServer()
        XCTAssertEqual(imported, 1)

        let workout = try await repository.fetch(id: "workout-scheduled-1")
        XCTAssertEqual(workout?.scheduledDate, "2026-03-05")
        XCTAssertEqual(workout?.scheduledTime, "07:30")
        XCTAssertEqual(workout?.status, .completed)
        XCTAssertEqual(workout?.completedDate, "2026-03-05")
        XCTAssertEqual(workout?.completedAt, "2026-03-05T08:05:00Z")
        XCTAssertEqual(workout?.durationSeconds, 2100)
        XCTAssertEqual(workout?.completionCount, 4)
        XCTAssertEqual(workout?.isCompleted, true)
    }

    func testCompleteWorkoutPersistsCompletionMetadataFromResponse() async throws {
        let database = try AppDatabase.inMemory()
        let tokenStore = InMemoryTokenStore()
        try tokenStore.setAccessToken("access-complete-workout")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore,
            session: session
        )
        let syncEngine = SyncEngine(database: database, apiClient: apiClient)
        let repository = WorkoutRepository(
            database: database,
            apiClient: apiClient,
            syncEngine: syncEngine
        )

        let now = Date(timeIntervalSince1970: 1_709_100_000)
        try await database.dbQueue.write { db in
            try Workout(
                id: "workout-complete-1",
                title: "Completion Workout",
                source: .manual,
                createdAt: now,
                updatedAt: now
            ).insert(db)
        }

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }

            switch url.path {
            case "/api/workouts/workout-complete-1/complete":
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(
                    request.value(forHTTPHeaderField: "Authorization"),
                    "Bearer access-complete-workout"
                )

                let bodyData = try XCTUnwrap(request.httpBody)
                let body = try XCTUnwrap(
                    try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
                )
                XCTAssertEqual(body["completedDate"] as? String, "2026-03-09")
                XCTAssertEqual(body["completedAt"] as? String, "2026-03-09T18:30:00Z")
                XCTAssertEqual(body["durationSeconds"] as? Int, 1980)

                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!

                let payload = """
                {
                  "success": true,
                  "workoutId": "workout-complete-1",
                  "status": "completed",
                  "completedDate": "2026-03-09",
                  "completedAt": "2026-03-09T18:30:00Z",
                  "durationSeconds": 1980,
                  "completionCount": 7
                }
                """
                return (response, Data(payload.utf8))

            default:
                throw TestFailure("Unexpected path: \(url.path)")
            }
        }

        let updated = try await repository.completeWorkout(
            id: "workout-complete-1",
            completedDate: "2026-03-09",
            completedAt: "2026-03-09T18:30:00Z",
            durationSeconds: 1980
        )

        XCTAssertEqual(updated?.status, .completed)
        XCTAssertEqual(updated?.completedDate, "2026-03-09")
        XCTAssertEqual(updated?.completedAt, "2026-03-09T18:30:00Z")
        XCTAssertEqual(updated?.durationSeconds, 1980)
        XCTAssertEqual(updated?.completionCount, 7)
        XCTAssertEqual(updated?.isCompleted, true)

        let persisted = try await repository.fetch(id: "workout-complete-1")
        XCTAssertEqual(persisted?.status, .completed)
        XCTAssertEqual(persisted?.completedDate, "2026-03-09")
        XCTAssertEqual(persisted?.completedAt, "2026-03-09T18:30:00Z")
        XCTAssertEqual(persisted?.durationSeconds, 1980)
        XCTAssertEqual(persisted?.completionCount, 7)
    }

    func testImportFromServerFallsBackToWebEndpointOnMobileServerError() async throws {
        let database = try AppDatabase.inMemory()
        let tokenStore = InMemoryTokenStore()
        try tokenStore.setAccessToken("access-import-fallback")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore,
            session: session
        )
        let syncEngine = SyncEngine(database: database, apiClient: apiClient)
        let repository = WorkoutRepository(
            database: database,
            apiClient: apiClient,
            syncEngine: syncEngine
        )

        var mobileRequestCount = 0
        var webRequestCount = 0

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }

            switch url.path {
            case "/api/mobile/workouts":
                mobileRequestCount += 1
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!

                return (response, Data("{\"error\":\"Failed to fetch workouts\"}".utf8))

            case "/api/workouts":
                webRequestCount += 1
                XCTAssertEqual(request.httpMethod, "GET")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-import-fallback")

                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!

                let payload = """
                {
                  "workouts": [
                    {
                      "workoutId": "workout-fallback-1",
                      "title": "Fallback Workout",
                      "content": "Recovered via /api/workouts",
                      "source": "manual",
                      "createdAt": "2026-02-23T19:00:00Z",
                      "updatedAt": "2026-02-23T19:00:00Z"
                    }
                  ]
                }
                """

                return (response, Data(payload.utf8))

            default:
                throw TestFailure("Unexpected path: \(url.path)")
            }
        }

        let imported = try await repository.importFromServer()
        XCTAssertEqual(imported, 1)
        XCTAssertEqual(mobileRequestCount, 1)
        XCTAssertEqual(webRequestCount, 1)

        let workout = try await repository.fetch(id: "workout-fallback-1")
        XCTAssertEqual(workout?.title, "Fallback Workout")
    }

    func testAPIClientInvalidatesSessionOnUnauthorizedMobileEndpointWhenRefreshUnavailable() async throws {
        let tokenStore = InMemoryTokenStore()
        try tokenStore.setAccessToken("expired-access-token")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore,
            session: session
        )

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }

            switch url.path {
            case "/api/mobile/workouts":
                XCTAssertEqual(request.httpMethod, "GET")
                XCTAssertEqual(
                    request.value(forHTTPHeaderField: "Authorization"),
                    "Bearer expired-access-token"
                )

                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (response, Data("{\"error\":\"Unauthorized\"}".utf8))

            default:
                throw TestFailure("Unexpected path: \(url.path)")
            }
        }

        let invalidatedExpectation = expectation(description: "auth session invalidated")
        let observer = NotificationCenter.default.addObserver(
            forName: .authSessionInvalidated,
            object: nil,
            queue: nil
        ) { _ in
            invalidatedExpectation.fulfill()
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        let request = APIRequest(path: "/api/mobile/workouts", method: .get)

        do {
            let _: Data = try await apiClient.send(request)
            XCTFail("Expected unauthorized error")
        } catch let error as APIError {
            guard case .httpStatus(let code, _) = error else {
                XCTFail("Expected HTTP status error, got \(error)")
                return
            }
            XCTAssertEqual(code, 401)
        }

        await fulfillment(of: [invalidatedExpectation], timeout: 1.0)
        XCTAssertNil(tokenStore.accessToken)
        XCTAssertNil(tokenStore.refreshToken)
    }

    func testTikTokImportFallsBackToOEmbedWhenTikTokEndpointMissing() async throws {
        let tokenStore = InMemoryTokenStore()
        try tokenStore.setAccessToken("access-tiktok")
        try tokenStore.setRefreshToken("refresh-tiktok")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore,
            session: session
        )
        let service = InstagramFetchService(apiClient: apiClient)

        var requestPaths: [String] = []

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }

            requestPaths.append(url.path)

            switch url.path {
            case "/api/tiktok-fetch":
                XCTAssertEqual(url.host, "kinexfit.com")
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-tiktok")
                let notFound = HTTPURLResponse(
                    url: url,
                    statusCode: 404,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (notFound, Data("{\"error\":\"Not found\"}".utf8))

            case "/oembed":
                XCTAssertEqual(url.host, "www.tiktok.com")
                XCTAssertEqual(request.httpMethod, "GET")
                XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
                let ok = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                let payload = """
                {
                  "version": "1.0",
                  "type": "video",
                  "title": "Leg Day - Squat 5x5",
                  "author_name": "Coach Alex",
                  "author_url": "https://www.tiktok.com/@coach",
                  "thumbnail_url": "https://example.com/thumb.jpg"
                }
                """
                return (ok, Data(payload.utf8))

            default:
                throw TestFailure("Unexpected path: \(url.path)")
            }
        }

        let response = try await service.fetchTikTokPost(
            url: "https://www.tiktok.com/@coach/video/1234567890123456789"
        )

        XCTAssertEqual(response.title, "Leg Day - Squat 5x5")
        XCTAssertEqual(response.author?.username, "coach")
        XCTAssertEqual(response.image, "https://example.com/thumb.jpg")
        XCTAssertEqual(
            requestPaths,
            ["/api/tiktok-fetch", "/oembed"]
        )
    }

    func testTikTokImportFallsBackToLegacyInstagramEndpointWhenOEmbedFails() async throws {
        let tokenStore = InMemoryTokenStore()
        try tokenStore.setAccessToken("access-tiktok")
        try tokenStore.setRefreshToken("refresh-tiktok")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore,
            session: session
        )
        let service = InstagramFetchService(apiClient: apiClient)

        var requestPaths: [String] = []

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }

            requestPaths.append(url.path)

            switch url.path {
            case "/api/tiktok-fetch":
                let badRequest = HTTPURLResponse(
                    url: url,
                    statusCode: 400,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (badRequest, Data("{\"error\":\"Invalid TikTok URL\"}".utf8))

            case "/oembed":
                let unavailable = HTTPURLResponse(
                    url: url,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (unavailable, Data("{\"message\":\"Unavailable\"}".utf8))

            case "/api/instagram-fetch":
                let ok = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                let payload = """
                {
                  "url": "https://www.tiktok.com/@coach/video/1234567890123456789",
                  "title": "Sprint Session",
                  "content": "Run 10x100m",
                  "timestamp": "2026-02-24T12:00:00Z"
                }
                """
                return (ok, Data(payload.utf8))

            default:
                throw TestFailure("Unexpected path: \(url.path)")
            }
        }

        let response = try await service.fetchTikTokPost(
            url: "https://www.tiktok.com/@coach/video/1234567890123456789"
        )

        XCTAssertEqual(response.title, "Sprint Session")
        XCTAssertEqual(
            requestPaths,
            ["/api/tiktok-fetch", "/oembed", "/api/instagram-fetch"]
        )
    }

    func testTikTokURLValidationAcceptsShareFormatsAndWrappedInput() {
        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: InMemoryTokenStore(),
            session: URLSession(configuration: .ephemeral)
        )
        let service = InstagramFetchService(apiClient: apiClient)

        XCTAssertTrue(service.isValidTikTokURL("https://www.tiktok.com/@coach/video/1234567890123456789"))
        XCTAssertTrue(service.isValidTikTokURL("https://vm.tiktok.com/ZTR45GpSF/"))
        XCTAssertTrue(service.isValidTikTokURL("https://vt.tiktok.com/ZSe4FqkKd"))
        XCTAssertTrue(service.isValidTikTokURL("https://www.tiktok.com/t/ZTRC5xgJp"))
        XCTAssertTrue(service.isValidTikTokURL("<https://www.tiktok.com/@coach/video/1234567890123456789>"))
        XCTAssertTrue(service.isValidTikTokURL("  https://www.tiktok.com/@coach/video/1234567890123456789  "))
    }

    func testAPIClientDoesNotInvalidateSessionOnSourceUnauthorizedSocialImportEndpoint() async throws {
        let tokenStore = InMemoryTokenStore()
        try tokenStore.setAccessToken("social-access-token")
        try tokenStore.setRefreshToken("social-refresh-token")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore,
            session: session
        )

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }
            switch url.path {
            case "/api/instagram-fetch":
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (response, Data("{\"error\":\"Instagram requires login to view this post\"}".utf8))
            default:
                throw TestFailure("Unexpected path: \(url.path)")
            }
        }

        let invalidatedExpectation = expectation(description: "auth session invalidated")
        invalidatedExpectation.isInverted = true
        let observer = NotificationCenter.default.addObserver(
            forName: .authSessionInvalidated,
            object: nil,
            queue: nil
        ) { _ in
            invalidatedExpectation.fulfill()
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        let request = try APIRequest.fetchInstagram(url: "https://www.instagram.com/p/abc123")

        do {
            let _: InstagramFetchResponse = try await apiClient.send(request)
            XCTFail("Expected unauthorized error")
        } catch let error as APIError {
            guard case .httpStatus(let code, _) = error else {
                XCTFail("Expected HTTP status error, got \(error)")
                return
            }
            XCTAssertEqual(code, 401)
        }

        await fulfillment(of: [invalidatedExpectation], timeout: 0.3)
        XCTAssertEqual(tokenStore.accessToken, "social-access-token")
        XCTAssertEqual(tokenStore.refreshToken, "social-refresh-token")
    }

    func testAPIClientRefreshesAndRetriesSocialImportOnAppUnauthorized() async throws {
        let tokenStore = InMemoryTokenStore()
        try tokenStore.setAccessToken("social-access-old")
        try tokenStore.setRefreshToken("social-refresh-old")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore,
            session: session
        )

        var socialRequestCount = 0
        var refreshRequestCount = 0
        var authorizationHeaders: [String?] = []

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }

            switch url.path {
            case "/api/instagram-fetch":
                socialRequestCount += 1
                authorizationHeaders.append(request.value(forHTTPHeaderField: "Authorization"))

                if socialRequestCount == 1 {
                    let unauthorizedResponse = HTTPURLResponse(
                        url: url,
                        statusCode: 401,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    return (unauthorizedResponse, Data("{\"error\":\"Unauthorized - Please sign in\"}".utf8))
                }

                let okResponse = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                let payload = """
                {
                  "url": "https://www.instagram.com/reel/xyz987",
                  "title": "Session Restored",
                  "content": "Split Squat 4x10",
                  "timestamp": "2026-03-02T18:00:00Z"
                }
                """
                return (okResponse, Data(payload.utf8))

            case "/api/mobile/auth/refresh":
                refreshRequestCount += 1
                XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))

                let refreshResponse = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                let payload = """
                {
                  "accessToken": "social-access-new",
                  "refreshToken": "social-refresh-new"
                }
                """
                return (refreshResponse, Data(payload.utf8))

            default:
                throw TestFailure("Unexpected path: \(url.path)")
            }
        }

        let request = try APIRequest.fetchInstagram(url: "https://www.instagram.com/reel/xyz987")
        let response: InstagramFetchResponse = try await apiClient.send(request)

        XCTAssertEqual(response.title, "Session Restored")
        XCTAssertEqual(socialRequestCount, 2)
        XCTAssertEqual(refreshRequestCount, 1)
        XCTAssertEqual(authorizationHeaders.count, 2)
        XCTAssertEqual(authorizationHeaders[0], "Bearer social-access-old")
        XCTAssertEqual(authorizationHeaders[1], "Bearer social-access-new")
        XCTAssertEqual(tokenStore.accessToken, "social-access-new")
        XCTAssertEqual(tokenStore.refreshToken, "social-refresh-new")
    }

    func testAPIClientInvalidatesSessionWhenSocialImportUnauthorizedAndRefreshFails() async throws {
        let tokenStore = InMemoryTokenStore()
        try tokenStore.setAccessToken("social-access-old")
        try tokenStore.setRefreshToken("social-refresh-old")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore,
            session: session
        )

        var requestPaths: [String] = []
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }
            requestPaths.append(url.path)

            switch url.path {
            case "/api/instagram-fetch":
                let unauthorizedResponse = HTTPURLResponse(
                    url: url,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (unauthorizedResponse, Data("{\"error\":\"Unauthorized - Please sign in\"}".utf8))

            case "/api/mobile/auth/refresh":
                let refreshUnauthorizedResponse = HTTPURLResponse(
                    url: url,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (refreshUnauthorizedResponse, Data("{\"error\":\"refresh token invalid\"}".utf8))

            default:
                throw TestFailure("Unexpected path: \(url.path)")
            }
        }

        let invalidatedExpectation = expectation(description: "auth session invalidated")
        let observer = NotificationCenter.default.addObserver(
            forName: .authSessionInvalidated,
            object: nil,
            queue: nil
        ) { _ in
            invalidatedExpectation.fulfill()
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        let request = try APIRequest.fetchInstagram(url: "https://www.instagram.com/p/abc123")

        do {
            let _: InstagramFetchResponse = try await apiClient.send(request)
            XCTFail("Expected unauthorized error")
        } catch let error as APIError {
            guard case .httpStatus(let code, _) = error else {
                XCTFail("Expected HTTP status error, got \(error)")
                return
            }
            XCTAssertEqual(code, 401)
        }

        await fulfillment(of: [invalidatedExpectation], timeout: 1.0)
        XCTAssertEqual(requestPaths, ["/api/instagram-fetch", "/api/mobile/auth/refresh"])
        XCTAssertNil(tokenStore.accessToken)
        XCTAssertNil(tokenStore.refreshToken)
    }

    func testAPIClientRetriesSocialImportWithoutAuthorizationOnGatewayTimeout() async throws {
        let tokenStore = InMemoryTokenStore()
        try tokenStore.setAccessToken("social-access-token")
        try tokenStore.setRefreshToken("social-refresh-token")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore,
            session: session
        )

        var requestCount = 0
        var authorizationHeaders: [String?] = []

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }

            switch url.path {
            case "/api/instagram-fetch":
                requestCount += 1
                authorizationHeaders.append(request.value(forHTTPHeaderField: "Authorization"))

                if requestCount == 1 {
                    let timeoutResponse = HTTPURLResponse(
                        url: url,
                        statusCode: 504,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    return (timeoutResponse, Data("{\"error\":\"Gateway Timeout\"}".utf8))
                }

                let okResponse = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                let payload = """
                {
                  "url": "https://www.instagram.com/reel/abc123",
                  "title": "Core Burner",
                  "content": "Plank 3x60s",
                  "timestamp": "2026-03-01T10:00:00Z"
                }
                """
                return (okResponse, Data(payload.utf8))

            default:
                throw TestFailure("Unexpected path: \(url.path)")
            }
        }

        let request = try APIRequest.fetchInstagram(url: "https://www.instagram.com/reel/abc123")
        let response: InstagramFetchResponse = try await apiClient.send(request)

        XCTAssertEqual(response.title, "Core Burner")
        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(authorizationHeaders.count, 2)
        XCTAssertEqual(authorizationHeaders[0], "Bearer social-access-token")
        XCTAssertNil(authorizationHeaders[1])
    }

    func testAPIClientDoesNotLoopSocialImportRetriesAfterSecondGatewayTimeout() async throws {
        let tokenStore = InMemoryTokenStore()
        try tokenStore.setAccessToken("social-access-token")
        try tokenStore.setRefreshToken("social-refresh-token")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore,
            session: session
        )

        var requestCount = 0

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }

            switch url.path {
            case "/api/instagram-fetch":
                requestCount += 1
                let timeoutResponse = HTTPURLResponse(
                    url: url,
                    statusCode: 504,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (timeoutResponse, Data("{\"error\":\"Gateway Timeout\"}".utf8))

            default:
                throw TestFailure("Unexpected path: \(url.path)")
            }
        }

        let request = try APIRequest.fetchInstagram(url: "https://www.instagram.com/reel/abc123")

        do {
            let _: InstagramFetchResponse = try await apiClient.send(request)
            XCTFail("Expected HTTP 504 error")
        } catch let error as APIError {
            guard case .httpStatus(let code, _) = error else {
                XCTFail("Expected HTTP status error, got \(error)")
                return
            }
            XCTAssertEqual(code, 504)
        }

        XCTAssertEqual(requestCount, 2)
    }

    func testInstagramFetchResponseDecodesFlexiblePayloadShapes() throws {
        let payload = """
        {
          "url": "https://www.instagram.com/reel/abc123",
          "title": "Leg Day",
          "content": "Heavy lower-body session",
          "author_name": "Coach Alex",
          "image_url": "https://example.com/cover.jpg",
          "timestamp": 1741020000,
          "media_type": "carousel",
          "quota_used": "3",
          "quota_limit": 10,
          "parsed_workout": {
            "title": "Leg Day",
            "workout_type": "strength",
            "rows": [
              { "exercise": "Back Squat", "sets": "5", "reps": 5, "notes": "heavy" },
              { "exerciseName": "Walking Lunge", "sets": 3, "reps": "12" }
            ],
            "structure": {
              "type": "rounds",
              "rounds": "2"
            },
            "used_llm": "true"
          }
        }
        """

        let response = try JSONCoding.apiDecoder().decode(
            InstagramFetchResponse.self,
            from: Data(payload.utf8)
        )

        XCTAssertEqual(response.author?.fullName, "Coach Alex")
        XCTAssertEqual(response.author?.username, "coachalex")
        XCTAssertEqual(response.image, "https://example.com/cover.jpg")
        XCTAssertEqual(response.quotaUsed, 3)
        XCTAssertEqual(response.quotaLimit, 10)
        XCTAssertEqual(response.parsedWorkout?.exercises?.count, 2)
        XCTAssertEqual(response.parsedWorkout?.exercises?.first?.sets, 5)
        XCTAssertEqual(response.parsedWorkout?.exercises?.first?.reps, "5")
        XCTAssertEqual(response.parsedWorkout?.structure?.rounds, 2)
        XCTAssertEqual(response.parsedWorkout?.usedLLM, true)
    }

    func testFetchedWorkoutOnboardingPreviewUsesStructuredInstagramExercises() {
        let fetchResponse = InstagramFetchResponse(
            url: "https://www.instagram.com/reel/abc123",
            title: "Leg Day Blast",
            content: "Heavy lower-body session",
            author: nil,
            stats: nil,
            image: nil,
            timestamp: "2026-03-09T12:00:00Z",
            mediaType: "image",
            parsedWorkout: nil,
            scanQuotaUsed: nil,
            scanQuotaLimit: nil,
            quotaUsed: nil,
            quotaLimit: nil
        )
        let ingestResponse = WorkoutIngestResponse(
            title: "Leg Day Blast",
            workoutType: "strength",
            exercises: [],
            rows: [
                WorkoutRow(exercise: "Back Squat", sets: 5, reps: "5", weight: nil, notes: nil),
                WorkoutRow(exercise: "Plank", sets: 3, reps: "60s", weight: nil, notes: nil)
            ],
            summary: nil,
            breakdown: nil,
            structure: WorkoutStructure(
                type: "rounds",
                timeLimit: nil,
                rounds: 2,
                interval: nil,
                work: nil,
                rest: "90s"
            ),
            amrapBlocks: nil,
            emomBlocks: nil,
            usedLLM: true,
            workoutV1: nil
        )

        let preview = FetchedWorkout(from: fetchResponse, ingestResponse: ingestResponse).onboardingPreview

        XCTAssertEqual(preview.sourceType, .instagram)
        XCTAssertEqual(preview.exercises.count, 2)
        XCTAssertEqual(preview.exercises[0].sets, 5)
        XCTAssertEqual(preview.exercises[0].reps, 5)
        XCTAssertEqual(preview.exercises[1].duration, 60)
        XCTAssertEqual(preview.rounds, 2)
        XCTAssertEqual(preview.restBetweenSets, "90s")
    }

    @MainActor
    func testEnterGuestModeClearsSessionAndSelectsLibraryTab() async throws {
        let environment = AppEnvironment.preview
        let appState = AppState(environment: environment)
        appState.guestModeManager.reset()

        try environment.tokenStore.setAccessToken("guest-access-token")
        try environment.tokenStore.setRefreshToken("guest-refresh-token")

        try await environment.userRepository.save(.preview)
        _ = try await environment.workoutRepository.create(
            Workout(title: "Previously Synced Workout", source: .manual)
        )

        appState.selectedMainTab = .home

        await appState.enterGuestMode()

        let guestWorkouts = try await environment.workoutRepository.fetchAll()
        let currentUser = try await environment.userRepository.getCurrentUser()

        XCTAssertTrue(appState.isGuestMode)
        XCTAssertEqual(appState.selectedMainTab, .library)
        XCTAssertNil(environment.tokenStore.accessToken)
        XCTAssertNil(environment.tokenStore.refreshToken)
        XCTAssertNil(currentUser)
        XCTAssertTrue(guestWorkouts.isEmpty)
        XCTAssertEqual(try environment.syncEngine.getPendingCount(), 0)
    }

    @MainActor
    func testGuestWorkoutCreateSavesLocallyWithoutQueueingSync() async throws {
        let environment = AppEnvironment.preview
        let appState = AppState(environment: environment)
        appState.guestModeManager.reset()

        await appState.enterGuestMode()

        let savedWorkout = try await environment.workoutRepository.create(
            Workout(title: "Guest Local Workout", content: "3 rounds\\n10 squats", source: .manual)
        )

        let workouts = try await environment.workoutRepository.fetchAll()

        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts.first?.id, savedWorkout.id)
        XCTAssertEqual(try environment.syncEngine.getPendingCount(), 0)
        XCTAssertEqual(appState.guestModeManager.workoutsSaved, 1)
    }

    func testInstagramFetchMapsSourceAuthenticationConstraintFromErrorBody() async throws {
        let tokenStore = InMemoryTokenStore()
        try tokenStore.setAccessToken("source-auth-access-token")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore,
            session: session
        )
        let service = InstagramFetchService(apiClient: apiClient)

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }

            switch url.path {
            case "/api/instagram-fetch":
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                let payload = """
                {"message":"Instagram authentication required to access this post"}
                """
                return (response, Data(payload.utf8))

            default:
                throw TestFailure("Unexpected path: \(url.path)")
            }
        }

        do {
            _ = try await service.fetchInstagramPost(url: "https://www.instagram.com/reel/abc123")
            XCTFail("Expected source authentication error")
        } catch let error as InstagramFetchError {
            switch error {
            case .sourceAuthenticationRequired:
                break
            default:
                XCTFail("Expected sourceAuthenticationRequired, got \(error)")
            }
        }
    }

    func testInstagramFetchMapsSourceAuthenticationConstraintFromErrorCode() async throws {
        let tokenStore = InMemoryTokenStore()
        try tokenStore.setAccessToken("source-auth-access-token")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore,
            session: session
        )
        let service = InstagramFetchService(apiClient: apiClient)

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }

            switch url.path {
            case "/api/instagram-fetch":
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                let payload = """
                {"message":"Authentication required","code":"SOURCE_AUTH_REQUIRED"}
                """
                return (response, Data(payload.utf8))

            default:
                throw TestFailure("Unexpected path: \(url.path)")
            }
        }

        do {
            _ = try await service.fetchInstagramPost(url: "https://www.instagram.com/reel/abc123")
            XCTFail("Expected source authentication error")
        } catch let error as InstagramFetchError {
            switch error {
            case .sourceAuthenticationRequired:
                break
            default:
                XCTFail("Expected sourceAuthenticationRequired, got \(error)")
            }
        }
    }

    func testInstagramFetchMapsUnauthorizedFromAppAuthErrorCode() async throws {
        let tokenStore = InMemoryTokenStore()
        try tokenStore.setAccessToken("app-auth-access-token")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore,
            session: session
        )
        let service = InstagramFetchService(apiClient: apiClient)

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }

            switch url.path {
            case "/api/instagram-fetch":
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                let payload = """
                {"message":"Authentication required","code":"APP_AUTH_REQUIRED"}
                """
                return (response, Data(payload.utf8))

            default:
                throw TestFailure("Unexpected path: \(url.path)")
            }
        }

        do {
            _ = try await service.fetchInstagramPost(url: "https://www.instagram.com/reel/abc123")
            XCTFail("Expected unauthorized error")
        } catch let error as InstagramFetchError {
            switch error {
            case .unauthorized:
                break
            default:
                XCTFail("Expected unauthorized, got \(error)")
            }
        }
    }

    func testInstagramFetchKeepsAppUnauthorizedMappingWhenBackendRequestsSignIn() async throws {
        let tokenStore = InMemoryTokenStore()
        try tokenStore.setAccessToken("app-auth-access-token")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore,
            session: session
        )
        let service = InstagramFetchService(apiClient: apiClient)

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }

            switch url.path {
            case "/api/instagram-fetch":
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                let payload = """
                {"error":"Unauthorized - Please sign in"}
                """
                return (response, Data(payload.utf8))

            default:
                throw TestFailure("Unexpected path: \(url.path)")
            }
        }

        do {
            _ = try await service.fetchInstagramPost(url: "https://www.instagram.com/reel/abc123")
            XCTFail("Expected unauthorized error")
        } catch let error as InstagramFetchError {
            switch error {
            case .unauthorized:
                break
            default:
                XCTFail("Expected unauthorized, got \(error)")
            }
        }
    }

    func testInstagramFetchMapsAmbiguousPleaseLoginMessageToSourceAuthentication() async throws {
        let tokenStore = InMemoryTokenStore()
        try tokenStore.setAccessToken("ambiguous-source-access-token")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore,
            session: session
        )
        let service = InstagramFetchService(apiClient: apiClient)

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }

            switch url.path {
            case "/api/instagram-fetch":
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                let payload = """
                {"error":"error please login"}
                """
                return (response, Data(payload.utf8))

            default:
                throw TestFailure("Unexpected path: \(url.path)")
            }
        }

        do {
            _ = try await service.fetchInstagramPost(url: "https://www.instagram.com/reel/abc123")
            XCTFail("Expected source authentication error")
        } catch let error as InstagramFetchError {
            switch error {
            case .sourceAuthenticationRequired:
                break
            default:
                XCTFail("Expected sourceAuthenticationRequired, got \(error)")
            }
        }
    }

    func testCaptionIngestKeepsUnauthorizedMappingForAmbiguousPleaseLoginMessage() async throws {
        let tokenStore = InMemoryTokenStore()
        try tokenStore.setAccessToken("ambiguous-ingest-access-token")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore,
            session: session
        )
        let service = InstagramFetchService(apiClient: apiClient)

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }

            switch url.path {
            case "/api/ingest":
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                let payload = """
                {"error":"error please login"}
                """
                return (response, Data(payload.utf8))

            default:
                throw TestFailure("Unexpected path: \(url.path)")
            }
        }

        do {
            _ = try await service.parseCaption("Squat 3x10", url: nil)
            XCTFail("Expected unauthorized error")
        } catch let error as InstagramFetchError {
            switch error {
            case .unauthorized:
                break
            default:
                XCTFail("Expected unauthorized, got \(error)")
            }
        }
    }

    func testSyncPayloadIncludesWorkoutMetadataForCreateAndUpdate() throws {
        let workout = Workout(
            id: "workout-metadata-1",
            title: "Metadata Workout",
            content: "3 rounds of squats and lunges",
            enhancementSourceText: "Original creator text",
            source: .instagram,
            durationMinutes: 42,
            exerciseCount: 10,
            difficulty: "advanced",
            imageURL: "https://cdn.kinexfit.com/workouts/workout-metadata-1.png",
            sourceURL: "https://www.instagram.com/p/kinexfit123",
            sourceAuthor: "@coachkinex",
            scheduledDate: "2026-03-07",
            scheduledTime: "08:00",
            status: .scheduled,
            completedDate: "2026-03-07",
            completedAt: "2026-03-07T08:47:00Z",
            durationSeconds: 2820,
            createdAt: Date(timeIntervalSince1970: 1_709_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_709_003_600)
        )

        let payload = SyncPayloadV1.createOrUpdate(workout: workout)
        let data = try JSONCoding.apiEncoder().encode(payload)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let encodedWorkout = try XCTUnwrap(root["workout"] as? [String: Any])

        XCTAssertEqual(encodedWorkout["id"] as? String, "workout-metadata-1")
        XCTAssertEqual(encodedWorkout["workoutId"] as? String, "workout-metadata-1")
        XCTAssertEqual(encodedWorkout["title"] as? String, "Metadata Workout")
        XCTAssertEqual(encodedWorkout["content"] as? String, "3 rounds of squats and lunges")
        XCTAssertEqual(encodedWorkout["enhancementSourceText"] as? String, "Original creator text")
        XCTAssertEqual(encodedWorkout["source"] as? String, "instagram")
        XCTAssertEqual(encodedWorkout["durationMinutes"] as? Int, 42)
        XCTAssertEqual(encodedWorkout["exerciseCount"] as? Int, 10)
        XCTAssertEqual(encodedWorkout["difficulty"] as? String, "advanced")
        XCTAssertEqual(
            encodedWorkout["imageURL"] as? String,
            "https://cdn.kinexfit.com/workouts/workout-metadata-1.png"
        )
        XCTAssertEqual(
            encodedWorkout["sourceURL"] as? String,
            "https://www.instagram.com/p/kinexfit123"
        )
        XCTAssertEqual(encodedWorkout["sourceAuthor"] as? String, "@coachkinex")
        XCTAssertEqual(encodedWorkout["scheduledDate"] as? String, "2026-03-07")
        XCTAssertEqual(encodedWorkout["scheduledTime"] as? String, "08:00")
        XCTAssertEqual(encodedWorkout["status"] as? String, "scheduled")
        XCTAssertEqual(encodedWorkout["completedDate"] as? String, "2026-03-07")
        XCTAssertEqual(encodedWorkout["completedAt"] as? String, "2026-03-07T08:47:00Z")
        XCTAssertEqual(encodedWorkout["durationSeconds"] as? Int, 2820)
        XCTAssertNotNil(encodedWorkout["createdAt"] as? String)
        XCTAssertNotNil(encodedWorkout["updatedAt"] as? String)
    }

    func testLiveAPIBaseURLUsesWWWHost() {
        XCTAssertEqual(AppConfig.apiBaseURL.absoluteString, "https://www.kinexfit.com")
    }

    func testEmailPasswordSignIn404ReturnsMobileUnavailableMessage() async throws {
        let database = try AppDatabase.inMemory()
        let tokenStore = InMemoryTokenStore()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let service = EmailPasswordAuthService(
            apiClient: APIClient(baseURL: AppConfig.apiBaseURL, tokenStore: tokenStore, session: session),
            tokenStore: tokenStore,
            database: database
        )

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }

            XCTAssertEqual(url.path, "/api/mobile/auth/signin-credentials")

            let response = HTTPURLResponse(
                url: url,
                statusCode: 404,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            return (response, Data("{\"error\":\"Not Found\"}".utf8))
        }

        do {
            _ = try await service.signIn(email: "user@example.com", password: "Password1!")
            XCTFail("Expected sign in to fail")
        } catch let error as AuthError {
            XCTAssertEqual(
                error.localizedDescription,
                "Email/password sign in is temporarily unavailable on mobile. Please use Apple, Google, or Facebook."
            )
        }
    }

    func testEmailPasswordSignUp404ReturnsMobileUnavailableMessage() async throws {
        let database = try AppDatabase.inMemory()
        let tokenStore = InMemoryTokenStore()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let service = EmailPasswordAuthService(
            apiClient: APIClient(baseURL: AppConfig.apiBaseURL, tokenStore: tokenStore, session: session),
            tokenStore: tokenStore,
            database: database
        )

        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw TestFailure("Missing request URL")
            }

            XCTAssertEqual(url.path, "/api/mobile/auth/signup")

            let response = HTTPURLResponse(
                url: url,
                statusCode: 404,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            return (response, Data("{\"error\":\"Not Found\"}".utf8))
        }

        do {
            _ = try await service.signUp(
                email: "user@example.com",
                password: "Password1!",
                firstName: "Test",
                lastName: "User"
            )
            XCTFail("Expected sign up to fail")
        } catch let error as AuthError {
            XCTAssertEqual(
                error.localizedDescription,
                "Email/password sign up is temporarily unavailable on mobile. Please use Apple, Google, or Facebook."
            )
        }
    }
}

final class WorkoutRoundsParsingTests: XCTestCase {
    func testPresentationRoundsFallbackToSets() {
        let presentation = WorkoutContentPresentation.from(
            content: """
            3 rounds:
            10 pushups
            10 situps
            10 squats
            """,
            source: .instagram,
            durationMinutes: nil,
            fallbackExerciseCount: nil
        )

        XCTAssertEqual(presentation.rounds, 3)

        let cards = EditableWorkoutCard.from(presentation: presentation)
        XCTAssertEqual(cards.count, 3)
        XCTAssertEqual(cards.map(\.sets), ["3", "3", "3"])
        XCTAssertEqual(cards.map(\.reps), ["10", "10", "10"])
    }

    func testAIEnhancedRoundsFallbackToSets() {
        let exercises = [
            EnhancedExercise(
                id: "e1",
                name: "Pushups",
                sets: nil,
                reps: .int(10),
                weight: nil,
                restSeconds: nil,
                notes: nil,
                duration: nil
            ),
            EnhancedExercise(
                id: "e2",
                name: "Situps",
                sets: nil,
                reps: .int(10),
                weight: nil,
                restSeconds: nil,
                notes: nil,
                duration: nil
            )
        ]

        let cards = EditableWorkoutCard.from(enhancedExercises: exercises, rounds: 3)
        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(cards.map(\.sets), ["3", "3"])
    }

    func testAIExplicitSetsWinOverRoundsFallback() {
        let exercises = [
            EnhancedExercise(
                id: "e1",
                name: "Pushups",
                sets: 4,
                reps: .int(10),
                weight: nil,
                restSeconds: nil,
                notes: nil,
                duration: nil
            )
        ]

        let cards = EditableWorkoutCard.from(enhancedExercises: exercises, rounds: 3)
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards.first?.sets, "4")
    }
}

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: TestFailure("MockURLProtocol handler is not set"))
            return
        }

        do {
            let (response, data) = try requestHandler(Self.materializedRequestBody(from: request))
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func reset() {
        requestHandler = nil
    }

    private static func materializedRequestBody(from request: URLRequest) -> URLRequest {
        guard request.httpBody == nil, let stream = request.httpBodyStream else {
            return request
        }

        var request = request
        request.httpBody = readAllBytes(from: stream)
        return request
    }

    private static func readAllBytes(from stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: bufferSize)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }

        return data
    }
}

private struct TestFailure: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
