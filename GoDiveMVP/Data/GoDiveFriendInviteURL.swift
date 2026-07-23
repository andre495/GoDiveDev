import Foundation

/// Builds and parses friend-invite deep links (`godive://` + HTTPS mirror).
enum GoDiveFriendInviteURL: Sendable {
    nonisolated static let customScheme = "godive"
    /// Universal Links + QR / share host (Firebase Hosting).
    nonisolated static let httpsInviteHost = "links.godiveios.com"
    /// Legacy share URLs (marketing site); still parsed if opened in-app.
    nonisolated static let legacyHTTPSInviteHost = "godiveios.com"
    nonisolated static let pathPrefix = "/invite/"

    /// URL for QR codes, Share link, and Copy (`https://links.godiveios.com/invite/{token}`).
    nonisolated static func preferredInviteURL(token: String) -> URL? {
        httpsInviteURL(token: token) ?? customSchemeInviteURL(token: token)
    }

    nonisolated static func httpsInviteURL(token: String) -> URL? {
        let trimmed = normalizedToken(token)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "https://\(httpsInviteHost)\(pathPrefix)\(trimmed)")
    }

    /// Custom URL scheme fallback when Universal Links are unavailable.
    nonisolated static func customSchemeInviteURL(token: String) -> URL? {
        let trimmed = normalizedToken(token)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "\(customScheme)://invite/\(trimmed)")
    }

    /// Parses `godive://invite/{token}` or `https://links.godiveios.com/invite/{token}` (legacy: **godiveios.com**).
    nonisolated static func inviteToken(from url: URL) -> String? {
        if let token = tokenFromCustomScheme(url) { return token }
        return tokenFromHTTPS(url)
    }

    nonisolated static func normalizedToken(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private nonisolated static func tokenFromCustomScheme(_ url: URL) -> String? {
        guard url.scheme?.lowercased() == customScheme else { return nil }
        let host = (url.host ?? "").lowercased()
        if host == "invite" {
            let pathToken = url.path.split(separator: "/").first.map(String.init)
            return pathToken.flatMap { normalizedToken($0).isEmpty ? nil : normalizedToken($0) }
        }
        // godive:///invite/token
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count >= 2, parts[0].lowercased() == "invite" else { return nil }
        let token = normalizedToken(parts[1])
        return token.isEmpty ? nil : token
    }

    private nonisolated static func tokenFromHTTPS(_ url: URL) -> String? {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            return nil
        }
        guard let host = url.host?.lowercased(), isInviteHTTPSHost(host) else {
            return nil
        }
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count >= 2, parts[0].lowercased() == "invite" else { return nil }
        let token = normalizedToken(parts[1])
        return token.isEmpty ? nil : token
    }

    private nonisolated static func isInviteHTTPSHost(_ host: String) -> Bool {
        let h = host.lowercased()
        if h == httpsInviteHost { return true }
        if h == legacyHTTPSInviteHost || h == "www.\(legacyHTTPSInviteHost)" { return true }
        return false
    }
}
