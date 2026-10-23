import Foundation

/// Injectable HTTP transport for **`FishialAPIClient`** tests.
///
/// Methods are `nonisolated` because `URLSession.data(for:)` is nonisolated
/// and callers may invoke from any isolation context.
protocol FishialURLSessioning: Sendable {
    nonisolated func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: FishialURLSessioning {}
