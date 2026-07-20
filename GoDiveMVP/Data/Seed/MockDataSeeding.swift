import Foundation

/// Controls bundled JSON fixture loading at launch (**`MockDataSeeder`**).
enum MockDataSeeding: Sendable {
    /// When **`false`**, **`GoDiveMVPApp`** does not call **`MockDataSeeder`** on launch (default). Set **`true`** locally to load **`dives_sample.json`** again.
    nonisolated static let isLaunchSeedingEnabled = false
}
