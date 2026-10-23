import Foundation
import os
@testable import GoDiveMVP

final class MockFishialURLSession: FishialURLSessioning, @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock<[(URLRequest) throws -> (Data, URLResponse)]>(initialState: [])

    init(handlers: [(URLRequest) throws -> (Data, URLResponse)]) {
        lock.withLock { $0 = handlers }
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let handler = try lock.withLock { handlers -> (URLRequest) throws -> (Data, URLResponse) in
            guard !handlers.isEmpty else {
                throw FishialAPIError.invalidResponse
            }
            return handlers.removeFirst()
        }
        return try handler(request)
    }

    static func jsonResponse(
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
