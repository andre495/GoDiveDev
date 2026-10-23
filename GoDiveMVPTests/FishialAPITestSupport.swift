import Foundation
@testable import GoDiveMVP

actor MockFishialURLSession: FishialURLSessioning {
    private var handlers: [(URLRequest) throws -> (Data, URLResponse)]

    init(handlers: [(URLRequest) throws -> (Data, URLResponse)]) {
        self.handlers = handlers
    }

    nonisolated func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let handler = try await nextHandler()
        return try handler(request)
    }

    private func nextHandler() throws -> (URLRequest) throws -> (Data, URLResponse) {
        guard !handlers.isEmpty else {
            throw FishialAPIError.invalidResponse
        }
        return handlers.removeFirst()
    }

    nonisolated static func jsonResponse(
        statusCode: Int,
        body: String,
        url: URL = URL(string: "https://api.fishial.ai")!
    ) -> (Data, URLResponse) {
        let http = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(body.utf8), http)
    }
}
