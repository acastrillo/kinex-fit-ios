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
            let (response, data) = try requestHandler(request)
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
