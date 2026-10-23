import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";
import { readFileSync } from "fs";
import { describe, it, before, after, beforeEach } from "node:test";

const PROJECT_ID = "demo-godive-rules";
const BUCKET_NAME = `${PROJECT_ID}.appspot.com`;

let testEnv;

function getStorage(auth) {
  return testEnv.authenticatedContext(auth.uid).storage();
}

function getUnauthStorage() {
  return testEnv.unauthenticatedContext().storage();
}

describe("Storage security rules", () => {
  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      storage: {
        rules: readFileSync("../storage.rules", "utf8"),
        host: "127.0.0.1",
        port: 9199,
      },
    });
  });

  after(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearStorage();
  });

  describe("catalog assets", () => {
    it("denies writing to catalog assets", async () => {
      const storage = getStorage({ uid: "some-user" });
      const ref = storage.ref("catalog/v1/test.json");
      const bytes = new Uint8Array([1, 2, 3]);
      await assertFails(ref.put(bytes));
    });
  });

  describe("profile photos", () => {
    const ownerUid = "owner-uid";
    const otherUid = "other-uid";

    it("allows owner to write profile photo", async () => {
      const storage = getStorage({ uid: ownerUid });
      const ref = storage.ref(`users/${ownerUid}/profile.jpg`);
      const bytes = new Uint8Array(1000);
      await assertSucceeds(ref.put(bytes, { contentType: "image/jpeg" }));
    });

    it("denies other users from writing profile photo", async () => {
      const storage = getStorage({ uid: otherUid });
      const ref = storage.ref(`users/${ownerUid}/profile.jpg`);
      const bytes = new Uint8Array(1000);
      await assertFails(ref.put(bytes, { contentType: "image/jpeg" }));
    });

    it("allows owner to delete profile photo", async () => {
      const storage = getStorage({ uid: ownerUid });
      const ref = storage.ref(`users/${ownerUid}/profile.jpg`);
      const bytes = new Uint8Array(1000);
      await ref.put(bytes, { contentType: "image/jpeg" });
      await assertSucceeds(ref.delete());
    });
  });

  describe("shared media - owner access", () => {
    const ownerUid = "owner-uid";
    const activityId = "activity-123";
    const mediaId = "media-456";

    it("allows owner to write thumb to shared media", async () => {
      const storage = getStorage({ uid: ownerUid });
      const ref = storage.ref(
        `users/${ownerUid}/sharedMedia/${activityId}/${mediaId}/thumb.jpg`
      );
      const bytes = new Uint8Array(500 * 1024);
      await assertSucceeds(ref.put(bytes, { contentType: "image/jpeg" }));
    });

    it("allows owner to write photo to shared media", async () => {
      const storage = getStorage({ uid: ownerUid });
      const ref = storage.ref(
        `users/${ownerUid}/sharedMedia/${activityId}/${mediaId}/photo.jpg`
      );
      const bytes = new Uint8Array(1000);
      await assertSucceeds(ref.put(bytes, { contentType: "image/jpeg" }));
    });

    it("allows owner to write video to shared media", async () => {
      const storage = getStorage({ uid: ownerUid });
      const ref = storage.ref(
        `users/${ownerUid}/sharedMedia/${activityId}/${mediaId}/video.mp4`
      );
      const bytes = new Uint8Array(1000);
      await assertSucceeds(ref.put(bytes, { contentType: "video/mp4" }));
    });

    it("allows owner to read their shared media", async () => {
      const storage = getStorage({ uid: ownerUid });
      const ref = storage.ref(
        `users/${ownerUid}/sharedMedia/${activityId}/${mediaId}/thumb.jpg`
      );
      const bytes = new Uint8Array(1000);
      await ref.put(bytes, { contentType: "image/jpeg" });
      await assertSucceeds(ref.getDownloadURL());
    });

    it("allows owner to delete shared media", async () => {
      const storage = getStorage({ uid: ownerUid });
      const ref = storage.ref(
        `users/${ownerUid}/sharedMedia/${activityId}/${mediaId}/thumb.jpg`
      );
      const bytes = new Uint8Array(1000);
      await ref.put(bytes, { contentType: "image/jpeg" });
      await assertSucceeds(ref.delete());
    });
  });

  describe("shared media - non-owner access restrictions", () => {
    const ownerUid = "owner-uid";
    const friendUid = "friend-uid";
    const strangerUid = "stranger-uid";
    const activityId = "activity-123";
    const mediaId = "media-456";

    it("denies other users from writing shared media", async () => {
      const storage = getStorage({ uid: friendUid });
      const ref = storage.ref(
        `users/${ownerUid}/sharedMedia/${activityId}/${mediaId}/thumb.jpg`
      );
      const bytes = new Uint8Array(1000);
      await assertFails(ref.put(bytes, { contentType: "image/jpeg" }));
    });

    it("denies other users from direct read of shared media", async () => {
      const ownerStorage = getStorage({ uid: ownerUid });
      const ownerRef = ownerStorage.ref(
        `users/${ownerUid}/sharedMedia/${activityId}/${mediaId}/thumb.jpg`
      );
      const bytes = new Uint8Array(1000);
      await ownerRef.put(bytes, { contentType: "image/jpeg" });

      const friendStorage = getStorage({ uid: friendUid });
      const friendRef = friendStorage.ref(
        `users/${ownerUid}/sharedMedia/${activityId}/${mediaId}/thumb.jpg`
      );
      await assertFails(friendRef.getDownloadURL());
    });

    it("denies unauthenticated direct read of shared media", async () => {
      const ownerStorage = getStorage({ uid: ownerUid });
      const ownerRef = ownerStorage.ref(
        `users/${ownerUid}/sharedMedia/${activityId}/${mediaId}/thumb.jpg`
      );
      const bytes = new Uint8Array(1000);
      await ownerRef.put(bytes, { contentType: "image/jpeg" });

      const unauthStorage = getUnauthStorage();
      const unauthRef = unauthStorage.ref(
        `users/${ownerUid}/sharedMedia/${activityId}/${mediaId}/thumb.jpg`
      );
      await assertFails(unauthRef.getDownloadURL());
    });

    it("denies other users from deleting shared media", async () => {
      const ownerStorage = getStorage({ uid: ownerUid });
      const ownerRef = ownerStorage.ref(
        `users/${ownerUid}/sharedMedia/${activityId}/${mediaId}/thumb.jpg`
      );
      const bytes = new Uint8Array(1000);
      await ownerRef.put(bytes, { contentType: "image/jpeg" });

      const friendStorage = getStorage({ uid: friendUid });
      const friendRef = friendStorage.ref(
        `users/${ownerUid}/sharedMedia/${activityId}/${mediaId}/thumb.jpg`
      );
      await assertFails(friendRef.delete());
    });
  });

  describe("legacy shared media", () => {
    const ownerUid = "owner-uid";
    const otherUid = "other-uid";
    const activityId = "activity-123";
    const mediaId = "media-456";

    it("allows owner to write legacy preview", async () => {
      const storage = getStorage({ uid: ownerUid });
      const ref = storage.ref(
        `users/${ownerUid}/sharedMedia/${activityId}/${mediaId}.jpg`
      );
      const bytes = new Uint8Array(1000);
      await assertSucceeds(ref.put(bytes, { contentType: "image/jpeg" }));
    });

    it("allows owner to read legacy preview", async () => {
      const storage = getStorage({ uid: ownerUid });
      const ref = storage.ref(
        `users/${ownerUid}/sharedMedia/${activityId}/${mediaId}.jpg`
      );
      const bytes = new Uint8Array(1000);
      await ref.put(bytes, { contentType: "image/jpeg" });
      await assertSucceeds(ref.getDownloadURL());
    });

    it("denies other users from direct read of legacy preview", async () => {
      const ownerStorage = getStorage({ uid: ownerUid });
      const ownerRef = ownerStorage.ref(
        `users/${ownerUid}/sharedMedia/${activityId}/${mediaId}.jpg`
      );
      const bytes = new Uint8Array(1000);
      await ownerRef.put(bytes, { contentType: "image/jpeg" });

      const otherStorage = getStorage({ uid: otherUid });
      const otherRef = otherStorage.ref(
        `users/${ownerUid}/sharedMedia/${activityId}/${mediaId}.jpg`
      );
      await assertFails(otherRef.getDownloadURL());
    });
  });

  describe("catch-all user paths", () => {
    const ownerUid = "owner-uid";
    const otherUid = "other-uid";

    it("allows owner to read their own paths", async () => {
      const storage = getStorage({ uid: ownerUid });
      const writeRef = storage.ref(`users/${ownerUid}/profile.jpg`);
      const bytes = new Uint8Array(1000);
      await writeRef.put(bytes, { contentType: "image/jpeg" });

      const readRef = storage.ref(`users/${ownerUid}/profile.jpg`);
      await assertSucceeds(readRef.getDownloadURL());
    });

    it("denies writing to arbitrary user paths", async () => {
      const storage = getStorage({ uid: ownerUid });
      const ref = storage.ref(`users/${ownerUid}/random/path/file.txt`);
      const bytes = new Uint8Array(1000);
      await assertFails(ref.put(bytes, { contentType: "text/plain" }));
    });

    it("allows owner to delete from catch-all paths", async () => {
      const storage = getStorage({ uid: ownerUid });
      const ref = storage.ref(`users/${ownerUid}/profile.jpg`);
      const bytes = new Uint8Array(1000);
      await ref.put(bytes, { contentType: "image/jpeg" });
      await assertSucceeds(ref.delete());
    });
  });
});
