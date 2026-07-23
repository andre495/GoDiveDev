# Friend invite accepted — push notifications

When someone redeems a friend invite, the **inviter** can get an iOS push: *"{name} accepted your invite."* Tapping opens **Logbook → Friends**.

## App (client)

- **Firebase Cloud Messaging** (`FirebaseMessaging` SPM) + APNs device token → FCM registration token.
- Tokens stored at **`users/{uid}/private/fcm_{vendorUUID}`** (owner read/write only; same `private` rules as Apple link docs).
- Permission prompt runs after the main shell appears (signed in + Firebase configured). Sign-out deletes the current device doc before Firebase Auth sign-out.
- Payload **`data.type`** = **`friend_invite_accepted`**; **`friendUID`** = redeemer Firebase UID.

## Firebase Console (one-time)

1. **Apple Developer** — Keys → create an **APNs Auth Key** (.p8); note Key ID and Team ID.
2. **Firebase** project **`godive-1cff8`** → Project settings → **Cloud Messaging** → Apple app **`PrimoSoftware.GoDiveMVP`** → upload the APNs key.
3. **Xcode** — target **GoDiveMVP** → **Signing & Capabilities** → add **Push Notifications** (entitlements already include **`aps-environment`**; Release/TestFlight builds use production APNs when the capability is enabled).

## Deploy Cloud Function

From **`catalog-cdn/`** (Blaze billing required for outbound FCM):

```bash
cd catalog-cdn/functions && npm install && cd ..
firebase deploy --only functions:notifyFriendInviteAccepted --project godive-1cff8
```

Function: **`notifyFriendInviteAccepted`** — Firestore **`friendInvites/{token}`** `onDocumentUpdated` when **`status`** becomes **`redeemed`**.

## Privacy

FCM tokens are device identifiers for notification delivery only; not used for dive-log data. See **`docs/privacy-and-data.md`** (social / notifications).
