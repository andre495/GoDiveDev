#if DEBUG
import FirebaseAuth
import Foundation
import os
import SwiftData

/// DEBUG-only email/password sign-in against the Firebase Auth emulator for QA flows.
///
/// Use the launch argument `-GoDiveEmulatorTestSignIn <email>` to create or sign in a test user
/// on launch. Requires the `-GoDiveUseFirebaseEmulator` flag to also be set.
enum GoDiveEmulatorTestSignIn {
    nonisolated private static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "EmulatorTestSignIn"
    )

    nonisolated private static let launchArgument = "-GoDiveEmulatorTestSignIn"
    nonisolated private static let testPassword = "TestPassword123!"

    nonisolated(unsafe) private static var didRunLaunchSignIn = false

    /// `true` when both the emulator flag is active and Auth is pointed at the emulator host.
    nonisolated static var isAvailable: Bool {
        guard GoDiveFirebaseBootstrap.isConfigured else { return false }
        guard GoDiveFirebaseBootstrap.isEmulatorEnabled else { return false }
        return isAuthUsingEmulator
    }

    /// Runtime check that Auth is actually pointed at the emulator (not production).
    nonisolated private static var isAuthUsingEmulator: Bool {
        guard let settings = Auth.auth().settings else { return false }
        return settings.isAppVerificationDisabledForTesting
    }

    /// Parses `-GoDiveEmulatorTestSignIn <email>` from launch arguments and returns the email.
    nonisolated static func launchArgumentEmail() -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: launchArgument),
              index + 1 < args.count
        else { return nil }
        let email = args[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !email.hasPrefix("-") else { return nil }
        return email
    }

    /// Runs test sign-in on launch if the launch argument is present.
    /// Call from `AppSessionRootView` after session restore.
    @MainActor
    static func runLaunchSignInIfNeeded(modelContext: ModelContext) async {
        guard !didRunLaunchSignIn else { return }
        didRunLaunchSignIn = true

        guard let email = launchArgumentEmail() else { return }

        guard GoDiveFirebaseBootstrap.isEmulatorEnabled else {
            log.warning("Emulator test sign-in requested but emulator is not configured (-GoDiveUseFirebaseEmulator missing)")
            return
        }

        guard isAvailable else {
            log.warning("Emulator test sign-in requested but Auth is not using emulator")
            return
        }

        log.notice("Running emulator test sign-in for \(email, privacy: .private)")

        do {
            try await signIn(email: email, modelContext: modelContext)
            log.notice("Emulator test sign-in completed")
        } catch {
            log.error("Emulator test sign-in failed: \(String(describing: error), privacy: .private)")
        }
    }

    /// Creates or signs in a test user with the given email on the emulator.
    @MainActor
    static func signIn(email: String, modelContext: ModelContext) async throws {
        guard isAvailable else {
            throw EmulatorTestSignInError.emulatorNotAvailable
        }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            throw EmulatorTestSignInError.invalidEmail
        }

        do {
            try await Auth.auth().signIn(withEmail: trimmedEmail, password: testPassword)
        } catch let error as NSError {
            if error.domain == AuthErrorDomain,
               error.code == AuthErrorCode.userNotFound.rawValue
            {
                try await Auth.auth().createUser(withEmail: trimmedEmail, password: testPassword)
            } else {
                throw error
            }
        }

        guard let currentUser = Auth.auth().currentUser else {
            throw EmulatorTestSignInError.signInFailed
        }

        let profile = try createOrFetchTestProfile(
            firebaseUID: currentUser.uid,
            email: trimmedEmail,
            modelContext: modelContext
        )

        try modelContext.save()
        AccountSession.shared.attachTestProfile(profile)

        await GoDiveFirebaseCloudMessaging.uploadCurrentFCMTokenIfAvailable()
    }

    @MainActor
    private static func createOrFetchTestProfile(
        firebaseUID: String,
        email: String,
        modelContext: ModelContext
    ) throws -> UserProfile {
        let testAppleIdentifier = "emulator_test_\(firebaseUID)"

        if let existing = try? UserProfileStore.profile(
            appleUserIdentifier: testAppleIdentifier,
            modelContext: modelContext
        ) {
            return existing
        }

        let displayName = email.components(separatedBy: "@").first ?? "Test User"
        return try UserProfileStore.findOrCreateProfile(
            appleUserIdentifier: testAppleIdentifier,
            displayName: displayName,
            modelContext: modelContext
        )
    }

    enum EmulatorTestSignInError: Error, LocalizedError {
        case emulatorNotAvailable
        case invalidEmail
        case signInFailed

        var errorDescription: String? {
            switch self {
            case .emulatorNotAvailable:
                return "Firebase Auth emulator is not available"
            case .invalidEmail:
                return "Invalid email address"
            case .signInFailed:
                return "Sign-in failed"
            }
        }
    }
}
#endif
