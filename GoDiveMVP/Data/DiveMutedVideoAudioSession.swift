import AVFoundation
import Foundation

/// Keeps muted dive / Home carousel videos from interrupting music, podcasts, or other video on the phone.
enum DiveMutedVideoAudioSession: Sendable {
    nonisolated static let category: AVAudioSession.Category = .ambient
    nonisolated static let mode: AVAudioSession.Mode = .default
    nonisolated static let categoryOptions: AVAudioSession.CategoryOptions = [.mixWithOthers]

    /// Stable strings for unit tests (avoids importing **AVFAudio** in **`GoDiveMVPTests`**).
    nonisolated static let categoryRawValueForTesting: String = category.rawValue
    nonisolated static let includesMixWithOthersForTesting: Bool = categoryOptions.contains(.mixWithOthers)

    /// Module defaults to MainActor; mark nonisolated so PhotoKit completion paths can activate the session.
    private nonisolated static let lock = NSLock()

    /// Call before starting any muted **`AVPlayer`** playback.
    ///
    /// Re-applies ambient + mix-with-others every time (cheap): other frameworks / first-play defaults
    /// can leave the shared session on **`.playback`**, which stops Music even when **`isMuted`**.
    nonisolated static func activateForMutedPlayback() {
        lock.lock()
        defer { lock.unlock() }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(category, mode: mode, options: categoryOptions)
            try session.setActive(true)
        } catch {
            // Non-fatal — playback may still duck other audio on failure.
        }
    }

    #if DEBUG
    /// Test hook retained for call-site compatibility (configuration is re-applied every activate).
    nonisolated static func resetConfigurationStateForTesting() {}
    #endif
}
