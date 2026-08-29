import Foundation
import os

protocol APITransport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: APITransport {}

extension Notification.Name {
    static let appSessionUnauthorized = Notification.Name("AppSessionUnauthorized")
}

enum APIErrorCategory: String {
    case configuration
    case networkUnavailable = "network_unavailable"
    case timeout
    case http4xx
    case http5xx
    case httpOther = "http_other"
    case invalidResponse = "invalid_response"
    case decodingFailure = "decoding_failure"
}

enum APIError: LocalizedError {
    case invalidConfiguration
    case networkUnavailable
    case timeout
    case invalidResponse
    case http(status: Int, message: String)
    case decodingFailure

    var category: APIErrorCategory {
        switch self {
        case .invalidConfiguration:
            .configuration
        case .networkUnavailable:
            .networkUnavailable
        case .timeout:
            .timeout
        case .invalidResponse:
            .invalidResponse
        case .decodingFailure:
            .decodingFailure
        case .http(let status, _):
            if (400..<500).contains(status) {
                .http4xx
            } else if (500..<600).contains(status) {
                .http5xx
            } else {
                .httpOther
            }
        }
    }

    fileprivate var shouldRetryGET: Bool {
        switch self {
        case .networkUnavailable, .timeout:
            true
        case .http(let status, _):
            [408, 429, 500, 502, 503, 504].contains(status)
        default:
            false
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "服务地址尚未配置"
        case .networkUnavailable:
            "网络连接不可用，请检查网络后重试"
        case .timeout:
            "请求超时，请稍后重试"
        case .invalidResponse:
            "服务器返回了无法识别的响应"
        case .http(let status, let message):
            if !message.isEmpty {
                message
            } else if (400..<500).contains(status) {
                "请求参数或权限有误"
            } else if (500..<600).contains(status) {
                "服务器暂时不可用，请稍后重试"
            } else {
                "请求失败（\(status)）"
            }
        case .decodingFailure:
            "服务器返回的数据无法识别，请稍后重试"
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
    private static let logger = Logger(subsystem: "top.uzbox.app", category: "api")

    private struct HTTPResult {
        let data: Data
        let status: Int
    }

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

    func currentAccount(token: String) async throws -> LoginAccount {
        try await request(
            path: "/v1/auth/me",
            method: "GET",
            token: token
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
        gpuPreference: String? = nil,
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
                gpuPreference: gpuPreference,
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

    func saveConfiguration(
        _ plan: SavedConfigurationPlanDTO,
        token: String
    ) async throws -> SavedConfigurationDTO {
        try await request(
            path: "/v1/builds",
            method: "POST",
            body: SaveConfigurationRequestDTO(
                title: plan.name,
                plan: plan,
                budget: plan.numericBudget,
                totalPrice: plan.numericTotalPrice,
                useCase: plan.kind.useCase
            ),
            token: token
        )
    }

    func savedConfigurations(token: String) async throws -> [SavedConfigurationDTO] {
        var configurations: [SavedConfigurationDTO] = []
        for kind in SavedConfigurationKind.allCases {
            let useCase = kind.useCase.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                ?? kind.useCase
            let saved: [SavedConfigurationDTO] = try await request(
                path: "/v1/builds?use_case=\(useCase)",
                method: "GET",
                token: token
            )
            configurations.append(contentsOf: saved)
        }
        return configurations.sorted { $0.createdAt > $1.createdAt }
    }

    func deleteSavedBuild(id: String, token: String) async throws {
        try await requestNoContent(
            path: "/v1/builds/\(id)",
            method: "DELETE",
            token: token
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
        request.timeoutInterval = timeoutInterval(for: path)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func timeoutInterval(for path: String) -> TimeInterval {
        if path == "/v1/build/options" || path.hasPrefix("/v1/review/") || path == "/v1/upgrade/plan" {
            return 60
        }
        return 15
    }

    private func perform<Response: Decodable>(request: URLRequest) async throws -> Response {
        let startedAt = Date()
        let result = try await responseData(for: request)
        do {
            let response = try decoder.decode(Response.self, from: result.data)
            log(
                endpoint: request.url?.path ?? "<unknown>",
                status: result.status,
                startedAt: startedAt,
                category: "success"
            )
            return response
        } catch {
            log(
                endpoint: request.url?.path ?? "<unknown>",
                status: result.status,
                startedAt: startedAt,
                category: APIErrorCategory.decodingFailure.rawValue
            )
            throw APIError.decodingFailure
        }
    }

    private func performNoContent(request: URLRequest) async throws {
        let startedAt = Date()
        let result = try await responseData(for: request)
        log(
            endpoint: request.url?.path ?? "<unknown>",
            status: result.status,
            startedAt: startedAt,
            category: "success"
        )
    }

    private func responseData(for request: URLRequest) async throws -> HTTPResult {
        var didRetryGET = false
        while true {
            do {
                return try await performSingleRequest(request)
            } catch let error as APIError {
                guard !didRetryGET,
                      request.httpMethod?.uppercased() == "GET",
                      error.shouldRetryGET else {
                    throw error
                }
                didRetryGET = true
            }
        }
    }

    private func performSingleRequest(_ request: URLRequest) async throws -> HTTPResult {
        let endpoint = request.url?.path ?? "<unknown>"
        let startedAt = Date()
        var status: Int?

        do {
            guard let url = request.url, url.scheme != nil, url.host != nil else {
                throw APIError.invalidConfiguration
            }
            let (data, response) = try await transport.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            status = httpResponse.statusCode
            guard (200..<300).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401,
                   request.value(forHTTPHeaderField: "Authorization") != nil {
                    NotificationCenter.default.post(name: .appSessionUnauthorized, object: nil)
                }
                throw APIError.http(
                    status: httpResponse.statusCode,
                    message: serverMessage(from: data, status: httpResponse.statusCode)
                )
            }

            return HTTPResult(data: data, status: httpResponse.statusCode)
        } catch is CancellationError {
            log(endpoint: endpoint, status: status, startedAt: startedAt, category: "cancelled")
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            log(endpoint: endpoint, status: status, startedAt: startedAt, category: "cancelled")
            throw error
        } catch {
            let normalized = normalize(error)
            log(endpoint: endpoint, status: status, startedAt: startedAt, category: normalized.category.rawValue)
            throw normalized
        }
    }

    private func normalize(_ error: Error) -> APIError {
        if let error = error as? APIError {
            return error
        }
        guard let urlError = error as? URLError else {
            return .networkUnavailable
        }
        if urlError.code == .timedOut {
            return .timeout
        }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
             .cannotFindHost, .dnsLookupFailed, .dataNotAllowed:
            return .networkUnavailable
        default:
            return .networkUnavailable
        }
    }

    private func log(
        endpoint: String,
        status: Int?,
        startedAt: Date,
        category: String
    ) {
        let statusText = status.map(String.init) ?? "-"
        let durationMilliseconds = Date().timeIntervalSince(startedAt) * 1_000
        Self.logger.info(
            "endpoint=\(endpoint, privacy: .public) status=\(statusText, privacy: .public) duration_ms=\(durationMilliseconds, privacy: .public) category=\(category, privacy: .public)"
        )
    }

    private func serverMessage(from data: Data, status: Int) -> String {
        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let detail = payload["detail"] else {
            return ""
        }

        if let detail = detail as? String {
            return humanizeDetail(detail)
        }

        if let details = detail as? [Any] {
            let messages = details.compactMap { item -> String? in
                if let issue = item as? [String: Any] {
                    let message = issue["msg"] as? String ?? ""
                    let location = issue["loc"] as? [Any] ?? []
                    let field = location.reversed().compactMap { $0 as? String }.first
                    return humanizeValidationMessage(message, field: field)
                }
                if let message = item as? String {
                    return humanizeDetail(message)
                }
                return nil
            }
            if !messages.isEmpty {
                return messages.joined(separator: "；")
            }
        }

        return ""
    }

    private func humanizeDetail(_ detail: String) -> String {
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "请求失败" }
        if trimmed.range(of: "[\\u4e00-\\u9fff]", options: .regularExpression) != nil {
            return trimmed
        }
        let lowercased = trimmed.lowercased()
        if lowercased.contains("unauthorized") || lowercased.contains("not authenticated") {
            return "登录状态已失效，请重新登录"
        }
        if lowercased.contains("forbidden") {
            return "暂无权限执行此操作"
        }
        if lowercased.contains("not found") {
            return "未找到请求的内容"
        }
        if lowercased.contains("too many") {
            return "请求过于频繁，请稍后再试"
        }
        if lowercased == "field required" {
            return "请补充必填信息"
        }
        return "请求参数填写有误"
    }

    private func humanizeValidationMessage(_ message: String, field: String?) -> String {
        let fieldName = validationFieldName(field)
        let lowercased = message.lowercased()
        if lowercased == "field required" {
            return "\(fieldName)不能为空"
        }
        if lowercased.contains("valid integer") || lowercased.contains("valid number") {
            return "\(fieldName)请输入有效数字"
        }
        if lowercased.contains("valid string") {
            return "\(fieldName)填写有误"
        }
        if lowercased.contains("pattern") || lowercased.contains("match") {
            return "\(fieldName)格式不正确"
        }
        if lowercased.contains("character") || lowercased.contains("length") {
            return "\(fieldName)长度不符合要求"
        }
        if lowercased.contains("at least") || lowercased.contains("greater than") || lowercased.contains("less than") {
            return "\(fieldName)数值不符合要求"
        }
        return humanizeDetail(message)
    }

    private func validationFieldName(_ field: String?) -> String {
        guard let field else { return "请求参数" }
        let names = [
            "budget": "预算",
            "use_case": "用途",
            "game_categories": "游戏类型",
            "direction": "性能方向",
            "memory_size": "内存容量",
            "storage_size": "硬盘容量",
            "phone": "手机号",
            "code": "验证码"
        ]
        return names[field] ?? field
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
    let gpuPreference: String?
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
        case gpuPreference = "gpu_preference"
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
    let cpuPlatformAlternative: CPUPlatformAlternativeDTO?
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

struct CPUPlatformAlternativeDTO: Decodable {
    let replacementParts: [BuildOptionPartDTO]
    let priceDifference: Int
    let performanceGainPercent: Int
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
