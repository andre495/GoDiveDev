# Firebase Rules Tests

Unit tests for Firestore and Storage security rules using `@firebase/rules-unit-testing`.

## Running tests

```bash
cd catalog-cdn/rules-tests
npm install
npm test
```

Run individual test suites:

```bash
npm run test:firestore  # 41 Firestore tests
npm run test:storage    # 24 Storage tests (requires both emulators for cross-service rules)
```

Tests run against the Firebase emulator with project ID `demo-godive-rules` (demo- prefix ensures no real project is affected).

**Note:** Storage tests use cross-service rules (Storage rules reading Firestore data). When running both test suites together with `npm test`, there may be occasional timing-related flakiness due to emulator inter-process communication. All tests pass consistently when run separately.

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

- `firestore.test.js` — Firestore rules (invites, friendships, shared dives/trips, profiles, app query patterns)
- `storage.test.js` — Storage rules (profile photos, shared media access including cross-service friendship checks)
