import Foundation

/// Shared debounce + haystack helpers for catalog / list search fields.
enum CatalogSearchPresentation: Sendable {
    nonisolated static let debounceNanoseconds: UInt64 = 80_000_000

    nonisolated static func joinedLowercasedHaystacks(_ haystacks: [String]) -> String {
        haystacks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
