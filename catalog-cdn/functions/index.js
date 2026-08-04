const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const FCM_DOC_PREFIX = "fcm_";
const INVITE_STATUS_REDEEMED = "redeemed";
const NOTIFICATION_TYPE = "friend_invite_accepted";

/**
 * When a friend invite moves to `redeemed`, notify the inviter (`fromUid`) on all
 * registered iOS devices (`users/{uid}/private/fcm_*`).
 */
exports.notifyFriendInviteAccepted = onDocumentUpdated(
  "friendInvites/{token}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!before || !after) return;

    if (after.status !== INVITE_STATUS_REDEEMED) return;
    if (before.status === after.status) return;

    const fromUid = after.fromUid;
    const redeemedBy = after.redeemedBy;
    if (typeof fromUid !== "string" || !fromUid) return;
    if (typeof redeemedBy !== "string" || !redeemedBy) return;

    const db = getFirestore();
    const privateSnap = await db
      .collection("users")
      .doc(fromUid)
      .collection("private")
      .get();

    const tokens = [];
    privateSnap.forEach((doc) => {
      if (!doc.id.startsWith(FCM_DOC_PREFIX)) return;
      const token = doc.data().fcmToken;
      if (typeof token === "string" && token.length > 0) {
        tokens.push(token);
      }
    });
    if (tokens.length === 0) return;

    let friendLabel = "A diver";
    const profileSnap = await db.collection("users").doc(redeemedBy).get();
    if (profileSnap.exists) {
      const displayName = (profileSnap.data().displayName || "").trim();
      if (displayName) friendLabel = displayName;
    }

    const title = "New friend on GoDive";
    const body = `${friendLabel} accepted your invite.`;

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: {
        type: NOTIFICATION_TYPE,
        friendUID: redeemedBy,
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    if (response.failureCount > 0) {
      console.warn(
        `friend invite push: ${response.failureCount}/${tokens.length} failures for inviter`
      );
    }
  }
);

// ---------------------------------------------------------------------------
// Buddy activity shared push — batched (20 s window per poster) + first-share
// dedupe so republishes / sharing off→on never re-notify friends.
// ---------------------------------------------------------------------------

const BUDDY_ACTIVITY_NOTIFICATION_TYPE = "buddy_activity_shared";
const BUDDY_ACTIVITY_STATE_COLLECTION = "buddyActivityPush";
const BUDDY_ACTIVITY_BATCH_WINDOW_MS = 20 * 1000;
// FIFO cap so the permanent dedupe list stays well under the 1 MiB doc limit.
const BUDDY_ACTIVITY_NOTIFIED_ID_CAP = 5000;
const NOTIFICATION_PREFS_DOC_ID = "notificationPrefs";
const NOTIFICATION_PREFS_BUDDY_FIELD = "buddyActivitySharesEnabled";

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Picks the activity friends should land on when tapping the push: the one
 * with the latest dive start time (falls back to the last queued).
 */
function latestPendingActivity(pending) {
  let latest = null;
  for (const item of pending) {
    if (!latest) {
      latest = item;
      continue;
    }
    const itemStart = item.startTimeMs || 0;
    const latestStart = latest.startTimeMs || 0;
    if (itemStart >= latestStart) latest = item;
  }
  return latest;
}

function buddyActivityNotificationCopy(posterName, pending) {
  const name = (posterName || "").trim() || "A dive buddy";
  if (pending.length === 1) {
    const kind = pending[0].kind === "snorkel" ? "snorkel" : "dive";
    return {
      title: "New buddy activity",
      body: `${name} logged a new ${kind}.`,
    };
  }
  return {
    title: "New buddy activities",
    body: `${name} shared ${pending.length} new activities.`,
  };
}

function taggedFirebaseUIDsFromTaggedBuddies(taggedBuddies) {
  if (!Array.isArray(taggedBuddies)) return [];
  const uids = [];
  for (const buddy of taggedBuddies) {
    const uid = buddy && buddy.firebaseUid;
    if (typeof uid === "string" && uid) uids.push(uid);
  }
  return uids;
}

