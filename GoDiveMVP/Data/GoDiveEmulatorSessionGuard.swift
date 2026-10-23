#if DEBUG
import FirebaseAuth
import Foundation
import os

/// Guards against emulator Auth sessions leaking into production launches.
///
/// Firebase Auth stores credentials in the keychain, which survives app reinstall.
/// If a user runs with the emulator, then later launches without it, the emulator
/// UID would be used against production Firebase (which denies everything).
///
/// This guard runs early (after Firebase configure, before Firestore/Storage/FCM work)
/// and signs out any session that originated from the emulator.
enum GoDiveEmulatorSessionGuard {
    nonisolated private static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "EmulatorSessionGuard"
    )

    private static let emulatorSessionMarkerKey = "GoDiveEmulatorSessionActive"
    private static let allowedTestEmailDomain = "@example.com"

    // MARK: - Marker Management

    /// Records that the current Auth session came from the emulator.
    static func markSessionAsEmulator() {
        UserDefaults.standard.set(true, forKey: emulatorSessionMarkerKey)
    }

    /// Clears the emulator session marker.
    static func clearEmulatorMarker() {
        UserDefaults.standard.removeObject(forKey: emulatorSessionMarkerKey)
    }

    /// `true` if the marker indicates an emulator session is active.
    static var hasEmulatorSessionMarker: Bool {
        UserDefaults.standard.bool(forKey: emulatorSessionMarkerKey)
    }

    // MARK: - Session Detection

    /// `true` if the current Firebase Auth user has an `@example.com` email.
    /// This catches sessions that survived reinstall (keychain persists, UserDefaults clears).
    static var currentUserHasTestEmail: Bool {
        guard let email = Auth.auth().currentUser?.email else { return false }
        return email.lowercased().hasSuffix(allowedTestEmailDomain)
    }

    /// `true` if there's evidence of an emulator session (marker or test email).
    static var hasEmulatorSession: Bool {
        hasEmulatorSessionMarker || currentUserHasTestEmail
    }

    // MARK: - Decision Logic

    /// Determines whether to clear the current session.
    /// Returns `true` if emulator mode is off AND there's evidence of an emulator session.
    static func shouldClearSession(isEmulatorEnabled: Bool) -> Bool {
        guard !isEmulatorEnabled else { return false }
        return hasEmulatorSession
    }

    // MARK: - Guard Execution

    /// Clears any emulator session when running in production mode.
    /// Call this after Firebase configure, before any Firestore/Storage/FCM work.
    ///
    /// - Parameter isEmulatorEnabled: Whether the emulator is currently enabled.
    /// - Returns: `true` if a session was cleared.
    @discardableResult
    static func clearEmulatorSessionIfNeeded(isEmulatorEnabled: Bool) -> Bool {
        guard shouldClearSession(isEmulatorEnabled: isEmulatorEnabled) else {
            return false
        }

        let hadMarker = hasEmulatorSessionMarker
        let hadTestEmail = currentUserHasTestEmail
        let email = Auth.auth().currentUser?.email ?? "(no email)"

        do {
            try Auth.auth().signOut()
            clearEmulatorMarker()
            log.warning("Cleared emulator Auth session to prevent production access (marker=\(hadMarker) testEmail=\(hadTestEmail) email=\(email, privacy: .private))")
            return true
        } catch {
            log.error("Failed to sign out emulator session: \(String(describing: error), privacy: .private)")
            clearEmulatorMarker()
            return false
        }
    }

    /// Logs a warning if the test sign-in flag is present without the emulator flag.
    /// Call this early in launch to warn about misconfiguration.
    static func logWarningIfTestSignInWithoutEmulator() {
        let hasTestSignInArg = GoDiveEmulatorTestSignIn.launchArgumentEmail() != nil
        let hasEmulatorArg = GoDiveFirebaseBootstrap.isEmulatorLaunchArgumentPresent

        if hasTestSignInArg && !hasEmulatorArg {
            log.warning("Test sign-in flag (-GoDiveEmulatorTestSignIn) present without emulator flag (-GoDiveUseFirebaseEmulator) — sign-in disabled")
        }
    }
}
#endif
