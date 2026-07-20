import Foundation

/// Optional CDN base URL from gitignored **`Config/CatalogCDNSecrets.plist`**.
///
/// Key: **`ManifestBaseURL`** — e.g. `https://your-project.web.app` (no trailing path required).
/// Empty / missing / placeholder → CDN disabled; bundled Marine Life seed remains the source of truth.
enum CatalogCDNSecretsBootstrap: Sendable {
    nonisolated private static let secretsPlistName = "CatalogCDNSecrets"
    nonisolated private static let baseURLKey = "ManifestBaseURL"

    nonisolated static func loadManifestBaseURL(bundle: Bundle = .main) -> URL? {
        guard let url = bundle.url(forResource: secretsPlistName, withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let raw = plist[baseURLKey] as? String
        else {
            return nil
        }
        return validatedBaseURL(raw)
    }

    nonisolated static func validatedBaseURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("YOUR_"),
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https",
              url.host != nil
        else {
            return nil
        }
        return url
    }

    nonisolated static var isConfigured: Bool {
        loadManifestBaseURL() != nil
    }
}
