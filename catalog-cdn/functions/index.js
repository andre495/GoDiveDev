const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
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
