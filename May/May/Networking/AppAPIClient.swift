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

enum CatalogJSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: CatalogJSONValue])
    case array([CatalogJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode([String: CatalogJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([CatalogJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "无法解析目录规格"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

struct CatalogComponentDTO: Codable, Identifiable {
    let id: String
    let category: String
    let name: String
    let brand: String
    let detailRaw: String
    let specs: [String: CatalogJSONValue]
    let isRecommended: Bool
    let status: String
}

struct CatalogPriceDTO: Codable {
    let componentId: String
    let referencePrice: Int
    let priceRangeLow: Int?
    let priceRangeHigh: Int?
    let source: String
}

struct DIYCatalogSnapshot: Codable {
    let components: [CatalogComponentDTO]
    let prices: [String: CatalogPriceDTO]
}

enum DIYCatalogCache {
    private static let fileName = "diy-catalog-v1.json"

    private static var fileURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
    }

    static func load() -> DIYCatalogSnapshot? {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(DIYCatalogSnapshot.self, from: data)
    }

    static func save(_ snapshot: DIYCatalogSnapshot) {
        guard let fileURL,
              let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

struct PerformanceHardwareDTO: Encodable {
    let cpu: String
    let gpu: String
}

struct PerformanceEstimateRequestDTO: Encodable {
    let hardware: PerformanceHardwareDTO
    let resolution: String
    let games: [String]
}

struct GamePerformanceResultDTO: Decodable {
    let game: String
    let averageFps: Int

    var model: GamePerformanceResult {
        GamePerformanceResult(
            gameID: game,
            averageFPS: averageFps
        )
    }
}

struct PerformanceEstimateResponseDTO: Decodable {
    let status: String
    let averageFps: Int?
    let missingGames: [String]
    let gameResults: [GamePerformanceResultDTO]

    var model: PerformanceEstimatePayload {
        PerformanceEstimatePayload(
            status: PerformanceEstimateStatus(rawValue: status) ?? .needsMoreData,
            averageFPS: averageFps,
            missingGames: missingGames,
            gameResults: gameResults.map(\.model)
        )
    }
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
        gameCategories: [String],
        direction: String,
        officeApps: [String],
        needsWirelessNetwork: Bool,
        memorySize: String,
        storageSize: String,
        noGPUBuild: Bool,
        ownedGPUModel: String?
    ) async throws -> BuildOptionsResponseDTO {
        let response: BuildOptionsResponseDTO = try await request(
            path: "/v1/build/options",
            method: "POST",
            body: BuildOptionsRequestDTO(
                budget: budget,
                useCase: useCase,
                gameCategories: gameCategories,
                direction: direction,
                officeApps: officeApps,
                needsWirelessNetwork: needsWirelessNetwork,
                memorySize: memorySize,
                storageSize: storageSize,
                noGPUBuild: noGPUBuild,
                ownedGPUModel: ownedGPUModel
            )
        )
        guard response.hasValidPartRoles else {
            throw APIError.invalidResponse
        }
        return response
    }

    func selectBuildOption(selectionID: String) async throws {
        let _: BuildSelectionConfirmationDTO = try await request(
            path: "/v1/build/options/\(selectionID)/select",
            method: "POST",
            body: EmptyBody()
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

    func estimatePerformance(
        cpuID: String,
        gpuID: String,
        resolution: String,
        gameIDs: [String]
    ) async throws -> PerformanceEstimateResponseDTO {
        try await request(
            path: "/v1/perf/estimate",
            method: "POST",
            body: PerformanceEstimateRequestDTO(
                hardware: PerformanceHardwareDTO(cpu: cpuID, gpu: gpuID),
                resolution: resolution,
                games: gameIDs
            )
        )
    }

    func diyCatalog() async throws -> DIYCatalogSnapshot {
        DIYCatalogSnapshot(
            components: try await diyComponents(),
            prices: try await diyPrices()
        )
    }

    func diyComponents(category: String? = nil) async throws -> [CatalogComponentDTO] {
        var components: [CatalogComponentDTO] = []
        var offset = 0
        let pageSize = 500
        let categoryQuery = category.map { "&category=\($0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0)" } ?? ""
        while true {
            let page: [CatalogComponentDTO] = try await request(
                path: "/v1/catalog/components?limit=\(pageSize)&offset=\(offset)\(categoryQuery)",
                method: "GET"
            )
            components.append(contentsOf: page)
            if page.count < pageSize { break }
            offset += page.count
        }
        return components
    }

    func diyPrices() async throws -> [String: CatalogPriceDTO] {
        var prices: [String: CatalogPriceDTO] = [:]
        var offset = 0
        let pageSize = 500
        while true {
            let page: [CatalogPriceDTO] = try await request(
                path: "/v1/catalog/prices?limit=\(pageSize)&offset=\(offset)",
                method: "GET"
            )
            for price in page {
                prices[price.componentId] = price
            }
            if page.count < pageSize { break }
            offset += page.count
        }
        return prices
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
        let url = URL(string: path, relativeTo: baseURL)?.absoluteURL ?? baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
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
    let direction: String
    let officeApps: [String]
    let needsWirelessNetwork: Bool
    let memorySize: String
    let storageSize: String
    let noGPUBuild: Bool
    let ownedGPUModel: String?

    enum CodingKeys: String, CodingKey {
        case budget
        case useCase = "use_case"
        case gameCategories = "game_categories"
        case direction
        case officeApps = "office_apps"
        case needsWirelessNetwork = "needs_wireless_network"
        case memorySize = "memory_size"
        case storageSize = "storage_size"
        case noGPUBuild = "no_gpu_build"
        case ownedGPUModel = "owned_gpu_model"
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
    case aiProvider = "ai_provider"
    case selectionCache = "selection_cache"
}

enum BuildPartRoleDTO: String, CaseIterable, Decodable, Hashable {
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
    case owned
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
    let selectionId: String?
    let title: String
    let components: [String: String]
    let estimatedTotal: Int?
    let explanation: String
    let details: BuildOptionDetailsDTO
}

private struct BuildSelectionConfirmationDTO: Decodable {
    let selectionId: String
    let selectedCount: Int
}

struct BuildOptionDetailsDTO: Decodable {
    let targetBudget: Int
    let direction: BuildDirectionDTO
    let purchaseMode: BuildPurchaseModeDTO
    let parts: [BuildOptionPartDTO]
    let extras: [BuildOptionExtraDTO]?
    let suitableUser: String
    let priceDate: String
}

struct BuildOptionExtraDTO: Decodable {
    let id: String
    let name: String
    let condition: BuildPartConditionDTO
    let referencePrice: Int
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

private extension BuildOptionsResponseDTO {
    var hasValidPartRoles: Bool {
        let requiredRoles = Set(BuildPartRoleDTO.allCases)
        return options.allSatisfy { option in
            let roles = option.details.parts.map(\.role)
            return roles.count == requiredRoles.count && Set(roles) == requiredRoles
        }
    }
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
        return URL(string: "https://api.uzbox.top")!
    }
}
