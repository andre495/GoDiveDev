# Buddy activity shared — push notifications

When a friend shares new activities to their friend network, everyone in the network gets one iOS push: *"{Name} logged a new dive."* or, for a burst, *"{Name} shared N new activities."* If the shared activity tags a friend by Firebase UID in **`taggedBuddies`**, that friend gets *"{Name} tagged you in a new dive/snorkel."* instead (or *tagged you in N new activities.* when several in the batch tag them). Tapping opens **Logbook → Buddy Feed → activity detail** (latest in the series for batched pushes) so Back returns to the feed.

## Design

- **Trigger:** client **`create()`** on **`users/{uid}/buddySharePushSignals/{activityId}`** immediately after the projection doc is **first** created (not on republish / media-only patches). Cloud Function **`onDocumentCreated`** on that path — reliable vs `sharedDives` merge writes.
- **One push per activity:** local **`friendSharePushSignalRecorded`** blocks any later signal write (including after projection delete/recreate from media edits). An existing **`sharedDives`** doc also blocks a new signal (already viewable by buddies). On full republish, local flags are **hydrated** from remote projection IDs so rebuild / CloudKit restore cannot re-signal history. Full republish **never wipes** `sharedDives` when sharing is still on but the friends graph is empty/unavailable (wipe only when Settings sharing is off). Server **`notifiedActivityIds`** is a second permanent dedupe. The drain **atomically claims** `pending` before FCM so concurrent reclaimers cannot double-send.
- **Home Notifications timing:** projections store stable **`sharedAt`** (set on first create; hydrated once from dive start if missing). Media content-tier patches must **not** bump **`updatedAt`** (that made buddy lists look “all new” after an owner rebuild). List sort uses **`sharedAt ?? updatedAt ?? startTime`**.
- **Batching:** activities queue in `pending` (each item stores `taggedFirebaseUIDs` from the signal); the invocation that opens a 20 s window sleeps, checks FCM tokens, sends **one** push per recipient device (`sendEach` — copy varies when the recipient is tagged), then clears `pending` and deletes processed signal docs. Stale windows (>20 s) are recovered so a crashed sender does not strand `pending`. `apns-collapse-id` = `buddy_activity_{posterUid}` so back-to-back bursts replace rather than stack.
- **Recipients:** `friendships` docs with `status == active` containing the poster, minus the poster. Receivers with `users/{uid}/private/notificationPrefs.buddyActivitySharesEnabled == false` are skipped (missing doc/field = enabled).
- **Payload `data`:** `type = buddy_activity_shared`, `friendUID` (poster), `activityID` (latest by dive `startTime`), `activityCount`.

## App (client)

- **`GoDiveBuddyActivityPushSignalSync`** — create-once signal after first projection write; delete on projection delete.
- **`GoDiveBuddyActivityPushPresentation`** — payload parsing, copy parity, pending-target store for cold launch.
- Tap → `ContentView` switches to Logbook, `LogbookView` lands on **Buddy Feed**, loads feed data (retries + direct `sharedDives` fetch if the list lags), then pushes `LogbookRoute.buddySharedDive` for the payload activity (single share) or the latest in a batch. Missing targets (unshared meanwhile) stay on the feed; **Back** returns to a feed that already includes the opened activity.
- **Settings → Buddy activity notifications** (default on) mirrors to `users/{uid}/private/notificationPrefs` via `GoDiveBuddyActivityPushPreferenceSync`; enabling re-runs push permission/token registration. FCM token storage is shared with the friend-invite push (`users/{uid}/private/fcm_{vendorUUID}` — see `friend_invite_push_notifications.md`).

## Rules

- **`users/{userId}/buddySharePushSignals/{activityId}`** — owner `read` / `create` (validated `activityKind`, `startTime`, `createdAt`) / `delete`; no client `update`. Owner read is required for the create-once transaction.
- **`users/{uid}/private`** — owner-only (FCM tokens + notification prefs).
- **`buddyActivityPush/{uid}`** — no client rules (default deny; Admin SDK only).

## Deploy

From **`catalog-cdn/`** (Blaze billing required for outbound FCM):

```bash
cd catalog-cdn/functions && npm install && cd ..
firebase deploy --only firestore:rules,functions:notifyBuddyActivityShared --project godive-1cff8
```

---

## Buddy activity liked

When a friend likes a shared activity (`users/{ownerUid}/sharedDives/{activityId}/likes/{likerUid}` create), Cloud Function **`notifyBuddyActivityLiked`**:

1. Increments denormalized **`likeCount`** on the parent projection (decrements on unlike/delete; never below 0).
2. Sends the owner a push: *"{Name} liked your dive/snorkel."*

**Payload `data`:** `type = buddy_activity_liked`, `friendUID` (liker), `activityID`, `activityKind`.

**Tap:** Logbook → **Me** → owned dive/snorkel detail (`GoDiveBuddyActivityLikedPushPresentation`).

**Client:** **`GoDiveSharedActivityLikeSync`** writes/deletes the like doc; Buddy Feed tallies update optimistically.

**APNs:** `apns-collapse-id` must stay ≤ 64 bytes (`blike_{activityId}`). Longer ids (e.g. including liker UID) cause every FCM send to fail.

**Deploy likes function + rules:**

```bash
cd catalog-cdn/functions && npm install && cd ..
firebase deploy --only firestore:rules,functions:notifyBuddyActivityLiked --project godive-1cff8
```

---

## Buddy activity commented (+ mentions)

When a friend (or the owner) creates a comment (`users/{ownerUid}/sharedDives/{activityId}/comments/{commentId}`), Cloud Function **`notifyBuddyActivityCommented`**:

1. Increments denormalized **`commentCount`** on the parent projection (decrements on delete; never below 0).
2. On create, for each UID in optional **`mentionedUids`** (≠ author; must be an active friend of the author or owner): push *"{Name} mentioned you in a comment: {preview}"* (`type = buddy_activity_mentioned`).
3. On create by someone **other than** the owner, pushes the owner: *"{Name} commented on your dive/snorkel: {preview}."* — **skipped** when the owner is in **`mentionedUids`** (mention push covers them). Preview is whitespace-collapsed and capped at **50** characters.

**Comment payload `data` (owner):** `type = buddy_activity_commented`, `friendUID` (author), `activityID`, `activityKind`.

**Mention payload `data`:** `type = buddy_activity_mentioned`, `friendUID` (author), `ownerUID`, `activityID`, `activityKind`.

**Tap (comment):** Logbook → owned dive/snorkel with comments open.

**Tap (mention):** If recipient is the activity owner → owned detail + comments; else → Buddy Feed shared detail + comments (`opensComments: true`).

**Client:** **`GoDiveSharedActivityCommentSync`** writes optional **`mentionedUids`** from `@` autocomplete; notes `@` mentions auto-tag buddies (publish uses existing tagged-you push).

**APNs:** comment collapse id `bcomm_{activityId}`; mention `bment_{activityId}_{recipientUid}` (≤ 64 bytes).

**Deploy comments function + rules:**

```bash
cd catalog-cdn/functions && npm install && cd ..
firebase deploy --only firestore:rules,functions:notifyBuddyActivityCommented --project godive-1cff8
```
