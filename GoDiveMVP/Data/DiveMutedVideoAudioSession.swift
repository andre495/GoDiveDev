import AVFoundation
import Foundation

/// Keeps muted dive videos from interrupting music/podcasts in other apps.
enum DiveMutedVideoAudioSession: Sendable {
    static let category: AVAudioSession.Category = .ambient
    static let mode: AVAudioSession.Mode = .default
    static let categoryOptions: AVAudioSession.CategoryOptions = [.mixWithOthers]

    /// Stable strings for unit tests (avoids importing **AVFAudio** in **`GoDiveMVPTests`**).
    nonisolated static let categoryRawValueForTesting: String = category.rawValue
    nonisolated static let includesMixWithOthersForTesting: Bool = categoryOptions.contains(.mixWithOthers)

    private static let lock = NSLock()
    private static var isConfigured = false

    /// Call before starting any muted **`AVPlayer`** playback.
    static func activateForMutedPlayback() {
        lock.lock()
        defer { lock.unlock() }
        guard !isConfigured else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(category, mode: mode, options: categoryOptions)
            try session.setActive(true)
            isConfigured = true
        } catch {
            // Non-fatal — playback may still duck other audio on failure.
        }
    }

    #if DEBUG
    /// Test hook to re-run configuration after resetting session state in tests.
    static func resetConfigurationStateForTesting() {
        lock.lock()
        isConfigured = false
        lock.unlock()
    }
    #endif
}
