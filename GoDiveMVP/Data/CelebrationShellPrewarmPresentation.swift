import SwiftUI

private struct CelebrationShellPrewarmActiveKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// **`ContentView`** is mounted invisibly under **`SignInCelebrationView`**.
    var isCelebrationShellPrewarmActive: Bool {
        get { self[CelebrationShellPrewarmActiveKey.self] }
        set { self[CelebrationShellPrewarmActiveKey.self] = newValue }
    }
}

/// Timing for hidden main-shell mount during the post-sign-in celebration.
enum CelebrationShellPrewarmPresentation: Sendable {
    nonisolated static let defaultDelayNanoseconds: UInt64 = 120_000_000
    /// After bulk UDDF import — let SwiftData merges settle before mounting **`ContentView`**.
    nonisolated static let postBulkImportDelayNanoseconds: UInt64 = 1_500_000_000
}
