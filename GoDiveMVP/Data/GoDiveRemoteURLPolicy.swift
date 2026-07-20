import Foundation

/// Output-side URL gates for catalog / Field Guide remote assets (OWASP Phase 6).
///
/// Complements CDN path validation (**`CatalogCDNPathValidation`**) and HTTPS fetch
/// (**`CatalogCDNClient`**) by rejecting unsafe schemes/hosts before **`AsyncImage`** or disk cache downloads.
enum GoDiveRemoteURLPolicy: Sendable {

    /// Catalog photos shown via **`AsyncImage`** — HTTPS to a public DNS host only.
    /// Blocks `http` / `file` / localhost / IP literals / embedded credentials.
    /// Host diversity (Wikimedia, museum CDNs, etc.) is intentional until signed CDN is universal.
    nonisolated static func sanitizedCatalogImageURL(from raw: String) -> URL? {
        guard let url = parsedHTTPSURL(from: raw) else { return nil }
        guard isPublicDNSHost(url.host) else { return nil }
        guard url.user == nil, url.password == nil else { return nil }
        return url
    }

    /// USDZ / Storage downloads into **`CatalogAssetDiskCache`** — HTTPS plus Firebase / CDN hosts only.
    nonisolated static func sanitizedCatalogDownloadURL(
        from raw: String,
        cdnBaseHost: String? = CatalogCDNSecretsBootstrap.loadManifestBaseURL()?.host
    ) -> URL? {
        guard let url = sanitizedCatalogImageURL(from: raw) else { return nil }
        guard let host = url.host?.lowercased(),
              isAllowedCatalogDownloadHost(host, cdnBaseHost: cdnBaseHost?.lowercased())
        else {
            return nil
        }
        return url
    }

    nonisolated static func isAllowedCatalogDownloadHost(
        _ host: String,
        cdnBaseHost: String? = nil
    ) -> Bool {
        let h = host.lowercased()
        if let cdn = cdnBaseHost?.lowercased(), !cdn.isEmpty, h == cdn {
            return true
        }
        if h == "firebasestorage.googleapis.com" || h == "storage.googleapis.com" {
            return true
        }
        return h.hasSuffix(".firebasestorage.app")
            || h.hasSuffix(".web.app")
            || h.hasSuffix(".firebaseapp.com")
    }

    // MARK: - Internals

    nonisolated private static func parsedHTTPSURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https",
              url.host != nil
        else {
            return nil
        }
        return url
    }

    /// Rejects empty, localhost, `.local`, and IP-literal hosts (IPv4 / IPv6).
    nonisolated static func isPublicDNSHost(_ host: String?) -> Bool {
        guard let host, !host.isEmpty else { return false }
        let h = host.lowercased()
        if h == "localhost" || h.hasSuffix(".localhost") || h.hasSuffix(".local") {
            return false
        }
        if h.contains(":") {
            // IPv6 literal (URL.host may omit brackets).
            return false
        }
        if isIPv4Literal(h) {
            return false
        }
        // Require at least one dot for a registrable-looking name (blocks "intranet").
        guard h.contains(".") else { return false }
        return true
    }

    nonisolated private static func isIPv4Literal(_ host: String) -> Bool {
        let parts = host.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let value = Int(part), (0 ... 255).contains(value) else { return false }
            return true
        }
    }
}