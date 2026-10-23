import Foundation

/// Injectable HTTP transport for **`FishialAPIClient`** tests.
///
/// Marked `nonisolated` so implementations (including `URLSession`) are not
/// required to be `@MainActor`-isolated, allowing cross-isolation calls.
nonisolated protocol FishialURLSessioning: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: FishialURLSessioning {}
