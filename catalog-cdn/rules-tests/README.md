# Firebase Rules Tests

Unit tests for Firestore and Storage security rules using `@firebase/rules-unit-testing`.

## Running tests

```bash
cd catalog-cdn/rules-tests
npm install
npm test
```

Tests run against the Firebase emulator with project ID `demo-godive-rules` (demo- prefix ensures no real project is affected).

## Running emulators for app testing

To test the iOS app against local emulators:

```bash
cd catalog-cdn
firebase emulators:start --project demo-godive-rules
```

Emulator ports:
- Auth: 127.0.0.1:9099
- Firestore: 127.0.0.1:8080
- Storage: 127.0.0.1:9199
- Emulator UI: http://127.0.0.1:4000

Then run the app in Xcode with launch argument `-GoDiveUseFirebaseEmulator` (DEBUG builds only).

## Test suites

- `firestore.test.js` — Firestore rules (invites, friendships, shared dives/trips, profiles)
- `storage.test.js` — Storage rules (profile photos, shared media access)
