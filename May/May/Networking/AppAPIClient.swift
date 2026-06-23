import Foundation

protocol APITransport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: APITransport {}

enum APIError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case http(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "服务地址尚未配置"
        case .invalidResponse:
            "服务器返回了无法识别的响应"
        case .http(_, let message):
            message
        }
    }
}

struct LoginAccount: Decodable {
    let id: String
    let phone: String?
    let nickname: String?
}

struct LoginResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let account: LoginAccount
}

struct SMSResponse: Decodable {
    let sent: Bool
    let debugCode: String?
}

struct AppAPIClient {
    let baseURL: URL
    private let transport: APITransport
    private let encoder = JSONEncoder()
    private let decoder: JSONDecoder

    init(
        baseURL: URL = AppConfiguration.apiBaseURL,
        transport: APITransport = URLSession.shared
    ) {
        self.baseURL = baseURL
        self.transport = transport
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    func sendSMS(phone: String) async throws -> SMSResponse {
        try await request(
            path: "/v1/auth/sms/send",
            method: "POST",
            body: ["phone": phone]
        )
    }

    func login(phone: String, code: String) async throws -> LoginResponse {
        try await request(
            path: "/v1/auth/login",
            method: "POST",
            body: ["phone": phone, "code": code]
        )
    }

    func deleteAccount(confirmation: String, token: String) async throws {
        try await requestNoContent(
            path: "/v1/auth/me",
            method: "DELETE",
            body: ["confirmation": confirmation],
            token: token
        )
    }

    func communityFeed(token: String) async throws -> [CommunityPost] {
        let response: CommunityFeedDTO = try await request(
            path: "/v1/community/feed",
            method: "GET",
            token: token
        )
        return response.posts.map(\.model)
    }

    func communityPostDetail(
        postID: String,
        token: String
    ) async throws -> (CommunityPost, [CommunityComment]) {
        let response: CommunityPostDetailDTO = try await request(
            path: "/v1/community/posts/\(postID)",
            method: "GET",
            token: token
        )
        return (response.post.model, response.comments.map(\.model))
    }

    func createCommunityPost(
        summary: String,
        body: String,
        tags: [String],
        token: String
    ) async throws -> CommunityPost {
        let response: CommunityPostDTO = try await request(
            path: "/v1/community/posts",
            method: "POST",
            body: CreateCommunityPostBody(summary: summary, body: body, tags: tags),
            token: token
        )
        return response.model
    }

    func createCommunityComment(
        postID: String,
        body: String,
        token: String
    ) async throws -> CommunityComment {
        let response: CommunityCommentDTO = try await request(
            path: "/v1/community/posts/\(postID)/comments",
            method: "POST",
            body: ["body": body],
            token: token
        )
        return response.model
    }

    func deleteCommunityPost(id: String, token: String) async throws {
        try await requestNoContent(
            path: "/v1/community/posts/\(id)",
            method: "DELETE",
            token: token
        )
    }

    func deleteCommunityComment(id: String, token: String) async throws {
        try await requestNoContent(
            path: "/v1/community/comments/\(id)",
            method: "DELETE",
            token: token
        )
    }

    func reportCommunityContent(
        targetType: String,
        targetID: String,
        reason: CommunityReportReason,
        token: String
    ) async throws {
        let _: CommunityReportDTO = try await request(
            path: "/v1/community/reports",
            method: "POST",
            body: CommunityReportBody(
                targetType: targetType,
                targetID: targetID,
                reason: reason.rawValue,
                details: ""
            ),
            token: token
        )
    }

    func blockCommunityAccount(id: String, token: String) async throws {
        let _: CommunityBlockDTO = try await request(
            path: "/v1/community/blocks/\(id)",
            method: "POST",
            body: EmptyBody(),
            token: token
        )
    }

    func unblockCommunityAccount(id: String, token: String) async throws {
        try await requestNoContent(
            path: "/v1/community/blocks/\(id)",
            method: "DELETE",
            token: token
        )
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        token: String? = nil
    ) async throws -> Response {
        try await perform(request: makeRequest(path: path, method: method, token: token))
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body,
        token: String? = nil
    ) async throws -> Response {
        var request = makeRequest(path: path, method: method, token: token)
        request.httpBody = try encoder.encode(body)

        return try await perform(request: request)
    }

    private func requestNoContent(
        path: String,
        method: String,
        token: String? = nil
    ) async throws {
        try await performNoContent(
            request: makeRequest(path: path, method: method, token: token)
        )
    }

    private func requestNoContent<Body: Encodable>(
        path: String,
        method: String,
        body: Body,
        token: String? = nil
    ) async throws {
        var request = makeRequest(path: path, method: method, token: token)
        request.httpBody = try encoder.encode(body)
        try await performNoContent(request: request)
    }

    private func makeRequest(path: String, method: String, token: String?) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func perform<Response: Decodable>(request: URLRequest) async throws -> Response {
        let data = try await responseData(for: request)
        return try decoder.decode(Response.self, from: data)
    }

    private func performNoContent(request: URLRequest) async throws {
        _ = try await responseData(for: request)
    }

    private func responseData(for request: URLRequest) async throws -> Data {

        let (data, response) = try await transport.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.http(
                status: httpResponse.statusCode,
                message: serverMessage(from: data, status: httpResponse.statusCode)
            )
        }

        return data
    }

