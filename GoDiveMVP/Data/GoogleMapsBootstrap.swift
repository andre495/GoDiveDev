import Foundation
#if canImport(GoogleMaps)
import GoogleMaps
#endif

/// Configures the Google Maps SDK when **`GoDiveMapEngine.active`** is **`.googleMaps`**.
enum GoogleMapsBootstrap {
    nonisolated private static let secretsPlistName = "GoogleMapsSecrets"
    nonisolated private static let secretsAPIKey = "APIKey"
    nonisolated private static let secretsMapIDKey = "MapID"
    nonisolated private static let infoPlistAPIKey = "GoogleMapsAPIKey"
    nonisolated private static let infoPlistMapIDKey = "GoogleMapsMapID"

    static var isConfigured = false

    /// Whether a hidden **`GMSMapView`** warm-up should run after launch (Explore first paint).
    nonisolated static var shouldWarmUpAtLaunch: Bool {
        guard !GoDiveUITestConfiguration.isActive else { return false }
        guard GoDiveMapEngine.active == .googleMaps else { return false }
        return loadAPIKey() != nil
    }

    static func configureIfNeeded() {
        guard GoDiveMapEngine.active == .googleMaps else { return }
        guard !isConfigured else { return }
        guard let apiKey = loadAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !apiKey.isEmpty
        else {
            #if DEBUG
            print(
                """
                GoDive: Google Maps API key missing. Copy Config/GoogleMapsSecrets.example.plist \
                to Config/GoogleMapsSecrets.plist and set your Maps SDK for iOS key.
                """
            )
            #endif
            return
        }

        #if canImport(GoogleMaps)
        GMSServices.provideAPIKey(apiKey)
        isConfigured = true
        #endif
    }

    nonisolated static func loadAPIKey() -> String? {
        if let url = Bundle.main.url(forResource: secretsPlistName, withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let key = plist[secretsAPIKey] as? String,
           !key.isEmpty,
           !key.hasPrefix("YOUR_")
        {
            return key
        }

        if let key = Bundle.main.object(forInfoDictionaryKey: infoPlistAPIKey) as? String,
           !key.isEmpty,
           !key.hasPrefix("YOUR_")
        {
            return key
        }

        return nil
    }

    /// Optional Cloud Console **map ID** for hybrid/satellite POI styling (see **`GoDiveMapPointOfInterestSuppression`**).
    nonisolated static func loadMapID() -> String? {
        if let url = Bundle.main.url(forResource: secretsPlistName, withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let mapID = plist[secretsMapIDKey] as? String,
           !mapID.isEmpty,
           !mapID.hasPrefix("YOUR_")
        {
            return mapID
        }

        if let mapID = Bundle.main.object(forInfoDictionaryKey: infoPlistMapIDKey) as? String,
           !mapID.isEmpty,
           !mapID.hasPrefix("YOUR_")
        {
            return mapID
        }

        return nil
    }
}

#if canImport(UIKit)
import UIKit

/// Initializes Google Maps before the first **`GMSMapView`** when the engine flag is on.
final class GoDiveGoogleMapsAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Firebase Auth/Firestore may touch the default app during launch swizzling — configure first.
        GoDiveFirebaseBootstrap.configureIfNeeded()
        // BGTask handlers must register before launch completes.
        GoDiveCloudKitBackgroundSync.registerTasksIfNeeded()
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppPortraitOrientationLockController.shared.supportedMask
    }
}
#endif
