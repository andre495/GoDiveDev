import CoreGraphics
import Foundation

/// Temporary layout lab for profile / buddy / friend blue-sheet identity chrome (remove before ship).
enum BlueSheetIdentityLayoutTuningPresentation: Sendable {
    struct Deltas: Equatable, Sendable {
        var avatarLeading: CGFloat = 0
        var avatarVertical: CGFloat = 0
        var identityTextVertical: CGFloat = 0
        /// Vertical shift of the pinned-summary → panel hairline (positive moves the line down).
        var panelDividerVertical: CGFloat = 0
        var panelContentTop: CGFloat = 0

        nonisolated init(
            avatarLeading: CGFloat = 0,
            avatarVertical: CGFloat = 0,
            identityTextVertical: CGFloat = 0,
            panelDividerVertical: CGFloat = 0,
            panelContentTop: CGFloat = 0
        ) {
            self.avatarLeading = avatarLeading
            self.avatarVertical = avatarVertical
            self.identityTextVertical = identityTextVertical
            self.panelDividerVertical = panelDividerVertical
            self.panelContentTop = panelContentTop
        }
    }

    nonisolated static let userDefaultsKey = "BlueSheetIdentityLayoutTuning.deltas"

    nonisolated static func loadPersistedDeltas() -> Deltas {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: userDefaultsKey + ".hasValues") else { return Deltas() }
        return Deltas(
            avatarLeading: CGFloat(defaults.double(forKey: userDefaultsKey + ".avatarLeading")),
            avatarVertical: CGFloat(defaults.double(forKey: userDefaultsKey + ".avatarVertical")),
            identityTextVertical: CGFloat(defaults.double(forKey: userDefaultsKey + ".identityTextVertical")),
            panelDividerVertical: CGFloat(defaults.double(forKey: userDefaultsKey + ".panelDividerVertical")),
            panelContentTop: CGFloat(defaults.double(forKey: userDefaultsKey + ".panelContentTop"))
        )
    }

    nonisolated static func persist(_ deltas: Deltas) {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: userDefaultsKey + ".hasValues")
        defaults.set(Double(deltas.avatarLeading), forKey: userDefaultsKey + ".avatarLeading")
        defaults.set(Double(deltas.avatarVertical), forKey: userDefaultsKey + ".avatarVertical")
        defaults.set(Double(deltas.identityTextVertical), forKey: userDefaultsKey + ".identityTextVertical")
        defaults.set(Double(deltas.panelDividerVertical), forKey: userDefaultsKey + ".panelDividerVertical")
        defaults.set(Double(deltas.panelContentTop), forKey: userDefaultsKey + ".panelContentTop")
    }

    nonisolated static func handoffSummary(deltas: Deltas) -> String {
        """
        Blue sheet identity layout deltas (add to production tokens):
        avatarLeading: +\(format(deltas.avatarLeading)) pt
        avatarVertical: +\(format(deltas.avatarVertical)) pt
        identityTextVertical: +\(format(deltas.identityTextVertical)) pt
        panelDividerVertical: +\(format(deltas.panelDividerVertical)) pt
        panelContentTop: +\(format(deltas.panelContentTop)) pt
        """
    }

    nonisolated private static func format(_ value: CGFloat) -> String {
        String(format: "%.1f", Double(value))
    }
}
