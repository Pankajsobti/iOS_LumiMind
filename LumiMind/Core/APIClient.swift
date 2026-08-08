//
//  APIClient.swift
//  LumiMind
//
//  Generic networking layer. Every future ViewModel routes its calls
//  through `APIClient.shared.request(...)` — no URLSession calls should
//  appear anywhere else in the app.
//
//  Endpoint paths/query building live in the `Endpoint` enum below so
//  there are zero hardcoded path strings outside of it.
//

import Foundation

// MARK: - HTTPMethod

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - Endpoint
//
// One case per route on the locked contract (see API_CONTRACT.md).
// Adding a new backend route means adding a case here — nowhere else
// in the app should construct a path string.

enum Endpoint {
    case signup
    case login
    case onboarding
    case me
    case meStats
    case gameResults
    case gameResultsList(category: String?, limit: Int?)

    var path: String {
        switch self {
        case .signup: return "/auth/signup"
        case .login: return "/auth/login"
        case .onboarding: return "/users/onboarding"
        case .me: return "/users/me"
        case .meStats: return "/users/me/stats"
        case .gameResults, .gameResultsList: return "/game-results"
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .gameResultsList(let category, let limit):
            var items: [URLQueryItem] = []
            if let category { items.append(URLQueryItem(name: "category", value: category)) }
            if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
            return items.isEmpty ? nil : items
        default:
            return nil
        }
    }
}

// MARK: - APIClientError

enum APIClientError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case missingToken
    case decodingFailed
    case encodingFailed
    case server(message: String, statusCode: Int)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL was invalid."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .missingToken:
            return "You need to be signed in to do that."
        case .decodingFailed:
            return "Couldn't understand the server's response."
        case .encodingFailed:
            return "Couldn't prepare the request."
        case .server(let message, _):
            return message
        case .network(let description):
            return description
        }
    }

    /// The HTTP status code, when this error came from a server response.
    var statusCode: Int? {
        if case .server(_, let statusCode) = self { return statusCode }
        return nil
    }
}

// MARK: - APIClient

final class APIClient {
    static let shared = APIClient()

    /// Locked base URL — see API_CONTRACT.md.
    private let baseURL = URL(string: "http://localhost:5000/api/v1")!

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let keychain: KeychainManager

    init(session: URLSession = .shared, keychain: KeychainManager = .shared) {
        self.session = session
        self.keychain = keychain

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    /// Performs a request against the given endpoint and decodes the
    /// response body as `T`.
    ///
    /// - Parameters:
    ///   - endpoint: which route to hit (see `Endpoint`).
    ///   - method: HTTP method.
    ///   - body: an `Encodable` request body, or `nil` for bodyless requests.
    ///   - requiresAuth: when `true`, attaches `Authorization: Bearer <token>`
    ///     from Keychain, or throws `.missingToken` if none is stored.
    func request<T: Decodable>(
        endpoint: Endpoint,
        method: HTTPMethod,
        body: Encodable? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIClientError.invalidURL
        }
        components.queryItems = endpoint.queryItems

        guard let url = components.url else {
            throw APIClientError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            guard let token = keychain.getToken() else {
                throw APIClientError.missingToken
            }
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            do {
                urlRequest.httpBody = try encoder.encode(AnyEncodable(body))
            } catch {
                throw APIClientError.encodingFailed
            }
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIClientError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIClientError.server(message: apiError.error, statusCode: httpResponse.statusCode)
            }
            throw APIClientError.server(
                message: "Request failed with status \(httpResponse.statusCode).",
                statusCode: httpResponse.statusCode
            )
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIClientError.decodingFailed
        }
    }
}

// MARK: - AnyEncodable
//
// Type-erasing wrapper so `request(...)` can accept `body: Encodable?`
// (an existential) and still hand JSONEncoder a concrete Encodable.

private struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        self.encodeFunc = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}