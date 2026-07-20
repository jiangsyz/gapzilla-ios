import Foundation

private struct APIResponseStatus: Decodable {
    let code: Int
    let message: String
}

enum APIClientError: LocalizedError {
    case invalidResponse
    case unauthorized
    case server(code: Int, message: String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "服务器返回了无法识别的数据。"
        case .unauthorized: "登录已过期，请重新登录。"
        case let .server(_, message): message
        case let .transport(message): message
        }
    }
}

actor APIClient {
    static let production = APIClient(baseURL: URL(string: "https://api.gapzilla.quietbase.online")!)
#if DEBUG
    static let app = APIClient(baseURL: URL(string: "http://localhost:8888")!)
#else
    static let app = production
#endif

    private let baseURL: URL
    private let session: URLSession
    private var accessToken: String?
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func setAccessToken(_ token: String?) { accessToken = token }

    func get<Value: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> Value {
        try await request(path, method: "GET", query: query, body: Optional<String>.none)
    }

    func post<Value: Decodable, Body: Encodable>(_ path: String, body: Body) async throws -> Value {
        try await request(path, method: "POST", body: body)
    }

    func patch<Value: Decodable, Body: Encodable>(_ path: String, body: Body) async throws -> Value {
        try await request(path, method: "PATCH", body: body)
    }

    func delete<Value: Decodable>(_ path: String) async throws -> Value {
        try await request(path, method: "DELETE", body: Optional<String>.none)
    }

    private func request<Value: Decodable, Body: Encodable>(
        _ path: String,
        method: String,
        query: [URLQueryItem] = [],
        body: Body?
    ) async throws -> Value {
        guard var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw APIClientError.invalidResponse
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIClientError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIClientError.invalidResponse }
            if http.statusCode == 401 { throw APIClientError.unauthorized }
            let status = try decoder.decode(APIResponseStatus.self, from: data)
            guard status.code == 0 else {
                throw APIClientError.server(code: status.code, message: status.message)
            }
            let envelope = try decoder.decode(APIEnvelope<Value>.self, from: data)
            return envelope.data
        } catch let error as APIClientError {
            throw error
        } catch let error as DecodingError {
            throw APIClientError.transport("数据解析失败：\(error.localizedDescription)")
        } catch {
            throw APIClientError.transport(error.localizedDescription)
        }
    }
}
