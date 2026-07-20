import Foundation

/// Redaction helpers so secrets never appear in logs (OWASP Phase 3).
enum GoDiveSecretLogging: Sendable {
    /// Safe description for an `Authorization` header value.
    nonisolated static func redactedAuthorizationDescription(_ raw: String?) -> String {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "(none)"
        }
        return "Bearer <redacted>"
    }

    /// True when a string looks like a bearer token or client secret worth never logging.
    nonisolated static func looksLikeSecretMaterial(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 16 else { return false }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("bearer ") { return true }
        if lower.contains("client_secret") { return true }
        return false
    }
}

/// Release gate: production Info.plist must not weaken ATS without an explicit exception.
enum AppTransportSecurityPolicy: Sendable {
    /// Keys that indicate an ATS exception dictionary is present.
    nonisolated static let appTransportSecurityKey = "NSAppTransportSecurity"
    nonisolated static let allowsArbitraryLoadsKey = "NSAllowsArbitraryLoads"

    /// `true` when the plist has no ATS exception block (system HTTPS defaults).
    nonisolated static func usesSystemDefaultATS(infoDictionary: [String: Any]) -> Bool {
        infoDictionary[appTransportSecurityKey] == nil
    }

    /// `true` when arbitrary HTTP loads are explicitly allowed (disallowed for GoDive Release).
    nonisolated static func allowsArbitraryLoads(infoDictionary: [String: Any]) -> Bool {
        guard let ats = infoDictionary[appTransportSecurityKey] as? [String: Any] else {
            return false
        }
        return ats[allowsArbitraryLoadsKey] as? Bool == true
    }
}
