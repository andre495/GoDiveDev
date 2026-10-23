import Foundation
import os
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

/// Configures Firebase when **`GoogleService-Info.plist`** is present (gitignored secrets).
enum GoDiveFirebaseBootstrap: Sendable {
    nonisolated private static let log = Logger(subsystem: "PrimoSoftware.GoDiveMVP", category: "FirebaseBootstrap")

    nonisolated private static let plistResourceName = "GoogleService-Info"
    nonisolated private static let placeholderAPIKeyMarkers: [String] = [
        "YOUR_API_KEY",
        "REPLACE_ME",
        "",
    ]

    #if DEBUG
    nonisolated private static let emulatorLaunchArgument = "-GoDiveUseFirebaseEmulator"
    nonisolated private static let emulatorHost = "127.0.0.1"
    nonisolated private static let authEmulatorPort = 9099
    nonisolated private static let firestoreEmulatorPort = 8080
    nonisolated private static let storageEmulatorPort = 9199
    #endif

    nonisolated(unsafe) private static var configuredSuccessfully = false
    nonisolated(unsafe) private static var emulatorConfigured = false

    nonisolated static var isConfigured: Bool {
        configuredSuccessfully && FirebaseApp.app() != nil
    }

    #if DEBUG
    nonisolated static var isEmulatorEnabled: Bool {
        emulatorConfigured
    }
    #endif

    /// Soft no-op when plist is missing or invalid (local dive app still works).
    /// Safe to call from App Delegate / SwiftUI `App.init` (main thread).
    nonisolated static func configureIfNeeded(bundle: Bundle = .main) {
        guard !GoDiveUITestConfiguration.isActive else { return }
        if Thread.isMainThread {
            configureOnMain(bundle: bundle)
        } else {
            DispatchQueue.main.sync {
                configureOnMain(bundle: bundle)
            }
        }
    }

    nonisolated private static func configureOnMain(bundle: Bundle) {
        if configuredSuccessfully, FirebaseApp.app() != nil { return }
        if FirebaseApp.app() != nil {
            configuredSuccessfully = true
            log.notice("Firebase already configured")
            return
        }

        guard let plistURL = googleServiceInfoURL(in: bundle) else {
            log.error("Firebase not configured: GoogleService-Info.plist not found in app bundle")
            return
        }

        log.notice("Loading Firebase options from GoogleService-Info.plist")

        guard let options = FirebaseOptions(contentsOfFile: plistURL.path) else {
            log.error("Firebase not configured: could not parse GoogleService-Info.plist")
            return
        }

        if isPlaceholder(options: options) {
            log.error(
                "Firebase not configured: GoogleService-Info.plist still has placeholder API keys. Download the real plist from Firebase Console."
            )
            return
        }

        FirebaseApp.configure(options: options)
        configuredSuccessfully = FirebaseApp.app() != nil
        if configuredSuccessfully {
            log.notice("Firebase configured (project/bundle redacted)")
            #if DEBUG
            configureEmulatorIfRequested()
            #endif
        } else {
            log.error("FirebaseApp.configure(options:) completed but FirebaseApp.app() is nil")
        }
    }

    #if DEBUG
    nonisolated private static func configureEmulatorIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains(emulatorLaunchArgument) else {
            return
        }

        Auth.auth().useEmulator(withHost: emulatorHost, port: authEmulatorPort)

        let firestoreSettings = Firestore.firestore().settings
        firestoreSettings.host = "\(emulatorHost):\(firestoreEmulatorPort)"
        firestoreSettings.isSSLEnabled = false
        firestoreSettings.cacheSettings = MemoryCacheSettings()
        Firestore.firestore().settings = firestoreSettings

        Storage.storage().useEmulator(withHost: emulatorHost, port: storageEmulatorPort)

        emulatorConfigured = true
        log.notice("Firebase emulator configured (auth:\(authEmulatorPort) firestore:\(firestoreEmulatorPort) storage:\(storageEmulatorPort))")
    }
    #endif

    /// Resolves the real secrets plist (never the `.example` template).
    nonisolated static func googleServiceInfoURL(in bundle: Bundle) -> URL? {
        let direct = bundle.bundleURL.appendingPathComponent("\(plistResourceName).plist")
        if FileManager.default.fileExists(atPath: direct.path) {
            return direct
        }

        let candidates: [URL?] = [
            bundle.url(forResource: plistResourceName, withExtension: "plist"),
            bundle.url(forResource: plistResourceName, withExtension: "plist", subdirectory: "Config"),
        ]
        for case let url? in candidates {
            let name = url.lastPathComponent
            guard name == "\(plistResourceName).plist" else { continue }
            guard !name.contains(".example.") else { continue }
            return url
        }
        return nil
    }

    nonisolated private static func isPlaceholder(options: FirebaseOptions) -> Bool {
        let key = options.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if placeholderAPIKeyMarkers.contains(key) { return true }
        if key.hasPrefix("YOUR_") { return true }
        let appID = options.googleAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        if appID.isEmpty || appID.hasPrefix("YOUR_") { return true }
        return false
    }
}