    private func serverMessage(from data: Data, status: Int) -> String {
        struct ErrorPayload: Decodable { let detail: String }
        if let payload = try? decoder.decode(ErrorPayload.self, from: data) {
            return payload.detail
        }
        return "请求失败（\(status)）"
    }
}

private struct EmptyBody: Encodable {}

private struct CreateCommunityPostBody: Encodable {
    let summary: String
    let body: String
    let tags: [String]
}

private struct CommunityReportBody: Encodable {
    let targetType: String
    let targetID: String
    let reason: String
    let details: String

    enum CodingKeys: String, CodingKey {
        case targetType = "target_type"
        case targetID = "target_id"
        case reason
        case details
    }
}

private struct CommunityFeedDTO: Decodable {
    let posts: [CommunityPostDTO]
}

private struct CommunityPostDetailDTO: Decodable {
    let post: CommunityPostDTO
    let comments: [CommunityCommentDTO]
}

private struct CommunityAuthorDTO: Decodable {
    let id: String
    let name: String
    let subtitle: String
    let avatarInitial: String

    var model: CommunityAuthor {
        CommunityAuthor(id: id, name: name, subtitle: subtitle, avatarInitial: avatarInitial)
    }
}

private struct CommunityStatsDTO: Decodable {
    let likes: Int
    let comments: Int
    let saves: Int

    var model: CommunityStats {
        CommunityStats(likes: likes, comments: comments, saves: saves)
    }
}

private struct CommunityPostDTO: Decodable {
    let id: String
    let author: CommunityAuthorDTO
    let summary: String
    let body: String
    let createdAt: String
    let tags: [String]
    let parts: [String]
    let stats: CommunityStatsDTO
    let isPinned: Bool
    let isOwnedByCurrentAccount: Bool

    var model: CommunityPost {
        CommunityPost(
            id: id,
            author: author.model,
            summary: summary,
            body: body,
            createdAt: createdAt,
            tags: tags,
            parts: parts,
            stats: stats.model,
            isPinned: isPinned,
            image: nil,
            isOwnedByCurrentAccount: isOwnedByCurrentAccount
        )
    }
}

private struct CommunityCommentDTO: Decodable {
    let id: String
    let author: CommunityAuthorDTO
    let body: String
    let createdAt: String
    let isOwnedByCurrentAccount: Bool

    var model: CommunityComment {
        CommunityComment(
            id: id,
            author: author.model,
            body: body,
            createdAt: createdAt,
            isOwnedByCurrentAccount: isOwnedByCurrentAccount
        )
    }
}

private struct CommunityReportDTO: Decodable { let id: String }
private struct CommunityBlockDTO: Decodable { let id: String }

enum AppConfiguration {
    static var apiBaseURL: URL {
        if let value = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           let url = URL(string: value),
           let scheme = url.scheme,
           ["http", "https"].contains(scheme) {
            return url
        }

        return URL(string: "http://127.0.0.1:8790")!
    }
}