function taggedPendingItemsForRecipient(recipientUid, pending) {
  return pending.filter((item) => {
    const tagged = Array.isArray(item.taggedFirebaseUIDs)
      ? item.taggedFirebaseUIDs
      : [];
    return tagged.includes(recipientUid);
  });
}

function buddyActivityTaggedNotificationCopy(posterName, taggedItems) {
  const name = (posterName || "").trim() || "A dive buddy";
  if (taggedItems.length === 1) {
    const kind = taggedItems[0].kind === "snorkel" ? "snorkel" : "dive";
    return {
      title: "Tagged in a buddy activity",
      body: `${name} tagged you in a new ${kind}.`,
    };
  }
  return {
    title: "Tagged in buddy activities",
    body: `${name} tagged you in ${taggedItems.length} new activities.`,
  };
}

function buddyActivityNotificationCopyForRecipient(
  posterName,
  pending,
  recipientUid
) {
  const taggedItems = taggedPendingItemsForRecipient(recipientUid, pending);
  if (taggedItems.length > 0) {
    return buddyActivityTaggedNotificationCopy(posterName, taggedItems);
  }
  return buddyActivityNotificationCopy(posterName, pending);
}

function isShareableActivityKind(kind) {
  return kind === "snorkel" || kind === "scubaDive";
}

function batchWindowAgeMs(state) {
  const windowStartedAt = state.windowStartedAt;
  if (!windowStartedAt || typeof windowStartedAt.toMillis !== "function") {
    return BUDDY_ACTIVITY_BATCH_WINDOW_MS + 1;
  }
  return Date.now() - windowStartedAt.toMillis();
}

function shouldOwnBatchWindow(state, pending) {
  if (pending.length === 0) return true;
  return batchWindowAgeMs(state) >= BUDDY_ACTIVITY_BATCH_WINDOW_MS;
}

async function collectBuddyActivityRecipientTokens(db, posterUid) {
  const friendshipsSnap = await db
    .collection("friendships")
    .where("members", "array-contains", posterUid)
    .get();
  const recipientUids = new Set();
  friendshipsSnap.forEach((doc) => {
    const data = doc.data();
    if (data.status !== "active") return;
    const members = Array.isArray(data.members) ? data.members : [];
    for (const member of members) {
      if (typeof member === "string" && member && member !== posterUid) {
        recipientUids.add(member);
      }
    }
  });
  if (recipientUids.size === 0) {
    return { recipientTokens: new Map(), recipientCount: 0 };
  }

  const recipientTokens = new Map();
  await Promise.all(
    Array.from(recipientUids).map(async (friendUid) => {
      const privateSnap = await db
        .collection("users")
        .doc(friendUid)
        .collection("private")
        .get();

      let enabled = true;
      const deviceTokens = [];
      privateSnap.forEach((doc) => {
        if (doc.id === NOTIFICATION_PREFS_DOC_ID) {
          if (doc.data()[NOTIFICATION_PREFS_BUDDY_FIELD] === false) {
            enabled = false;
          }
          return;
        }
        if (!doc.id.startsWith(FCM_DOC_PREFIX)) return;
        const token = doc.data().fcmToken;
        if (typeof token === "string" && token.length > 0) {
          deviceTokens.push(token);
        }
      });
      if (enabled && deviceTokens.length > 0) {
        recipientTokens.set(friendUid, deviceTokens);
      }
    })
  );
  return { recipientTokens, recipientCount: recipientUids.size };
}

/**
 * Fires when the poster creates `users/{uid}/buddySharePushSignals/{activityId}`
 * after a full projection upsert (create-once per activity). State doc
 * `buddyActivityPush/{uid}` (server-only; no client rules) keeps:
 * - `notifiedActivityIds`: permanent dedupe (re-created docs never re-notify)
 * - `pending`: activities queued in the current 20 s batch window
 * The invocation that opens a window sleeps 20 s, drains the queue, and sends
 * one push to all active friends (minus those who opted out in-app).
 */
const FCM_INVALID_TOKEN_CODES = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
]);

