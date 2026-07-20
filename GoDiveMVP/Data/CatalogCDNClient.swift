import Foundation

enum CatalogCDNClientError: Error, Equatable, Sendable {
    case invalidURL
    case httpStatus(Int)
    case emptyBody
    case responseTooLarge
}

/// HTTPS fetch for catalog manifests and payloads (Firebase Hosting — no Firebase SDK).
enum CatalogCDNClient: Sendable {
    nonisolated static let manifestRelativePath = "catalog/v1/manifest.json"

    nonisolated static func url(base: URL, relativePath: String) -> URL? {
        guard CatalogCDNPathValidation.isAllowedRelativePath(relativePath) else { return nil }
        let trimmed = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return nil }
        return base.appending(path: trimmed)
    }

    nonisolated static func fetchData(
        from url: URL,
        session: URLSession = .shared
    ) async throws -> Data {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" else {
            throw CatalogCDNClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
            throw CatalogCDNClientError.httpStatus(http.statusCode)
        }
        guard !data.isEmpty else { throw CatalogCDNClientError.emptyBody }
        guard data.count <= CatalogCDNSessionFactory.maxResponseBytes else {
            throw CatalogCDNClientError.responseTooLarge
        }
        return data
    }

    nonisolated static func fetchManifest(
        baseURL: URL,
        session: URLSession? = nil
    ) async throws -> (manifest: CatalogCDNManifest, data: Data) {
        let resolvedSession = session ?? CatalogCDNSessionFactory.makeSession(forBaseURL: baseURL)
        guard let url = url(base: baseURL, relativePath: manifestRelativePath) else {
            throw CatalogCDNClientError.invalidURL
        }
        let data = try await fetchData(from: url, session: resolvedSession)
        let manifest = try CatalogCDNManifestCodec.decode(data)
        return (manifest, data)
    }

    nonisolated static func fetchPayload(
        baseURL: URL,
        relativePath: String,
        session: URLSession? = nil
    ) async throws -> Data {
        let resolvedSession = session ?? CatalogCDNSessionFactory.makeSession(forBaseURL: baseURL)
        guard let url = url(base: baseURL, relativePath: relativePath) else {
            throw CatalogCDNClientError.invalidURL
        }
        return try await fetchData(from: url, session: resolvedSession)
    }
}
