import Foundation

extension DiveActivityDuplicateMatcher.MatchReason: Equatable {
    /// Explicit **nonisolated** equality for Swift Testing **`#expect`** (Swift 6).
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.sameSourceDiveId, .sameSourceDiveId), (.matchingFingerprint, .matchingFingerprint):
            return true
        default:
            return false
        }
    }
}

extension DiveActivityDuplicateMatcher.Match: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.existingId == rhs.existingId && lhs.reason == rhs.reason
    }
}
