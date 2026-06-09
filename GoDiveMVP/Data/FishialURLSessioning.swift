import Foundation

/// Injectable HTTP transport for **`FishialAPIClient`** tests.
protocol FishialURLSessioning: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: FishialURLSessioning {}
