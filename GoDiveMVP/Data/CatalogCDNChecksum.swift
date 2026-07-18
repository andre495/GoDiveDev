import CryptoKit
import Foundation

enum CatalogCDNChecksum: Sendable {
    /// Lowercase hex SHA-256 of **`data`**.
    nonisolated static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func matches(data: Data, expectedHex: String) -> Bool {
        let expected = expectedHex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !expected.isEmpty else { return false }
        return sha256Hex(data) == expected
    }
}