async function deleteInvalidFcmTokens(db, messages, responses) {
  const deletions = [];
  responses.forEach((result, index) => {
    if (result.success) return;
    const code = result.error && result.error.code;
    if (!FCM_INVALID_TOKEN_CODES.has(code)) return;
    const token = messages[index] && messages[index].token;
    if (typeof token !== "string" || !token) return;
    deletions.push(
      db
        .collectionGroup("private")
        .where("fcmToken", "==", token)
        .limit(5)
        .get()
        .then((snap) =>
          Promise.all(snap.docs.map((doc) => doc.ref.delete()))
        )
        .catch((err) => {
          console.warn(
            `buddy activity push: failed pruning invalid token (${code}): ${err}`
          );
        })
    );
  });
  if (deletions.length > 0) {
    await Promise.all(deletions);
  }
}

function mergePendingItems(existing, incoming) {
  const byId = new Map();
  for (const item of existing || []) {
    if (item && item.id) byId.set(item.id, item);
  }
  for (const item of incoming || []) {
    if (item && item.id && !byId.has(item.id)) byId.set(item.id, item);
  }
  return Array.from(byId.values());
}

exports.notifyBuddyActivityShared = onDocumentCreated(
  {
    document: "users/{uid}/buddySharePushSignals/{activityId}",
    timeoutSeconds: 120,
    // No Eventarc retry — concurrent retries were double-sending after APNs recovered.
    // Stale-window reclaim on a later signal covers stranded pending.
  },
  async (event) => {
    const posterUid = event.params.uid;
    const activityId = event.params.activityId;
    const signalData = event.data.data();
    if (!signalData) return;

    const kindRaw = signalData.activityKind;
    if (!isShareableActivityKind(kindRaw)) {
      console.warn(
        `buddy activity push: skip invalid activityKind for signal ${activityId}`
      );
      return;
    }

    console.log(
      `buddy activity push: signal received poster=${posterUid} activity=${activityId} kind=${kindRaw}`
    );

    const db = getFirestore();
    const stateRef = db
      .collection(BUDDY_ACTIVITY_STATE_COLLECTION)
      .doc(posterUid);
    const signalRef = db
      .collection("users")
      .doc(posterUid)
      .collection("buddySharePushSignals")
      .doc(activityId);

    const startTime = signalData.startTime;
    const startTimeMs =
      startTime && typeof startTime.toMillis === "function"
        ? startTime.toMillis()
        : 0;
    const queuedItem = {
      id: activityId,
      startTimeMs,
      kind: kindRaw === "snorkel" ? "snorkel" : "scubaDive",
      taggedFirebaseUIDs: taggedFirebaseUIDsFromTaggedBuddies(
        signalData.taggedBuddies
      ),
    };

    const queueResult = await db.runTransaction(async (tx) => {
      const snap = await tx.get(stateRef);
      const state = snap.exists ? snap.data() : {};
      const notified = Array.isArray(state.notifiedActivityIds)
        ? state.notifiedActivityIds
        : [];
      if (notified.includes(activityId)) {
        return { ownsWindow: false, queued: false, alreadyNotified: true };
      }

      const pending = Array.isArray(state.pending) ? state.pending : [];
      const alreadyQueued = pending.some((item) => item.id === activityId);

      // Already queued: reclaim a stale window so a later signal can drain after
      // a prior FCM failure left `pending` stranded (no Eventarc retry).
      if (alreadyQueued) {
        const ownsWindow = shouldOwnBatchWindow(state, pending);
        if (!ownsWindow) {
          return { ownsWindow: false, queued: false, alreadyNotified: false };
        }
        tx.set(
          stateRef,
          { windowStartedAt: Timestamp.now() },
          { merge: true }
        );
        return { ownsWindow: true, queued: true, alreadyNotified: false };
      }

      const ownsWindow = shouldOwnBatchWindow(state, pending);
      tx.set(
        stateRef,
        {
          pending: [...pending, queuedItem],
          windowStartedAt: ownsWindow
            ? Timestamp.now()
            : state.windowStartedAt || Timestamp.now(),
        },
        { merge: true }
      );
      return { ownsWindow, queued: true, alreadyNotified: false };
    });

    if (queueResult.alreadyNotified) {
      await signalRef.delete().catch(() => {});
      return;
    }
    if (!queueResult.queued) return;
    if (!queueResult.ownsWindow) return;

    await sleep(BUDDY_ACTIVITY_BATCH_WINDOW_MS);

    // Atomically claim the queue so only one drain can send (prevents duplicate
    // banners when media republish / concurrent reclaim races).
    const pendingToSend = await db.runTransaction(async (tx) => {
      const snap = await tx.get(stateRef);
      const state = snap.exists ? snap.data() : {};
      const pending = Array.isArray(state.pending) ? state.pending : [];
      if (pending.length === 0) return [];
      tx.set(
        stateRef,
        {
          pending: [],
          windowStartedAt: null,
          drainClaimedAt: Timestamp.now(),
        },
        { merge: true }
      );
      return pending;
    });

    if (pendingToSend.length === 0) return;

    const restorePending = async () => {
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(stateRef);
        const state = snap.exists ? snap.data() : {};
        const existing = Array.isArray(state.pending) ? state.pending : [];
        tx.set(
          stateRef,
          {
            pending: mergePendingItems(existing, pendingToSend),
            windowStartedAt: Timestamp.now(),
            drainClaimedAt: null,
          },
          { merge: true }
        );
      });
    };

    const { recipientTokens, recipientCount } =
      await collectBuddyActivityRecipientTokens(db, posterUid);
    if (recipientTokens.size === 0) {
      console.warn(
        `buddy activity push: no deliverable tokens for poster (${recipientCount} friends, ${pendingToSend.length} pending) — restoring queue`
      );
      await restorePending();
      return;
    }

    let posterName = "";
    const posterSnap = await db.collection("users").doc(posterUid).get();
    if (posterSnap.exists) {
      posterName = (posterSnap.data().displayName || "").trim();
    }

    const latest = latestPendingActivity(pendingToSend);
    const messages = [];
    for (const [recipientUid, tokens] of recipientTokens) {
      const copy = buddyActivityNotificationCopyForRecipient(
        posterName,
        pendingToSend,
        recipientUid
      );
      for (const token of tokens) {
        messages.push({
          token,
          notification: { title: copy.title, body: copy.body },
          data: {
            type: BUDDY_ACTIVITY_NOTIFICATION_TYPE,
            friendUID: posterUid,
            activityID: latest ? latest.id : "",
            activityCount: String(pendingToSend.length),
          },
          apns: {
            headers: {
              "apns-collapse-id": `buddy_activity_${posterUid}`,
            },
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
        });
      }
    }

    const response = await getMessaging().sendEach(messages);

    if (response.failureCount > 0) {
      const failureCodes = response.responses
        .map((result, index) => {
          if (result.success) return null;
          const code = (result.error && result.error.code) || "unknown";
          const msg = (result.error && result.error.message) || "";
          return `${code}: ${msg}`;
        })
        .filter(Boolean);
      console.warn(
        `buddy activity push: ${response.failureCount}/${messages.length} failures for poster network — ${failureCodes.join(" | ")}`
      );
      await deleteInvalidFcmTokens(db, messages, response.responses);
    }
    if (response.successCount === 0) {
      console.warn(
        `buddy activity push: zero successes for poster (${messages.length} messages) — restoring queue`
      );
      await restorePending();
      return;
    }

    console.log(
      `buddy activity push: sent ${response.successCount}/${messages.length} for ${pendingToSend.length} activities`
    );

    const signalCollection = db
      .collection("users")
      .doc(posterUid)
      .collection("buddySharePushSignals");

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(stateRef);
      const state = snap.exists ? snap.data() : {};
      const notified = Array.isArray(state.notifiedActivityIds)
        ? state.notifiedActivityIds
        : [];
      const merged = [...notified, ...pendingToSend.map((item) => item.id)];
      const trimmed =
        merged.length > BUDDY_ACTIVITY_NOTIFIED_ID_CAP
          ? merged.slice(merged.length - BUDDY_ACTIVITY_NOTIFIED_ID_CAP)
          : merged;
      tx.set(
        stateRef,
        {
          drainClaimedAt: null,
          notifiedActivityIds: trimmed,
        },
        { merge: true }
      );
    });

    await Promise.all(
      pendingToSend.map((item) => signalCollection.doc(item.id).delete())
    );
  }
);
