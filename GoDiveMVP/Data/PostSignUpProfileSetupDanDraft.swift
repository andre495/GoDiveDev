import Foundation
import Observation

/// DAN step typing buffer — text changes do not invalidate the wizard; only **showsContinue** does.
@MainActor
@Observable
final class PostSignUpProfileSetupDanDraft {
    var text: String
    private(set) var showsContinue: Bool

    init(initialText: String = "") {
        text = initialText
        showsContinue = Self.hasNonemptyEntry(initialText)
    }

    func replaceText(_ newValue: String) {
        text = newValue
        let nextShowsContinue = Self.hasNonemptyEntry(newValue)
        guard showsContinue != nextShowsContinue else { return }
        showsContinue = nextShowsContinue
    }

    nonisolated static func hasNonemptyEntry(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
