import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";
import { readFileSync } from "fs";
import { describe, it, before, after, beforeEach } from "node:test";

const PROJECT_ID = "demo-godive-rules";

let testEnv;

function getFirestore(auth) {
  return testEnv.authenticatedContext(auth.uid).firestore();
}

function getUnauthFirestore() {
  return testEnv.unauthenticatedContext().firestore();
}

async function setAdminDoc(path, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const segments = path.split("/");
    let ref = db.collection(segments[0]).doc(segments[1]);
    for (let i = 2; i < segments.length; i += 2) {
      ref = ref.collection(segments[i]).doc(segments[i + 1]);
    }
    await ref.set(data);
  });
}

describe("Firestore security rules", () => {
  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: readFileSync("../firestore.rules", "utf8"),
        host: "127.0.0.1",
        port: 8080,
      },
    });
  });

  after(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  describe("friendInvites", () => {
    const ownerUid = "owner-uid";
    const redeemerUid = "redeemer-uid";
    const strangerUid = "stranger-uid";
    const tokenId = "abc123token";

    it("allows owner to create an invite", async () => {
      const db = getFirestore({ uid: ownerUid });
      const inviteRef = db.collection("friendInvites").doc(tokenId);
      await assertSucceeds(
        inviteRef.set({
          fromUid: ownerUid,
          status: "open",
          expiresAt: new Date(Date.now() + 86400000),
          createdAt: new Date(),
        })
      );
    });

    it("denies creating invite with mismatched fromUid", async () => {
      const db = getFirestore({ uid: ownerUid });
      const inviteRef = db.collection("friendInvites").doc(tokenId);
      await assertFails(
        inviteRef.set({
          fromUid: strangerUid,
          status: "open",
          expiresAt: new Date(Date.now() + 86400000),
          createdAt: new Date(),
        })
      );
    });

    it("allows signed-in user to get invite by token", async () => {
      await setAdminDoc(`friendInvites/${tokenId}`, {
        fromUid: ownerUid,
        status: "open",
        expiresAt: new Date(Date.now() + 86400000),
        createdAt: new Date(),
      });

      const db = getFirestore({ uid: redeemerUid });
      const inviteRef = db.collection("friendInvites").doc(tokenId);
      await assertSucceeds(inviteRef.get());
    });

    it("denies listing invites for any signed-in user", async () => {
      await setAdminDoc(`friendInvites/${tokenId}`, {
        fromUid: ownerUid,
        status: "open",
        expiresAt: new Date(Date.now() + 86400000),
        createdAt: new Date(),
      });

      const db = getFirestore({ uid: redeemerUid });
      await assertFails(db.collection("friendInvites").get());
    });

    it("denies unauthenticated get of invite", async () => {
      await setAdminDoc(`friendInvites/${tokenId}`, {
        fromUid: ownerUid,
        status: "open",
        expiresAt: new Date(Date.now() + 86400000),
        createdAt: new Date(),
      });

      const db = getUnauthFirestore();
      const inviteRef = db.collection("friendInvites").doc(tokenId);
      await assertFails(inviteRef.get());
    });

    it("allows redeemer to mark invite as redeemed", async () => {
      await setAdminDoc(`friendInvites/${tokenId}`, {
        fromUid: ownerUid,
        status: "open",
        expiresAt: new Date(Date.now() + 86400000),
        createdAt: new Date(),
      });

      const db = getFirestore({ uid: redeemerUid });
      const inviteRef = db.collection("friendInvites").doc(tokenId);
      await assertSucceeds(
        inviteRef.update({
          status: "redeemed",
          redeemedBy: redeemerUid,
        })
      );
    });

    it("allows owner to update their own invite (e.g. revoke)", async () => {
      await setAdminDoc(`friendInvites/${tokenId}`, {
        fromUid: ownerUid,
        status: "open",
        expiresAt: new Date(Date.now() + 86400000),
        createdAt: new Date(),
      });

      const db = getFirestore({ uid: ownerUid });
      const inviteRef = db.collection("friendInvites").doc(tokenId);
      await assertSucceeds(
        inviteRef.update({
          status: "revoked",
        })
      );
    });

    it("denies redeeming an already-redeemed invite", async () => {
      await setAdminDoc(`friendInvites/${tokenId}`, {
        fromUid: ownerUid,
        status: "redeemed",
        redeemedBy: "someone-else",
        expiresAt: new Date(Date.now() + 86400000),
        createdAt: new Date(),
      });

      const db = getFirestore({ uid: strangerUid });
      const inviteRef = db.collection("friendInvites").doc(tokenId);
      await assertFails(
        inviteRef.update({
          status: "redeemed",
          redeemedBy: strangerUid,
        })
      );
    });

    it("denies redeeming an expired invite", async () => {
      await setAdminDoc(`friendInvites/${tokenId}`, {
        fromUid: ownerUid,
        status: "open",
        expiresAt: new Date(Date.now() - 1000),
        createdAt: new Date(),
      });

      const db = getFirestore({ uid: redeemerUid });
      const inviteRef = db.collection("friendInvites").doc(tokenId);
      await assertFails(
        inviteRef.update({
          status: "redeemed",
          redeemedBy: redeemerUid,
        })
      );
    });

    it("allows owner to delete their invite", async () => {
      await setAdminDoc(`friendInvites/${tokenId}`, {
        fromUid: ownerUid,
        status: "open",
        expiresAt: new Date(Date.now() + 86400000),
        createdAt: new Date(),
      });

      const db = getFirestore({ uid: ownerUid });
      const inviteRef = db.collection("friendInvites").doc(tokenId);
      await assertSucceeds(inviteRef.delete());
    });

    it("denies stranger from deleting invite", async () => {
      await setAdminDoc(`friendInvites/${tokenId}`, {
        fromUid: ownerUid,
        status: "open",
        expiresAt: new Date(Date.now() + 86400000),
        createdAt: new Date(),
      });

      const db = getFirestore({ uid: strangerUid });
      const inviteRef = db.collection("friendInvites").doc(tokenId);
      await assertFails(inviteRef.delete());
    });
  });

  describe("friendships", () => {
    const ownerUid = "owner-uid";
    const redeemerUid = "redeemer-uid";
    const strangerUid = "stranger-uid";
    const tokenId = "valid-token";
    const friendshipId = "owner-uid_redeemer-uid";

    it("allows creating friendship with valid open invite", async () => {
      await setAdminDoc(`friendInvites/${tokenId}`, {
        fromUid: ownerUid,
        status: "open",
        expiresAt: new Date(Date.now() + 86400000),
        createdAt: new Date(),
      });

      const db = getFirestore({ uid: redeemerUid });
      const friendshipRef = db.collection("friendships").doc(friendshipId);
      await assertSucceeds(
        friendshipRef.set({
          members: [ownerUid, redeemerUid],
          status: "active",
          inviteToken: tokenId,
          createdAt: new Date(),
        })
      );
    });

    it("denies creating friendship with expired invite", async () => {
      await setAdminDoc(`friendInvites/${tokenId}`, {
        fromUid: ownerUid,
        status: "open",
        expiresAt: new Date(Date.now() - 1000),
        createdAt: new Date(),
      });

      const db = getFirestore({ uid: redeemerUid });
      const friendshipRef = db.collection("friendships").doc(friendshipId);
      await assertFails(
        friendshipRef.set({
          members: [ownerUid, redeemerUid],
          status: "active",
          inviteToken: tokenId,
          createdAt: new Date(),
        })
      );
    });

    it("denies creating friendship with nonexistent invite", async () => {
      const db = getFirestore({ uid: redeemerUid });
      const friendshipRef = db.collection("friendships").doc(friendshipId);
      await assertFails(
        friendshipRef.set({
          members: [ownerUid, redeemerUid],
          status: "active",
          inviteToken: "fake-token",
          createdAt: new Date(),
        })
      );
    });

    it("denies creating friendship with redeemed invite", async () => {
      await setAdminDoc(`friendInvites/${tokenId}`, {
        fromUid: ownerUid,
        status: "redeemed",
        redeemedBy: "someone-else",
        expiresAt: new Date(Date.now() + 86400000),
        createdAt: new Date(),
      });

      const db = getFirestore({ uid: redeemerUid });
      const friendshipRef = db.collection("friendships").doc(friendshipId);
      await assertFails(
        friendshipRef.set({
          members: [ownerUid, redeemerUid],
          status: "active",
          inviteToken: tokenId,
          createdAt: new Date(),
        })
      );
    });

    it("denies inviter from creating friendship (redeemer must do it)", async () => {
      await setAdminDoc(`friendInvites/${tokenId}`, {
        fromUid: ownerUid,
        status: "open",
        expiresAt: new Date(Date.now() + 86400000),
        createdAt: new Date(),
      });

      const db = getFirestore({ uid: ownerUid });
      const friendshipRef = db.collection("friendships").doc(friendshipId);
      await assertFails(
        friendshipRef.set({
          members: [ownerUid, redeemerUid],
          status: "active",
          inviteToken: tokenId,
          createdAt: new Date(),
        })
      );
    });

    it("allows valid recipient to create friendship with invite owner", async () => {
      await setAdminDoc(`friendInvites/${tokenId}`, {
        fromUid: ownerUid,
        status: "open",
        expiresAt: new Date(Date.now() + 86400000),
        createdAt: new Date(),
      });

      const db = getFirestore({ uid: strangerUid });
      const friendshipId = ownerUid < strangerUid
        ? `${ownerUid}_${strangerUid}`
        : `${strangerUid}_${ownerUid}`;
      const friendshipRef = db.collection("friendships").doc(friendshipId);
      await assertSucceeds(
        friendshipRef.set({
          members: [ownerUid, strangerUid],
          status: "active",
          inviteToken: tokenId,
          createdAt: new Date(),
        })
      );
    });

    it("denies creating friendship without being in members list", async () => {
      await setAdminDoc(`friendInvites/${tokenId}`, {
        fromUid: ownerUid,
        status: "open",
        expiresAt: new Date(Date.now() + 86400000),
        createdAt: new Date(),
      });

      const db = getFirestore({ uid: strangerUid });
      const friendshipRef = db.collection("friendships").doc("owner-uid_redeemer-uid");
      await assertFails(
        friendshipRef.set({
          members: [ownerUid, redeemerUid],
          status: "active",
          inviteToken: tokenId,
          createdAt: new Date(),
        })
      );
    });

    it("allows member to read their friendship", async () => {
      await setAdminDoc(`friendships/${friendshipId}`, {
        members: [ownerUid, redeemerUid],
        status: "active",
        inviteToken: tokenId,
        createdAt: new Date(),
      });

      const db = getFirestore({ uid: ownerUid });
      const friendshipRef = db.collection("friendships").doc(friendshipId);
      await assertSucceeds(friendshipRef.get());
    });

    it("denies stranger from reading friendship", async () => {
      await setAdminDoc(`friendships/${friendshipId}`, {
        members: [ownerUid, redeemerUid],
        status: "active",
        inviteToken: tokenId,
        createdAt: new Date(),
      });

      const db = getFirestore({ uid: strangerUid });
      const friendshipRef = db.collection("friendships").doc(friendshipId);
      await assertFails(friendshipRef.get());
    });

    it("allows member to delete friendship", async () => {
      await setAdminDoc(`friendships/${friendshipId}`, {
        members: [ownerUid, redeemerUid],
        status: "active",
        inviteToken: tokenId,
        createdAt: new Date(),
      });

      const db = getFirestore({ uid: redeemerUid });
      const friendshipRef = db.collection("friendships").doc(friendshipId);
      await assertSucceeds(friendshipRef.delete());
    });

    it("denies stranger from deleting friendship", async () => {
      await setAdminDoc(`friendships/${friendshipId}`, {
        members: [ownerUid, redeemerUid],
        status: "active",
        inviteToken: tokenId,
        createdAt: new Date(),
      });

      const db = getFirestore({ uid: strangerUid });
      const friendshipRef = db.collection("friendships").doc(friendshipId);
      await assertFails(friendshipRef.delete());
    });
  });

  describe("sharedDives", () => {
    const ownerUid = "owner-uid";
    const friendUid = "friend-uid";
    const strangerUid = "stranger-uid";
    const diveId = "dive-123";
    const friendshipId = "friend-uid_owner-uid";

    it("allows owner to read their shared dives", async () => {
      await setAdminDoc(`users/${ownerUid}/sharedDives/${diveId}`, {
        title: "Test dive",
        startTime: new Date(),
      });

      const db = getFirestore({ uid: ownerUid });
      const diveRef = db.collection("users").doc(ownerUid).collection("sharedDives").doc(diveId);
      await assertSucceeds(diveRef.get());
    });

    it("allows friend to read owner's shared dives", async () => {
      await setAdminDoc(`friendships/${friendshipId}`, {
        members: [friendUid, ownerUid],
        status: "active",
        inviteToken: "some-token",
        createdAt: new Date(),
      });
      await setAdminDoc(`users/${ownerUid}/sharedDives/${diveId}`, {
        title: "Test dive",
        startTime: new Date(),
      });

      const db = getFirestore({ uid: friendUid });
      const diveRef = db.collection("users").doc(ownerUid).collection("sharedDives").doc(diveId);
      await assertSucceeds(diveRef.get());
    });

    it("denies stranger from reading shared dives", async () => {
      await setAdminDoc(`users/${ownerUid}/sharedDives/${diveId}`, {
        title: "Test dive",
        startTime: new Date(),
      });

      const db = getFirestore({ uid: strangerUid });
      const diveRef = db.collection("users").doc(ownerUid).collection("sharedDives").doc(diveId);
      await assertFails(diveRef.get());
    });

    it("allows owner to create shared dive", async () => {
      const db = getFirestore({ uid: ownerUid });
      const diveRef = db.collection("users").doc(ownerUid).collection("sharedDives").doc(diveId);
      await assertSucceeds(
        diveRef.set({
          title: "Test dive",
          startTime: new Date(),
        })
      );
    });

    it("denies creating shared dive with likeCount field", async () => {
      const db = getFirestore({ uid: ownerUid });
      const diveRef = db.collection("users").doc(ownerUid).collection("sharedDives").doc(diveId);
      await assertFails(
        diveRef.set({
          title: "Test dive",
          startTime: new Date(),
          likeCount: 5,
        })
      );
    });

    it("denies friend from creating dive on owner's profile", async () => {
      await setAdminDoc(`friendships/${friendshipId}`, {
        members: [friendUid, ownerUid],
        status: "active",
        inviteToken: "some-token",
        createdAt: new Date(),
      });

      const db = getFirestore({ uid: friendUid });
      const diveRef = db.collection("users").doc(ownerUid).collection("sharedDives").doc(diveId);
      await assertFails(
        diveRef.set({
          title: "Test dive",
          startTime: new Date(),
        })
      );
    });
  });

  describe("sharedTrips", () => {
    const ownerUid = "owner-uid";
    const friendUid = "friend-uid";
    const strangerUid = "stranger-uid";
    const tripId = "trip-123";
    const friendshipId = "friend-uid_owner-uid";

    it("allows owner to read their shared trips", async () => {
      await setAdminDoc(`users/${ownerUid}/sharedTrips/${tripId}`, {
        title: "Test trip",
      });

      const db = getFirestore({ uid: ownerUid });
      const tripRef = db.collection("users").doc(ownerUid).collection("sharedTrips").doc(tripId);
      await assertSucceeds(tripRef.get());
    });

    it("allows friend to read owner's shared trips", async () => {
      await setAdminDoc(`friendships/${friendshipId}`, {
        members: [friendUid, ownerUid],
        status: "active",
        inviteToken: "some-token",
        createdAt: new Date(),
      });
      await setAdminDoc(`users/${ownerUid}/sharedTrips/${tripId}`, {
        title: "Test trip",
      });

      const db = getFirestore({ uid: friendUid });
      const tripRef = db.collection("users").doc(ownerUid).collection("sharedTrips").doc(tripId);
      await assertSucceeds(tripRef.get());
    });

    it("denies stranger from reading shared trips", async () => {
      await setAdminDoc(`users/${ownerUid}/sharedTrips/${tripId}`, {
        title: "Test trip",
      });

      const db = getFirestore({ uid: strangerUid });
      const tripRef = db.collection("users").doc(ownerUid).collection("sharedTrips").doc(tripId);
      await assertFails(tripRef.get());
    });
  });

  describe("user profiles", () => {
    const ownerUid = "owner-uid";
    const otherUid = "other-uid";

    it("allows signed-in user to read any profile", async () => {
      await setAdminDoc(`users/${ownerUid}`, {
        displayName: "Test User",
      });

      const db = getFirestore({ uid: otherUid });
      const profileRef = db.collection("users").doc(ownerUid);
      await assertSucceeds(profileRef.get());
    });

    it("denies unauthenticated profile read", async () => {
      await setAdminDoc(`users/${ownerUid}`, {
        displayName: "Test User",
      });

      const db = getUnauthFirestore();
      const profileRef = db.collection("users").doc(ownerUid);
      await assertFails(profileRef.get());
    });

    it("allows owner to update their profile", async () => {
      await setAdminDoc(`users/${ownerUid}`, {
        displayName: "Test User",
      });

      const db = getFirestore({ uid: ownerUid });
      const profileRef = db.collection("users").doc(ownerUid);
      await assertSucceeds(profileRef.update({ displayName: "New Name" }));
    });

    it("denies other users from updating profile", async () => {
      await setAdminDoc(`users/${ownerUid}`, {
        displayName: "Test User",
      });

      const db = getFirestore({ uid: otherUid });
      const profileRef = db.collection("users").doc(ownerUid);
      await assertFails(profileRef.update({ displayName: "Hacked" }));
    });
  });
});
