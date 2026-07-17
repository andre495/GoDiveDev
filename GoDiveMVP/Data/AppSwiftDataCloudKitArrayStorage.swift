import Foundation

/// JSON `Data` codecs for list attributes that must not persist as SwiftData Codable arrays
/// (CloudKit rejects `NSCodableAttributeType`).
enum AppSwiftDataCloudKitArrayStorage: Sendable {

    nonisolated static func encodeUUIDList(_ values: [UUID]) -> Data? {
        guard !values.isEmpty else { return nil }
        return try? JSONEncoder().encode(values.map(\.uuidString))
    }

    nonisolated static func decodeUUIDList(_ data: Data?) -> [UUID] {
        guard let data, !data.isEmpty,
              let strings = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return strings.compactMap(UUID.init(uuidString:))
    }

    nonisolated static func encodeStringList(_ values: [String]) -> Data? {
        let trimmed = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { return nil }
        return try? JSONEncoder().encode(trimmed)
    }

    nonisolated static func decodeStringList(_ data: Data?) -> [String] {
        guard let data, !data.isEmpty,
              let values = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return values
    }
}
