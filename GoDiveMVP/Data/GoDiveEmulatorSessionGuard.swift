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
        subsystem: "GoDive",
        category: "EmulatorSessionGuard"
    )

    nonisolated static let emulatorSessionMarkerKey = "GoDiveEmulatorSessionActive"
    nonisolated static let allowedTestEmailDomain = "@example.com"

    // MARK: - Marker Management (nonisolated, no Auth access)

    /// Records that the current Auth session came from the emulator.
    nonisolated static func markSessionAsEmulator(userDefaults: UserDefaults = .standard) {
        userDefaults.set(true, forKey: emulatorSessionMarkerKey)
    }

    /// Clears the emulator session marker.
    nonisolated static func clearEmulatorMarker(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: emulatorSessionMarkerKey)
    }

    /// `true` if the marker indicates an emulator session is active.
    nonisolated static func hasEmulatorSessionMarker(userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.bool(forKey: emulatorSessionMarkerKey)
    }

    /// Legacy computed property for existing callers.
    nonisolated static var hasEmulatorSessionMarker: Bool {
        hasEmulatorSessionMarker(userDefaults: .standard)
    }

    // MARK: - Pure Decision Logic (nonisolated, testable)

    /// Checks if an email is a test email (ends with `@example.com`).
    nonisolated static func isTestEmail(_ email: String?) -> Bool {
        guard let email else { return false }
        return email.lowercased().hasSuffix(allowedTestEmailDomain)
    }

    /// Determines whether to clear the current session based on inputs.
    /// Returns `true` if emulator mode is off AND there's evidence of an emulator session.
    nonisolated static func shouldClearSession(
        isEmulatorEnabled: Bool,
        hasMarker: Bool,
        currentUserEmail: String?
    ) -> Bool {
        guard !isEmulatorEnabled else { return false }
        return hasMarker || isTestEmail(currentUserEmail)
    }

    // MARK: - Persisted Session Clearing (nonisolated, testable)

    /// Clears all persisted session state for an emulator-origin session.
    /// Called when an emulator session is detected on a non-emulator launch.
    nonisolated static func clearPersistedEmulatorSession() {
        AppLaunchSessionRestorePresentation.clearPersistedProfileID()
        ReturningAccountHints.clearAll()
        GoDiveFirestoreUserProfileMapping.clearCachedFirebaseUID()
    }

    // MARK: - Guard Execution (must run on main thread)

    /// Clears any emulator session when running in production mode.
    /// Call from main thread after Firebase configure, before Firestore/Storage/FCM work.
    ///
    /// When emulator is enabled, this is a no-op (emulator sessions are expected).
    ///
    /// Clears: Firebase Auth session, emulator marker, persisted profile ID, returning
    /// account hints, and cached Firebase UID. The user lands on Welcome after restore.
    ///
    /// - Parameter isEmulatorEnabled: Whether the emulator is currently enabled.
    /// - Returns: `true` if a session was cleared.
    @discardableResult
    nonisolated static func clearEmulatorSessionIfNeededOnMain(isEmulatorEnabled: Bool) -> Bool {
        precondition(Thread.isMainThread, "Must be called on main thread")

        guard !isEmulatorEnabled else {
            return false
        }

        let hasMarker = hasEmulatorSessionMarker
        let currentEmail = Auth.auth().currentUser?.email

        guard shouldClearSession(
            isEmulatorEnabled: false,
            hasMarker: hasMarker,
            currentUserEmail: currentEmail
        ) else {
            return false
        }

        do {
            try Auth.auth().signOut()
        } catch {
            log.error("Failed to sign out emulator session: \(String(describing: error), privacy: .private)")
        }

        clearPersistedEmulatorSession()
        clearEmulatorMarker()

        log.info("Cleared emulator-origin session on non-emulator launch")
        return true
    }

    // MARK: - Testable Guard (injectable dependencies)

    /// Result of a testable guard execution.
    struct ClearResult: Equatable, Sendable {
        let didClear: Bool
        let signOutCalled: Bool
        let persistedSessionCleared: Bool
        let markerCleared: Bool
    }

    /// Testable version of the guard with injectable dependencies.
    /// - Parameters:
    ///   - isEmulatorEnabled: Whether the emulator is currently enabled.
    ///   - hasMarker: Whether the emulator session marker is set.
    ///   - currentUserEmail: The current Firebase user's email (if any).
    ///   - signOut: Closure to sign out of Firebase Auth.
    ///   - clearPersistedSession: Closure to clear persisted session state.
    ///   - clearMarker: Closure to clear the emulator marker.
    /// - Returns: Result indicating what was cleared.
    nonisolated static func clearEmulatorSessionIfNeeded(
        isEmulatorEnabled: Bool,
        hasMarker: Bool,
        currentUserEmail: String?,
        signOut: () throws -> Void,
        clearPersistedSession: () -> Void,
        clearMarker: () -> Void
    ) -> ClearResult {
        guard !isEmulatorEnabled else {
            return ClearResult(
                didClear: false,
                signOutCalled: false,
                persistedSessionCleared: false,
                markerCleared: false
            )
        }

        guard shouldClearSession(
            isEmulatorEnabled: false,
            hasMarker: hasMarker,
            currentUserEmail: currentUserEmail
        ) else {
            return ClearResult(
                didClear: false,
                signOutCalled: false,
                persistedSessionCleared: false,
                markerCleared: false
            )
        }

        var signOutCalled = false
        do {
            try signOut()
            signOutCalled = true
        } catch {
            signOutCalled = true
        }

        clearPersistedSession()
        clearMarker()

        return ClearResult(
            didClear: true,
            signOutCalled: signOutCalled,
            persistedSessionCleared: true,
            markerCleared: true
        )
    }

    /// Logs a warning if the test sign-in flag is present without the emulator flag.
    /// Call this early in launch to warn about misconfiguration.
    nonisolated static func logWarningIfTestSignInWithoutEmulator() {
        let hasTestSignInArg = GoDiveEmulatorTestSignIn.launchArgumentEmail() != nil
        let hasEmulatorArg = GoDiveFirebaseBootstrap.isEmulatorLaunchArgumentPresent

        if hasTestSignInArg && !hasEmulatorArg {
            log.warning("Test sign-in flag (-GoDiveEmulatorTestSignIn) present without emulator flag (-GoDiveUseFirebaseEmulator) — sign-in disabled")
        }
    }
}
#endif
