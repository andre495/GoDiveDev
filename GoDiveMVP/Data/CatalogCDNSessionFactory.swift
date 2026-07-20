import Foundation

/// Same-host HTTPS-only redirects for catalog CDN fetches (OWASP Phase 2).
///
/// Uses the completion-handler redirect API (not `async`) so SILGen can emit a stable
/// ObjC thunk under MainActor default isolation.
final class CatalogCDNRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let allowedHost: String

    nonisolated init(allowedHost: String) {
        self.allowedHost = allowedHost.lowercased()
        super.init()
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let url = request.url,
              let scheme = url.scheme?.lowercased(),
              scheme == "https",
              let host = url.host?.lowercased(),
              host == allowedHost
        else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

enum CatalogCDNPathValidation: Sendable {
    /// Manifest + payload paths must stay under **`catalog/v1/`** with no `..` traversal.
    nonisolated static func isAllowedRelativePath(_ relativePath: String) -> Bool {
        let trimmed = relativePath
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return false }
        let lowered = trimmed.lowercased()
        guard lowered.hasPrefix("catalog/v1/") else { return false }
        guard !trimmed.contains("..") else { return false }
        guard !lowered.hasPrefix("http:"), !lowered.hasPrefix("https:") else { return false }
        return true
    }
}

enum CatalogCDNSessionFactory: Sendable {
    nonisolated static let maxResponseBytes = 20 * 1024 * 1024

    nonisolated static func makeSession(forBaseURL baseURL: URL) -> URLSession {
        let host = (baseURL.host ?? "").lowercased()
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let delegate = CatalogCDNRedirectDelegate(allowedHost: host)
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }
}
