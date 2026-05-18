import Foundation

/// Controls bundled JSON fixture loading at launch (**`MockDataSeeder`**).
enum MockDataSeeding {
    /// When **`false`**, **`GoDiveMVPApp`** does not call **`MockDataSeeder`** on launch (default). Set **`true`** locally to load **`dives_sample.json`** again.
    static let isLaunchSeedingEnabled = false
}
