import Foundation

struct APIClient {
    let baseURL: URL
    let tokenStore: TokenStore
    let session: URLSession

    init(baseURL: URL, tokenStore: TokenStore, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.session = session
    }

    func send(_ request: APIRequest) async throws -> Data {
        var url = baseURL.appendingPathComponent(request.path)
        if !request.queryItems.isEmpty {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw APIError.invalidURL
            }
            components.queryItems = request.queryItems
            guard let resolved = components.url else {
                throw APIError.invalidURL
            }
            url = resolved
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        request.headers.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        if let token = tokenStore.accessToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.httpStatus(httpResponse.statusCode)
        }
        return data
    }

    func send<T: Decodable>(_ request: APIRequest, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
        let data = try await send(request)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case decoding(Error)
}
