const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getStorage } = require("firebase-admin/storage");
const crypto = require("crypto");
const {
  buildSpeciesSimilarity,
  publicFieldsFromPrivate,
  publicFieldsFromSiteReportPrivate,
} = require("./speciesSimilarity");

initializeApp();

const COMMUNITY_SIGHTINGS = "communitySightings";
const COMMUNITY_SITE_REPORTS = "communitySiteReports";
const SPECIES_SIMILARITY_STORAGE_PATH = "catalog/v1/species_similarity.json";
const SPECIES_SIMILARITY_META_PATH = "catalog/v1/species_similarity.meta.json";

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

/**
 * Mirror owner private staging → anonymized communitySightings/{contributionId}.
 */
exports.mirrorOntologySightingContribution = onDocumentWritten(
  "users/{uid}/ontologySightingContributions/{sightingUUID}",
  async (event) => {
    const after = event.data.after.exists ? event.data.after.data() : null;
    const before = event.data.before.exists ? event.data.before.data() : null;
    const db = getFirestore();

    if (!after) {
      const contributionId =
        before && typeof before.contributionId === "string"
          ? before.contributionId.trim()
          : "";
      if (!contributionId) return;
      await db.collection(COMMUNITY_SIGHTINGS).doc(contributionId).delete();
      return;
    }

    const publicFields = publicFieldsFromPrivate(after);
    if (!publicFields) return;

    const ref = db.collection(COMMUNITY_SIGHTINGS).doc(publicFields.contributionId);
    if (publicFields.status === "deleted") {
      await ref.delete();
      return;
    }

    await ref.set(
      {
        ...publicFields,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
);

/**
 * Mirror owner private SiteReport staging → communitySiteReports/{contributionId}.
 * One SiteReport per dive/snorkel activity (conditions + depth); sightings link via siteReportId.
 */
exports.mirrorOntologySiteReportContribution = onDocumentWritten(
  "users/{uid}/ontologySiteReportContributions/{activityUUID}",
  async (event) => {
    const after = event.data.after.exists ? event.data.after.data() : null;
    const before = event.data.before.exists ? event.data.before.data() : null;
    const db = getFirestore();

    if (!after) {
      const contributionId =
        before && typeof before.contributionId === "string"
          ? before.contributionId.trim()
          : "";
      if (!contributionId) return;
      await db.collection(COMMUNITY_SITE_REPORTS).doc(contributionId).delete();
      return;
    }

    const publicFields = publicFieldsFromSiteReportPrivate(after);
    if (!publicFields) return;

    const ref = db.collection(COMMUNITY_SITE_REPORTS).doc(publicFields.contributionId);
    if (publicFields.status === "deleted") {
      await ref.delete();
      return;
    }

    await ref.set(
      {
        ...publicFields,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
);

/**
 * Daily rebuild of community sighting similarity cache → Storage (public catalog path).
 */
exports.rebuildSpeciesSimilarityCache = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "UTC",
  },
  async () => {
    const db = getFirestore();
    const snap = await db.collection(COMMUNITY_SIGHTINGS).get();
    const rows = [];
    snap.forEach((doc) => {
      const data = doc.data() || {};
      rows.push({
        contributionId: doc.id,
        ...data,
      });
    });

    const payload = buildSpeciesSimilarity(rows, { limit: 15 });
    const body = JSON.stringify(payload);
    const sha256 = crypto.createHash("sha256").update(body, "utf8").digest("hex");
    const meta = {
      schemaVersion: 1,
      path: SPECIES_SIMILARITY_STORAGE_PATH,
      sha256,
      updatedAt: payload.updatedAt,
      speciesCount: Object.keys(payload.bySpecies || {}).length,
    };

    const bucket = getStorage().bucket();
    await bucket.file(SPECIES_SIMILARITY_STORAGE_PATH).save(body, {
      contentType: "application/json",
      metadata: {
        cacheControl: "public, max-age=3600",
      },
    });
    await bucket.file(SPECIES_SIMILARITY_META_PATH).save(JSON.stringify(meta), {
      contentType: "application/json",
      metadata: {
        cacheControl: "public, max-age=60, must-revalidate",
      },
    });

    await db.collection("catalogMeta").doc("speciesSimilarity").set(
      {
        ...meta,
        storagePath: SPECIES_SIMILARITY_STORAGE_PATH,
        writtenAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    console.log(
      `species similarity rebuilt: ${meta.speciesCount} seeds, sha256=${sha256.slice(0, 12)}…`
    );
  }
);

// ---------------------------------------------------------------------------
// Buddy activity liked — increment/decrement likeCount + notify the owner.
// ---------------------------------------------------------------------------

const BUDDY_ACTIVITY_LIKED_NOTIFICATION_TYPE = "buddy_activity_liked";

/**
 * When a friend creates/deletes `users/{ownerUid}/sharedDives/{activityId}/likes/{likerUid}`:
 * - maintain denormalized `likeCount` on the parent projection (Admin SDK only)
 * - on create, push the owner ("{Name} liked your dive/snorkel.")
 */
exports.notifyBuddyActivityLiked = onDocumentWritten(
  {
    document: "users/{ownerUid}/sharedDives/{activityId}/likes/{likerUid}",
    timeoutSeconds: 60,
  },
  async (event) => {
    const ownerUid = event.params.ownerUid;
    const activityId = event.params.activityId;
    const likerUid = event.params.likerUid;
    const beforeExists = event.data.before.exists;
    const afterExists = event.data.after.exists;
    if (beforeExists === afterExists) return;
    if (likerUid === ownerUid) return;

    const created = afterExists && !beforeExists;
    const deleted = !afterExists && beforeExists;
    if (!created && !deleted) return;

    const db = getFirestore();
    const activityRef = db
      .collection("users")
      .doc(ownerUid)
      .collection("sharedDives")
      .doc(activityId);

    const activitySnap = await activityRef.get();
    if (!activitySnap.exists) {
      console.warn(
        `buddy activity liked: missing sharedDive owner=${ownerUid} activity=${activityId}`
      );
      return;
    }

    const delta = created ? 1 : -1;
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(activityRef);
      if (!snap.exists) return;
      const current = Number(snap.data().likeCount) || 0;
      tx.update(activityRef, {
        likeCount: Math.max(0, current + delta),
      });
    });

    if (!created) return;

    const activityData = activitySnap.data() || {};
    const kindRaw = activityData.activityKind;
    const activityKind = kindRaw === "snorkel" ? "snorkel" : "scubaDive";

    const privateSnap = await db
      .collection("users")
      .doc(ownerUid)
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
    if (tokens.length === 0) {
      console.warn(
        `buddy activity liked: no FCM tokens for owner=${ownerUid}`
      );
      return;
    }

    let likerLabel = "A dive buddy";
    const likeData = event.data.after.data() || {};
    const likeName =
      typeof likeData.displayName === "string" ? likeData.displayName.trim() : "";
    if (likeName) {
      likerLabel = likeName;
    } else {
      const likerSnap = await db.collection("users").doc(likerUid).get();
      if (likerSnap.exists) {
        const displayName = (likerSnap.data().displayName || "").trim();
        if (displayName) likerLabel = displayName;
      }
    }

    const kindLabel = activityKind === "snorkel" ? "snorkel" : "dive";
    const title = "Someone liked your activity";
    const body = `${likerLabel} liked your ${kindLabel}.`;

    // APNs collapse-id max is 64 bytes — keep under that (UUID alone is 36).
    const collapseId = `blike_${activityId}`.slice(0, 64);

    const messages = tokens.map((token) => ({
      token,
      notification: { title, body },
      data: {
        type: BUDDY_ACTIVITY_LIKED_NOTIFICATION_TYPE,
        friendUID: likerUid,
        activityID: activityId,
        activityKind,
      },
      apns: {
        headers: {
          "apns-collapse-id": collapseId,
        },
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    }));

    const response = await getMessaging().sendEach(messages);

    if (response.failureCount > 0) {
      const failureCodes = response.responses
        .map((result) => {
          if (result.success) return null;
          const code = (result.error && result.error.code) || "unknown";
          const msg = (result.error && result.error.message) || "";
          return `${code}: ${msg}`;
        })
        .filter(Boolean);
      console.warn(
        `buddy activity liked push: ${response.failureCount}/${messages.length} failures for owner — ${failureCodes.join(" | ")}`
      );
      await deleteInvalidFcmTokens(db, messages, response.responses);
    }
    if (response.successCount > 0) {
      console.log(
        `buddy activity liked push: sent ${response.successCount}/${messages.length} for activity=${activityId}`
      );
    }
  }
);

// ---------------------------------------------------------------------------
// Buddy activity commented — increment/decrement commentCount + notify owner.
// ---------------------------------------------------------------------------

const BUDDY_ACTIVITY_COMMENTED_NOTIFICATION_TYPE = "buddy_activity_commented";
const BUDDY_ACTIVITY_MENTIONED_NOTIFICATION_TYPE = "buddy_activity_mentioned";
/** Character cap for the comment snippet in the owner push body (parity with iOS). */
const BUDDY_ACTIVITY_COMMENT_PREVIEW_MAX_CHARS = 50;
const BUDDY_ACTIVITY_MENTION_UIDS_MAX = 10;

/**
 * Collapse whitespace and truncate for APNs body preview.
 * @param {unknown} raw
 * @param {number} maxChars
 * @returns {string}
 */
function buddyActivityCommentNotificationPreview(raw, maxChars = BUDDY_ACTIVITY_COMMENT_PREVIEW_MAX_CHARS) {
  if (typeof raw !== "string") return "";
  const collapsed = raw.replace(/\s+/g, " ").trim();
  if (!collapsed) return "";
  if (collapsed.length <= maxChars) return collapsed;
  if (maxChars <= 1) return "…";
  return `${collapsed.slice(0, maxChars - 1)}…`;
}

/**
 * Sanitize `mentionedUids` from a comment doc (unique, non-empty, capped, no author).
 * @param {unknown} raw
 * @param {string} authorUid
 * @returns {string[]}
 */
function sanitizeMentionedUids(raw, authorUid) {
  if (!Array.isArray(raw)) return [];
  const seen = new Set();
  const out = [];
  for (const value of raw) {
    if (typeof value !== "string") continue;
    const uid = value.trim();
    if (!uid || uid === authorUid || seen.has(uid)) continue;
    seen.add(uid);
    out.push(uid);
    if (out.length >= BUDDY_ACTIVITY_MENTION_UIDS_MAX) break;
  }
  return out;
}

/**
 * True when uidA and uidB share an active friendship.
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} uidA
 * @param {string} uidB
 */
async function areActiveFriends(db, uidA, uidB) {
  if (!uidA || !uidB || uidA === uidB) return false;
  const snap = await db
    .collection("friendships")
    .where("members", "array-contains", uidA)
    .get();
  for (const doc of snap.docs) {
    const data = doc.data() || {};
    if (data.status !== "active") continue;
    const members = Array.isArray(data.members) ? data.members : [];
    if (members.includes(uidB)) return true;
  }
  return false;
}

/**
 * Collect FCM device tokens under `users/{uid}/private/fcm_*`.
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} uid
 * @returns {Promise<string[]>}
 */
async function collectFcmTokensForUser(db, uid) {
  const privateSnap = await db.collection("users").doc(uid).collection("private").get();
  const tokens = [];
  privateSnap.forEach((doc) => {
    if (!doc.id.startsWith(FCM_DOC_PREFIX)) return;
    const token = doc.data().fcmToken;
    if (typeof token === "string" && token.length > 0) {
      tokens.push(token);
    }
  });
  return tokens;
}

/**
 * When a friend (or owner) creates/deletes
 * `users/{ownerUid}/sharedDives/{activityId}/comments/{commentId}`:
 * - maintain denormalized `commentCount` on the parent projection
 * - on create: mention pushes to `mentionedUids`; owner comment push when not mentioned
 */
exports.notifyBuddyActivityCommented = onDocumentWritten(
  {
    document: "users/{ownerUid}/sharedDives/{activityId}/comments/{commentId}",
    timeoutSeconds: 60,
  },
  async (event) => {
    const ownerUid = event.params.ownerUid;
    const activityId = event.params.activityId;
    const beforeExists = event.data.before.exists;
    const afterExists = event.data.after.exists;
    if (beforeExists === afterExists) return;

    const created = afterExists && !beforeExists;
    const deleted = !afterExists && beforeExists;
    if (!created && !deleted) return;

    const db = getFirestore();
    const activityRef = db
      .collection("users")
      .doc(ownerUid)
      .collection("sharedDives")
      .doc(activityId);

    const activitySnap = await activityRef.get();
    if (!activitySnap.exists) {
      console.warn(
        `buddy activity commented: missing sharedDive owner=${ownerUid} activity=${activityId}`
      );
      return;
    }

    const delta = created ? 1 : -1;
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(activityRef);
      if (!snap.exists) return;
      const current = Number(snap.data().commentCount) || 0;
      tx.update(activityRef, {
        commentCount: Math.max(0, current + delta),
      });
    });

    if (!created) return;

    const commentData = event.data.after.data() || {};
    const authorUid =
      typeof commentData.authorUid === "string" ? commentData.authorUid.trim() : "";
    if (!authorUid) {
      console.log(
        `buddy activity commented: skip push (missing author) activity=${activityId}`
      );
      return;
    }

    const activityData = activitySnap.data() || {};
    const kindRaw = activityData.activityKind;
    const activityKind = kindRaw === "snorkel" ? "snorkel" : "scubaDive";
    const mentionedUids = sanitizeMentionedUids(
      commentData.mentionedUids,
      authorUid
    );

    let authorLabel = "A dive buddy";
    const commentName =
      typeof commentData.displayName === "string"
        ? commentData.displayName.trim()
        : "";
    if (commentName) {
      authorLabel = commentName;
    } else {
      const authorSnap = await db.collection("users").doc(authorUid).get();
      if (authorSnap.exists) {
        const displayName = (authorSnap.data().displayName || "").trim();
        if (displayName) authorLabel = displayName;
      }
    }

    const preview = buddyActivityCommentNotificationPreview(commentData.text);
    const messaging = getMessaging();

    // Mention pushes (author may be the owner).
    for (const recipientUid of mentionedUids) {
      const friendOfAuthor = await areActiveFriends(db, authorUid, recipientUid);
      const friendOfOwner =
        recipientUid === ownerUid
          ? true
          : await areActiveFriends(db, ownerUid, recipientUid);
      if (!friendOfAuthor && !friendOfOwner) {
        console.log(
          `buddy activity mentioned: skip non-friend recipient=${recipientUid} activity=${activityId}`
        );
        continue;
      }
      const tokens = await collectFcmTokensForUser(db, recipientUid);
      if (tokens.length === 0) {
        console.warn(
          `buddy activity mentioned: no FCM tokens for recipient=${recipientUid}`
        );
        continue;
      }
      const mentionBody = preview
        ? `${authorLabel} mentioned you in a comment: ${preview}`
        : `${authorLabel} mentioned you in a comment.`;
      const collapseId = `bment_${activityId}_${recipientUid}`.slice(0, 64);
      const messages = tokens.map((token) => ({
        token,
        notification: {
          title: "Mentioned in a comment",
          body: mentionBody,
        },
        data: {
          type: BUDDY_ACTIVITY_MENTIONED_NOTIFICATION_TYPE,
          friendUID: authorUid,
          activityID: activityId,
          activityKind,
          ownerUID: ownerUid,
        },
        apns: {
          headers: {
            "apns-collapse-id": collapseId,
          },
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      }));
      const response = await messaging.sendEach(messages);
      if (response.failureCount > 0) {
        await deleteInvalidFcmTokens(db, messages, response.responses);
      }
      if (response.successCount > 0) {
        console.log(
          `buddy activity mentioned push: sent ${response.successCount}/${messages.length} recipient=${recipientUid} activity=${activityId}`
        );
      }
    }

    // Owner comment push — skip when owner authored, or owner was @mentioned (mention push covers them).
    if (authorUid === ownerUid || mentionedUids.includes(ownerUid)) {
      return;
    }

    const tokens = await collectFcmTokensForUser(db, ownerUid);
    if (tokens.length === 0) {
      console.warn(
        `buddy activity commented: no FCM tokens for owner=${ownerUid}`
      );
      return;
    }

    const kindLabel = activityKind === "snorkel" ? "snorkel" : "dive";
    const title = "New comment on your activity";
    const body = preview
      ? `${authorLabel} commented on your ${kindLabel}: ${preview}`
      : `${authorLabel} commented on your ${kindLabel}.`;
    const collapseId = `bcomm_${activityId}`.slice(0, 64);

    const messages = tokens.map((token) => ({
      token,
      notification: { title, body },
      data: {
        type: BUDDY_ACTIVITY_COMMENTED_NOTIFICATION_TYPE,
        friendUID: authorUid,
        activityID: activityId,
        activityKind,
      },
      apns: {
        headers: {
          "apns-collapse-id": collapseId,
        },
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    }));

    const response = await messaging.sendEach(messages);

    if (response.failureCount > 0) {
      const failureCodes = response.responses
        .map((result) => {
          if (result.success) return null;
          const code = (result.error && result.error.code) || "unknown";
          const msg = (result.error && result.error.message) || "";
          return `${code}: ${msg}`;
        })
        .filter(Boolean);
      console.warn(
        `buddy activity commented push: ${response.failureCount}/${messages.length} failures for owner — ${failureCodes.join(" | ")}`
      );
      await deleteInvalidFcmTokens(db, messages, response.responses);
    }
    if (response.successCount > 0) {
      console.log(
        `buddy activity commented push: sent ${response.successCount}/${messages.length} for activity=${activityId}`
      );
    }
  }
);
