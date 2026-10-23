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

## Launch Arguments

Add these launch arguments in Xcode (Product → Scheme → Edit Scheme → Run → Arguments):

| Argument | Description |
|----------|-------------|
| `-GoDiveUseFirebaseEmulator` | Points Firebase SDKs at the local emulator |
| `-GoDiveEmulatorTestSignIn <email>` | Auto-signs in with the given email on launch |

### Example

```
-GoDiveUseFirebaseEmulator
-GoDiveEmulatorTestSignIn qa-tester@example.com
```

On launch, the app will:
1. Connect to the local Firebase emulators
2. Create or sign in a user with `qa-tester@example.com` (fixed test password)
3. Create a local `UserProfile` and attach it to the session
4. Upload the FCM token to Firestore (if available)

## Interactive Sign-In

When running in DEBUG with the emulator enabled (`-GoDiveUseFirebaseEmulator`), a small "Emulator test sign-in" button appears on the sign-in screen below the Sign in with Apple button.

Tap it to enter any test email address and sign in without using Apple ID.

## Guard Rails

- **DEBUG-only**: All emulator sign-in code is wrapped in `#if DEBUG` and will not compile into Release builds
- **Emulator check**: Sign-in only proceeds if Auth is actually pointed at the emulator host (runtime check)
- **No production impact**: If the emulator flag is set but Firebase isn't configured for emulator, the app logs a warning and does nothing

## Testing FCM Token Upload

After emulator sign-in:

1. The app runs the normal post-sign-in flow
2. FCM token is uploaded to `users/{uid}/private/fcm_{deviceId}` in the **emulator Firestore**
3. View the token in the Firestore Emulator UI at `http://localhost:4000/firestore`

## Files

| File | Purpose |
|------|---------|
| `GoDiveMVP/Data/GoDiveEmulatorTestSignIn.swift` | Sign-in logic (DEBUG-only) |
| `GoDiveMVP/Data/GoDiveFirebaseBootstrap.swift` | Emulator configuration |
| `GoDiveMVP/Views/Components/EmulatorTestSignInButton.swift` | UI button (DEBUG-only) |
| `GoDiveMVPTests/EmulatorTestSignInTests.swift` | Gating logic tests |
