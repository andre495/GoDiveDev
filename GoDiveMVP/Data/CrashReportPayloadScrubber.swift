import Foundation

/// Scrubs crash report text before **public CloudKit** upload (OWASP Phase 4).
///
/// Local Settings export may retain richer diagnostics; cloud payloads must not carry
/// emails, tokens, GPS, absolute paths, or accidental notes payloads.
enum CrashReportPayloadScrubber: Sendable {

    nonisolated static let redactedToken = "<redacted>"

    /// Applies all cloud-share redactions to a free-form string (reason or details).
    nonisolated static func scrub(_ raw: String) -> String {
        var text = raw
        text = replaceMatches(in: text, pattern: #"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#, options: [.caseInsensitive])
        text = replaceMatches(in: text, pattern: #"(?i)Bearer\s+[A-Za-z0-9\-._~+/]+=*"#) { _ in
            "Bearer \(redactedToken)"
        }
        text = replaceMatches(in: text, pattern: #"(?i)(client_secret|access_token|id_token)\s*[:=]\s*\S+"#)
        text = replaceMatches(in: text, pattern: #"-?\d{1,3}\.\d{3,}\s*,\s*-?\d{1,3}\.\d{3,}"#)
        text = replaceMatches(in: text, pattern: #"(?i)(lat(itude)?|lon(gitude)?|coord(inate)?s?)\s*[:=]\s*-?\d+(\.\d+)?"#)
        text = replaceMatches(in: text, pattern: #"(?i)(/Users/|/private/var/|/private/tmp/|/tmp/|file://)[^\s\]]+"#)
        text = replaceMatches(in: text, pattern: #"(?i)notes\s*[:=]\s*.+"#) { _ in
            "notes: \(redactedToken)"
        }
        return text
    }

    nonisolated private static func replaceMatches(
        in text: String,
        pattern: String,
        options: NSRegularExpression.Options = [],
        replacement: ((NSTextCheckingResult) -> String)? = nil
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return text
        }
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)
        guard !matches.isEmpty else { return text }

        var rebuilt = ""
        var cursor = text.startIndex
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            rebuilt += text[cursor..<range.lowerBound]
            rebuilt += replacement?(match) ?? redactedToken
            cursor = range.upperBound
        }
        rebuilt += text[cursor...]
        return rebuilt
    }
}
