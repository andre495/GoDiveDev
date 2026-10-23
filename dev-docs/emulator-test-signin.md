# Emulator Test Sign-In

DEBUG-only feature for QA to sign in with a fake user against the local Firebase Auth emulator, enabling tests of signed-in flows (like FCM token upload to Firestore) without a real Apple ID.

## Prerequisites

1. Firebase emulator suite installed (`npm install -g firebase-tools`)
2. The `catalog-cdn/` directory contains `firebase.json` with emulator configuration

## Starting the Emulator

```bash
cd catalog-cdn/
firebase emulators:start
```

This starts:
- Auth emulator on port `9099`
- Firestore emulator on port `8080`
- Storage emulator on port `9199`
- Emulator UI on port `4000`

## Launch Arguments

Add these launch arguments in Xcode (Product → Scheme → Edit Scheme → Run → Arguments):

| Argument | Description |
|----------|-------------|
| `-GoDiveUseFirebaseEmulator` | Points Firebase SDKs at the local emulator |
| `-GoDiveEmulatorTestSignIn <email>` | Auto-signs in with the given email on launch |

### Example

```
-GoDiveUseFirebaseEmulator
-GoDiveEmulatorTestSignIn qa@example.com
```

On launch, the app will:
1. Connect to the local Firebase emulators
2. Create or sign in a user with `qa@example.com` (fixed test password)
3. Create a local `UserProfile` and attach it to the session
4. Upload the FCM token to Firestore (if available)

## Email Domain Restriction

**Only `@example.com` emails are allowed.** This prevents accidental use of real email addresses during testing.

Valid examples:
- `qa@example.com`
- `tester@example.com`
- `user.name@example.com`

Invalid (rejected):
- `test@gmail.com`
- `test@example.org`
- `@example.com`

## Interactive Sign-In

When running in DEBUG with the emulator enabled (`-GoDiveUseFirebaseEmulator`), a small "Emulator test sign-in" button appears on the sign-in screen below the Sign in with Apple button.

Tap it to enter a test email address (must end with `@example.com`) and sign in without using Apple ID.

## Guard Rails

- **DEBUG-only**: All emulator sign-in code is wrapped in `#if DEBUG` and will not compile into Release builds
- **Single source of truth**: Gating uses `GoDiveFirebaseBootstrap.isEmulatorEnabled`, a flag set only when `useEmulator(withHost:port:)` is actually called
- **Abort on misconfiguration**: If the emulator launch argument is present but `useEmulator` was never called, sign-in is blocked and an error is logged
- **Email domain restriction**: Only `@example.com` addresses are accepted
- **No production impact**: Without the emulator launch argument, test sign-in is completely disabled
- **Session isolation**: Emulator sessions are marked and automatically cleared on non-emulator launches to prevent cross-contamination

## Testing FCM Token Upload

After emulator sign-in:

1. The app runs the normal post-sign-in flow
2. FCM token is uploaded to `users/{uid}/private/fcm_{deviceId}` in the **emulator Firestore**
3. View the token in the Firestore Emulator UI at `http://localhost:4000/firestore`

## Files

| File | Purpose |
|------|---------|
| `GoDiveMVP/Data/GoDiveEmulatorTestSignIn.swift` | Sign-in logic (DEBUG-only) |
| `GoDiveMVP/Data/GoDiveEmulatorSessionGuard.swift` | Session isolation + cleanup (DEBUG-only) |
| `GoDiveMVP/Data/GoDiveFirebaseBootstrap.swift` | Emulator configuration + `isEmulatorEnabled` flag |
| `GoDiveMVP/Views/Components/EmulatorTestSignInButton.swift` | UI button (DEBUG-only) |
| `GoDiveMVPTests/EmulatorTestSignInTests.swift` | Gating, email validation, and session guard tests |

## Why Not Demo Project ID

Firebase supports `demo-*` project IDs for fully offline emulator use. However, GoDive uses the production `GoogleService-Info.plist` for configuration, and switching project IDs at runtime would require:

1. Reconfiguring `FirebaseApp` with different options
2. Potentially invalidating existing Auth state
3. Handling edge cases where production and demo states conflict

The current approach provides equivalent safety through:
- Emulator flag gating (SDKs point at localhost)
- Session markers cleared on non-emulator launches
- `@example.com` email restriction
- All code excluded from Release builds

These measures ensure emulator sessions cannot reach production without the added complexity of project ID switching.
