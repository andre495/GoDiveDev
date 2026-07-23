import Foundation

/// Friend-visible profile header media stored in Firebase (`profileHeroURL` + `profileHeroMediaKind`).
enum GoDiveProfileHeroMediaKind: String, Sendable, Equatable, Hashable {
    case image
    case video

    nonisolated static func fromFirestoreValue(_ raw: String?) -> GoDiveProfileHeroMediaKind? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch trimmed {
        case Self.image.rawValue: return .image
        case Self.video.rawValue: return .video
        default: return nil
        }
    }
}
