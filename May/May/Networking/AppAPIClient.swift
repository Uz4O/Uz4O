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

    func buildOptions(
        budget: Int,
        useCase: String,
        gameCategories: [String]
    ) async throws -> BuildOptionsResponseDTO {
        try await request(
            path: "/v1/build/options",
            method: "POST",
            body: BuildOptionsRequestDTO(
                budget: budget,
                useCase: useCase,
                gameCategories: gameCategories
            )
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

    func analyzeConfigReviewText(_ text: String) async throws -> ConfigReviewResponseDTO {
        try await request(
            path: "/v1/review/analyze",
            method: "POST",
            body: ["text": text]
        )
    }

    func analyzeConfigReviewImage(imageData: Data) async throws -> ConfigReviewResponseDTO {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = makeRequest(path: "/v1/review/analyze/image", method: "POST", token: nil)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Disposition: form-data; name=\"image\"; filename=\"config.jpg\"\r\n")
        body.appendUTF8("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.appendUTF8("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        return try await perform(request: request)
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

private extension Data {
    mutating func appendUTF8(_ string: String) {
        append(contentsOf: string.utf8)
    }
}

private struct EmptyBody: Encodable {}

private struct BuildOptionsRequestDTO: Encodable {
    let budget: Int
    let useCase: String
    let gameCategories: [String]

    enum CodingKeys: String, CodingKey {
        case budget
        case useCase = "use_case"
        case gameCategories = "game_categories"
    }
}

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

enum BuildDirectionDTO: String, Decodable {
    case fps
    case aaa
    case balanced
}

enum BuildPurchaseModeDTO: String, Decodable {
    case new
    case used
    case mixed
}

enum BuildOptionStatusDTO: String, Decodable {
    case ready
}

enum BuildOptionSourceDTO: String, Decodable {
    case template
}

enum BuildPartRoleDTO: String, CaseIterable, Decodable {
    case cpu
    case motherboard
    case gpu
    case ram
    case storage
    case psu
    case cooler
    case `case`
}

enum BuildPartConditionDTO: String, Decodable {
    case new
    case used
}

enum BuildCompatibilityLevelDTO: String, Decodable {
    case pass
    case warning
    case error
}

struct BuildOptionsResponseDTO: Decodable {
    let direction: BuildDirectionDTO
    let options: [BuildOptionDTO]
    let unavailableModes: [BuildPurchaseModeDTO]
}

struct BuildOptionDTO: Decodable, Identifiable {
    var id: String { templateId }
    var templateID: String { templateId }

    let status: BuildOptionStatusDTO
    let source: BuildOptionSourceDTO
    private let templateId: String
    let title: String
    let components: [String: String]
    let estimatedTotal: Int?
    let explanation: String
    let details: BuildOptionDetailsDTO
    let compatibility: BuildCompatibilityDTO
}

struct BuildOptionDetailsDTO: Decodable {
    let targetBudget: Int
    let direction: BuildDirectionDTO
    let purchaseMode: BuildPurchaseModeDTO
    let parts: [BuildOptionPartDTO]
    let advantages: [String]
    let disadvantages: [String]
    let risks: [String]
    let suitableUser: String
    let priceDate: String
}

struct BuildOptionPartDTO: Decodable {
    let role: BuildPartRoleDTO
    let componentId: String
    let name: String
    let condition: BuildPartConditionDTO
    let referencePrice: Int
    let priceSource: String
    let priceDate: String
}

struct BuildCompatibilityDTO: Decodable {
    let compatible: Bool
    let summary: String
    let findings: [BuildCompatibilityFindingDTO]
    let findingCounts: [String: Int]
    let checkedRuleCodes: [String]
}

struct BuildCompatibilityFindingDTO: Decodable {
    let level: BuildCompatibilityLevelDTO
    let code: String
    let title: String
    let detail: String
    let componentIds: [String]
}

struct ConfigReviewResponseDTO: Decodable {
    let riskLevel: String
    let summary: String
    let sourceText: String
    let sellerPrice: Int?
    let referenceTotal: Int?
    let findings: [ConfigReviewFindingDTO]
    let questionsForSeller: [String]
    let replyText: String
}

struct ConfigReviewFindingDTO: Decodable, Identifiable {
    var id: String { code }

    let level: String
    let code: String
    let title: String
    let detail: String
}

enum AppConfiguration {
    static var apiBaseURL: URL {
#if DEBUG
        return URL(string: "http://127.0.0.1:8790")!
#else
        return URL(string: "https://api.uzbox.top")!
#endif
    }
}
