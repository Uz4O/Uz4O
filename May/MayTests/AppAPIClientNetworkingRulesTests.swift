import Foundation

@main
struct AppAPIClientNetworkingRulesTests {
    static func main() async throws {
        try await retriesOnlyIdempotentGET()
        try await mapsFastAPIValidationErrors()
        try await separatesTransportAndDecodingFailures()
        await verifiesTimeoutProfiles()
        print("AppAPIClientNetworkingRulesTests passed")
    }

    private static func retriesOnlyIdempotentGET() async throws {
        let getTransport = FixtureTransport(fixtures: [
            .failure(URLError(.networkConnectionLost)),
            .success(Data("[]".utf8), status: 200)
        ])
        _ = try await AppAPIClient(baseURL: URL(string: "https://example.com")!, transport: getTransport)
            .diyComponents()
        guard getTransport.requests.count == 2 else {
            fatalError("GET should retry one transient failure exactly once.")
        }

        let serverTransport = FixtureTransport(fixtures: [
            .success(Data("{}".utf8), status: 503),
            .success(Data("[]".utf8), status: 200)
        ])
        _ = try await AppAPIClient(baseURL: URL(string: "https://example.com")!, transport: serverTransport)
            .diyComponents()
        guard serverTransport.requests.count == 2 else {
            fatalError("GET should retry one transient 5xx response exactly once.")
        }

        let postTransport = FixtureTransport(fixtures: [
            .success(Data(#"{"detail":"Field required"}"#.utf8), status: 422),
            .success(Data(#"{"detail":"Field required"}"#.utf8), status: 422)
        ])
        do {
            _ = try await AppAPIClient(baseURL: URL(string: "https://example.com")!, transport: postTransport)
                .analyzeConfigReviewText("完整配置单不应进入日志")
            fatalError("POST should throw on HTTP 422.")
        } catch let error as APIError {
            guard error.category == .http4xx, postTransport.requests.count == 1 else {
                fatalError("POST must not retry, category=\(error.category).")
            }
        }
    }

    private static func mapsFastAPIValidationErrors() async throws {
        let transport = FixtureTransport(fixtures: [
            .success(
                Data(#"{"detail":[{"loc":["body","budget"],"msg":"Field required","type":"missing"},{"loc":["body","memory_size"],"msg":"Input should be a valid integer","type":"int_parsing"}]}"#.utf8),
                status: 422
            )
        ])
        do {
            _ = try await AppAPIClient(baseURL: URL(string: "https://example.com")!, transport: transport)
                .analyzeConfigReviewText("配置内容")
            fatalError("FastAPI validation fixture should fail.")
        } catch let error as APIError {
            guard error.errorDescription == "预算不能为空；内存容量请输入有效数字" else {
                fatalError("Unexpected humanized 422 message: \(error.localizedDescription)")
            }
        }

        let stringTransport = FixtureTransport(fixtures: [
            .success(Data(#"{"detail":"Unauthorized"}"#.utf8), status: 422)
        ])
        do {
            _ = try await AppAPIClient(baseURL: URL(string: "https://example.com")!, transport: stringTransport)
                .analyzeConfigReviewText("配置内容")
            fatalError("FastAPI string detail fixture should fail.")
        } catch let error as APIError {
            guard error.errorDescription == "登录状态已失效，请重新登录" else {
                fatalError("Unexpected humanized detail message: \(error.localizedDescription)")
            }
        }
    }

    private static func separatesTransportAndDecodingFailures() async throws {
        let timeoutTransport = FixtureTransport(fixtures: [
            .failure(URLError(.timedOut)),
            .failure(URLError(.timedOut))
        ])
        do {
            _ = try await AppAPIClient(baseURL: URL(string: "https://example.com")!, transport: timeoutTransport)
                .diyComponents()
            fatalError("Timeout fixture should fail.")
        } catch let error as APIError {
            guard error.category == .timeout else { fatalError("Expected timeout category.") }
        }

        let decodeTransport = FixtureTransport(fixtures: [.success(Data("{}".utf8), status: 200)])
        do {
            _ = try await AppAPIClient(baseURL: URL(string: "https://example.com")!, transport: decodeTransport)
                .diyComponents()
            fatalError("Malformed success fixture should fail decoding.")
        } catch let error as APIError {
            guard error.category == .decodingFailure else { fatalError("Expected decoding failure category.") }
        }

        let serverTransport = FixtureTransport(fixtures: [.success(Data("{}".utf8), status: 503)])
        do {
            _ = try await AppAPIClient(baseURL: URL(string: "https://example.com")!, transport: serverTransport)
                .analyzeConfigReviewText("配置内容")
            fatalError("HTTP 503 fixture should fail.")
        } catch let error as APIError {
            guard error.category == .http5xx else { fatalError("Expected HTTP 5xx category.") }
        }
    }

    private static func verifiesTimeoutProfiles() async {
        let ordinaryTransport = FixtureTransport(fixtures: [
            .failure(URLError(.timedOut)),
            .failure(URLError(.timedOut))
        ])
        do {
            _ = try await AppAPIClient(baseURL: URL(string: "https://example.com")!, transport: ordinaryTransport)
                .diyComponents()
        } catch {
            guard ordinaryTransport.requests.first?.timeoutInterval == 15 else {
                fatalError("Ordinary requests should use the short timeout.")
            }
        }

        let reviewTransport = FixtureTransport(fixtures: [.failure(URLError(.timedOut))])
        do {
            _ = try await AppAPIClient(baseURL: URL(string: "https://example.com")!, transport: reviewTransport)
                .analyzeConfigReviewText("配置内容")
        } catch {
            guard reviewTransport.requests.first?.timeoutInterval == 60 else {
                fatalError("AI/review requests should use the long timeout.")
            }
        }
    }
}

private final class FixtureTransport: APITransport {
    enum Fixture {
        case success(Data, status: Int)
        case failure(Error)
    }

    var fixtures: [Fixture]
    var requests: [URLRequest] = []

    init(fixtures: [Fixture]) {
        self.fixtures = fixtures
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        guard !fixtures.isEmpty else { fatalError("Missing transport fixture.") }
        switch fixtures.removeFirst() {
        case .success(let data, let status):
            return (
                data,
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: status,
                    httpVersion: nil,
                    headerFields: nil
                )!
            )
        case .failure(let error):
            throw error
        }
    }
}
