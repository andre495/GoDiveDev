# Trip share invite — push notifications

## Invite (to recipient)

When someone shares a trip with a GoDive friend, the **recipient** can get an iOS push — title **You're Invited**, body *"{name} invited you on {trip}!"*. Tapping opens **Home → that trip** (pending Accept / Decline).

### App (client)

- Payload **`data.type`** = **`trip_share_invite`**
- Keys: **`inviteId`**, **`sharerUid`**, **`tripId`**, optional **`title`**
- Client: **`GoDiveTripSharePushPresentation`** / **`GoDiveTripSharePushNavigationStore`**
- Tap → materialize pending local **`DiveTrip`** if needed → **`HomeRoute.tripDetail`**
- Home bell also lists pending/accepted invites via **`HomeNotificationsPresentation`**
- Invite create must write **`createdAt: FieldValue.serverTimestamp()`** — Firestore rules require **`createdAt == request.time`**. A wall-clock client `Timestamp` is permission-denied and the push never fires.

### Cloud Function

**`notifyTripShareInvite`** — Firestore **`users/{uid}/tripShareInvites/{inviteId}`** `onDocumentCreated` when **`status`** is **`pending`**.

## Accept (to sender)

When the recipient **Accept**s, the **sharer** can get an iOS push — title **Trip buddy joined**, body *"{name} joined {trip}!"*. Tap opens the sharer’s trip. The buddy shows a cert-style **Joined** badge on trip buddies.

### App (client)

- Payload **`data.type`** = **`trip_share_invite_accepted`**
- Keys: **`inviteId`**, **`tripId`** (sharer’s trip UUID), **`friendUID`** (recipient), optional **`title`**
- Client: **`GoDiveTripShareInviteAcceptedPushPresentation`** / navigation store
- Local **`DiveTrip.tripShareAcceptedFriendUIDs`** updated from push + **`reconcileOutgoingAcceptances`**

### Cloud Function

**`notifyTripShareInviteAccepted`** — `onDocumentUpdated` on the same invite path when **`pending` → `accepted`**.

## Deploy

From **`catalog-cdn/`** (Blaze billing required for outbound FCM):

```bash
cd catalog-cdn/functions && npm install && cd ..
firebase deploy --only functions:notifyTripShareInvite,functions:notifyTripShareInviteAccepted --project godive-1cff8
```

Also deploy Firestore rules when the invite / sharedTrips paths change:

```bash
firebase deploy --only firestore:rules --project godive-1cff8
```

## Privacy

Push copy uses display name + trip title only — no dive notes, GPS, or media. FCM tokens remain under **`users/{uid}/private/fcm_*`**.
