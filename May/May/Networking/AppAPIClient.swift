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

struct DIYPowerRecommendationResponseDTO: Decodable {
    let recommendedPsuWatt: Int?
}

private struct DIYCompatibilityRequestDTO: Encodable {
    let components: [String: String]
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
    let gpuTimeSpyScore: Int?
    let missingGames: [String]
    let gameResults: [GamePerformanceResultDTO]

    var model: PerformanceEstimatePayload {
        PerformanceEstimatePayload(
            status: PerformanceEstimateStatus(rawValue: status) ?? .needsMoreData,
            averageFPS: averageFps,
            gpuTimeSpyScore: gpuTimeSpyScore,
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

    func loginWithApple(
        identityToken: String,
        authorizationCode: String?,
        nonce: String
    ) async throws -> LoginResponse {
        try await request(
            path: "/v1/auth/apple/login",
            method: "POST",
            body: AppleLoginRequestDTO(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                nonce: nonce
            )
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
        allowsFlexibleBudget: Bool,
        noGPUBuild: Bool,
        ownedGPUModel: String?,
        aestheticStyle: AestheticBuildSelection? = nil
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
                allowsFlexibleBudget: allowsFlexibleBudget,
                noGPUBuild: noGPUBuild,
                ownedGPUModel: ownedGPUModel,
                aestheticStyle: aestheticStyle
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
            body: ConfigReviewRequestDTO(text: text)
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

    func upgradePlan(_ body: UpgradePlanRequestDTO) async throws -> UpgradePlanResponseDTO {
        try await request(
            path: "/v1/upgrade/plan",
            method: "POST",
            body: body
        )
    }

    func saveUpgradePlan(
        _ plan: UpgradePlanResponseDTO,
        title: String,
        token: String
    ) async throws -> SavedUpgradePlanDTO {
        try await request(
            path: "/v1/builds",
            method: "POST",
            body: SaveUpgradePlanRequestDTO(
                title: title,
                plan: plan,
                budget: plan.budget,
                totalPrice: plan.totalEstimatedPrice,
                useCase: "游戏升级"
            ),
            token: token
        )
    }

    func savedUpgradePlans(token: String) async throws -> [SavedUpgradePlanDTO] {
        let useCase = "游戏升级".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            ?? "游戏升级"
        return try await request(
            path: "/v1/builds?use_case=\(useCase)",
            method: "GET",
            token: token
        )
    }

    func diyCatalog() async throws -> DIYCatalogSnapshot {
        DIYCatalogSnapshot(
            components: try await diyComponents(),
            prices: try await diyPrices()
        )
    }

    func diyRecommendedPSUWatt(cpuID: String, gpuID: String) async throws -> Int? {
        let response: DIYPowerRecommendationResponseDTO = try await request(
            path: "/v1/compat/check",
            method: "POST",
            body: DIYCompatibilityRequestDTO(
                components: ["cpu": cpuID, "gpu": gpuID]
            )
        )
        return response.recommendedPsuWatt
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
        do {
            return try decoder.decode(Response.self, from: data)
        } catch is DecodingError {
            throw APIError.invalidResponse
        }
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

private struct ConfigReviewRequestDTO: Encodable {
    let text: String
}

private extension Data {
    mutating func appendUTF8(_ string: String) {
        append(contentsOf: string.utf8)
    }
}

private struct EmptyBody: Encodable {}

private struct AppleLoginRequestDTO: Encodable {
    let identityToken: String
    let authorizationCode: String?
    let nonce: String

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
        case authorizationCode = "authorization_code"
        case nonce
    }
}

private struct BuildOptionsRequestDTO: Encodable {
    let budget: Int
    let useCase: String
    let gameCategories: [String]
    let direction: String
    let officeApps: [String]
    let needsWirelessNetwork: Bool
    let memorySize: String
    let storageSize: String
    let allowsFlexibleBudget: Bool
    let noGPUBuild: Bool
    let ownedGPUModel: String?
    let aestheticStyle: AestheticBuildSelection?

    enum CodingKeys: String, CodingKey {
        case budget
        case useCase = "use_case"
        case gameCategories = "game_categories"
        case direction
        case officeApps = "office_apps"
        case needsWirelessNetwork = "needs_wireless_network"
        case memorySize = "memory_size"
        case storageSize = "storage_size"
        case allowsFlexibleBudget = "allows_flexible_budget"
        case noGPUBuild = "no_gpu_build"
        case ownedGPUModel = "owned_gpu_model"
        case aestheticStyle = "aesthetic_style"
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
    let unavailableModeReasons: [String: String]?
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
    let usedGpuAlternative: UsedGPUAlternativeDTO?
    let aestheticStyleId: String?
    let aestheticStyleName: String?
    let aestheticColor: String?
    let performanceTotal: Int?
    let appearanceTotal: Int?
    let suitableUser: String
    let priceDate: String
}

struct UsedGPUAlternativeDTO: Decodable {
    let componentId: String
    let name: String
    let referencePrice: Int
    let priceDifference: Int
    let performanceComparison: String
    let gamingPerformanceGainPercent: Int?
}

struct BuildOptionExtraDTO: Decodable {
    let id: String
    let name: String
    let condition: BuildPartConditionDTO
    let referencePrice: Int
    let category: String?
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
    let direction: String
    let resolution: String
    let pairingRating: ConfigReviewRatingDTO
    let performanceRating: ConfigReviewRatingDTO
    let detectedComponents: [String: ConfigReviewDetectedComponentDTO]
    let findings: [ConfigReviewFindingDTO]
    let recommendations: [ConfigReviewRecommendationDTO]
    let questionsForSeller: [String]
    let replyText: String
    let webSearchStatus: String
    let webSources: [ConfigReviewSourceDTO]

    private enum CodingKeys: String, CodingKey {
        case riskLevel, summary, sourceText, direction, resolution
        case pairingRating, performanceRating, detectedComponents, findings, recommendations
        case questionsForSeller, replyText, webSearchStatus, webSources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let hasCurrentContract = container.contains(.pairingRating)
            && container.contains(.performanceRating)
        riskLevel = hasCurrentContract
            ? try container.decodeIfPresent(String.self, forKey: .riskLevel) ?? "warning"
            : "warning"
        summary = hasCurrentContract
            ? try container.decodeIfPresent(String.self, forKey: .summary) ?? "服务已返回结果，请核对配置详情。"
            : "已完成基础兼容性检查；搭配合理度和性能评级需等待服务更新后补全。"
        sourceText = try container.decodeIfPresent(String.self, forKey: .sourceText) ?? ""
        direction = try container.decodeIfPresent(String.self, forKey: .direction) ?? "balanced"
        resolution = try container.decodeIfPresent(String.self, forKey: .resolution) ?? "1440p"
        pairingRating = try container.decodeIfPresent(ConfigReviewRatingDTO.self, forKey: .pairingRating) ?? .incomplete
        performanceRating = try container.decodeIfPresent(ConfigReviewRatingDTO.self, forKey: .performanceRating) ?? .incomplete
        let detected = try container.decodeIfPresent(
            [String: ConfigReviewDetectedComponentDTO?].self,
            forKey: .detectedComponents
        ) ?? [:]
        detectedComponents = detected.compactMapValues { $0 }
        findings = try container.decodeIfPresent([ConfigReviewFindingDTO].self, forKey: .findings)?
            .filter { !$0.code.localizedCaseInsensitiveContains("price") } ?? []
        recommendations = try container.decodeIfPresent(
            [ConfigReviewRecommendationDTO].self,
            forKey: .recommendations
        ) ?? []
        questionsForSeller = try container.decodeIfPresent([String].self, forKey: .questionsForSeller) ?? []
        replyText = hasCurrentContract
            ? try container.decodeIfPresent(String.self, forKey: .replyText) ?? summary
            : "请把每个配件的完整品牌和型号写清楚，确认兼容性后再决定。"
        webSearchStatus = try container.decodeIfPresent(String.self, forKey: .webSearchStatus) ?? "unavailable"
        webSources = try container.decodeIfPresent([ConfigReviewSourceDTO].self, forKey: .webSources) ?? []
    }
}

struct ConfigReviewRatingDTO: Decodable {
    let status: String
    let score: Int?
    let grade: String?
    let detail: String
    let confidence: String

    static let incomplete = ConfigReviewRatingDTO(
        status: "incomplete",
        score: nil,
        grade: nil,
        detail: "当前服务未返回完整评级，请补全配置或稍后重试。",
        confidence: "unavailable"
    )

    var displayValue: String {
        switch status {
        case "failed": "不通过"
        case "incomplete": "待补全"
        default: grade ?? "待补全"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case status, score, grade, detail, confidence
    }

    init(status: String, score: Int?, grade: String?, detail: String, confidence: String) {
        self.status = status
        self.score = score
        self.grade = grade
        self.detail = detail
        self.confidence = confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        score = try container.decodeIfPresent(Int.self, forKey: .score)
        grade = try container.decodeIfPresent(String.self, forKey: .grade)
        status = try container.decodeIfPresent(String.self, forKey: .status)
            ?? (grade == nil ? "incomplete" : "graded")
        detail = try container.decodeIfPresent(String.self, forKey: .detail) ?? "评级信息待补全。"
        confidence = try container.decodeIfPresent(String.self, forKey: .confidence) ?? "unavailable"
    }
}

struct ConfigReviewDetectedComponentDTO: Decodable, Identifiable {
    var id: String { role }
    let role: String
    let componentId: String
    let name: String
    let brand: String
    let confidence: String
}

struct ConfigReviewRecommendationDTO: Decodable, Identifiable {
    var id: String { "\(title)-\(componentIds.joined(separator: "-"))" }
    let severity: String
    let title: String
    let reason: String
    let action: String
    let expectedImpact: String
    let componentIds: [String]
}

struct ConfigReviewSourceDTO: Decodable, Identifiable {
    var id: String { url }
    let role: String
    let componentName: String
    let title: String
    let url: String
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
        URL(string: "https://api.uzbox.top")!
    }
}
