# Firebase user profiles (friends-ready)

Firebase project: **`godive-1cff8`**. **Apple CloudKit** `UserProfile` remains the dive-log account. **Firestore** holds a **social directory** only (no dives, sites, media, or catalog). Architecture overview (CloudKit vs Firebase): **`cursor/hybrid_cloud_sync_boundaries.md`**, **`cursor/app_summary.md`** → **External dependencies**.

## One-time Console / CLI

1. **Authentication → Sign-in method → Apple** — enable for the iOS app (`PrimoSoftware.GoDiveMVP`). Soft-fail in-app if this is off.
2. **Firestore** — Standard `(default)` database (e.g. `nam5`).
3. **Storage** — default bucket enabled (Console → Storage). Deploy rules from `catalog-cdn/`:

```bash
npx firebase-tools@latest deploy --only firestore:rules,storage --project godive-1cff8
```

- Firestore rules: **`catalog-cdn/firestore.rules`** — authenticated read of `users/{uid}`; owner-only write; `users/{uid}/private/{doc}` owner-only.
- Storage rules: **`catalog-cdn/storage.rules`** — public read for `catalog/v1/**` and `users/{uid}/**`; owner write/delete for profile avatars (`users/{uid}/profile.jpg`, &lt; 5 MB image).

## App config (`GoogleService-Info.plist`)

1. Firebase Console → Project settings → Your apps → iOS app **GoDiveMVP** (`PrimoSoftware.GoDiveMVP`).
2. Download **`GoogleService-Info.plist`**.
3. Copy to **`GoDiveMVP/Config/GoogleService-Info.plist`** (gitignored). Template: **`GoogleService-Info.example.plist`**.
4. Xcode already references that path as a resource; missing plist → bootstrap skips Firebase (dive app still works).

SPM: **FirebaseCore**, **FirebaseAuth**, **FirebaseFirestore**, **FirebaseStorage**.

### If Auth fails with `API_KEY_SERVICE_BLOCKED` / Identity Toolkit 403

The iOS API key’s **API restrictions** omit Auth. In [Google Cloud → Credentials](https://console.cloud.google.com/apis/credentials?project=godive-1cff8) (project **godive-1cff8**):

1. Open the API key that matches **`API_KEY`** in `GoogleService-Info.plist`.
2. **API restrictions** → either **Don’t restrict key** (dev OK), or **Restrict key** and allow at least:
   - **Identity Toolkit API**
   - **Token Service API**
   - **Cloud Firestore API** (for profile upserts)
   - **Firebase Installations API** (recommended)
3. Save (propagation can take a few minutes).
4. Also confirm **APIs & Services → Library**: Identity Toolkit API is **Enabled**.
5. Sign out → Sign in with Apple again in the app.

## Public profile schema (`users/{uid}`)

| Field | Type | Notes |
|-------|------|--------|
| `displayName` | string | From local profile |
| `handle` | string | Reserved (empty) |
| `photoURL` | string | Firebase Storage download URL when avatar uploaded; empty if skipped |
| `profileHeroURL` | string | Friend-visible header media (tagged photo / video mirror); Storage **`profileHero.jpg`** or **`profileHero.mp4`** |
| `profileHeroMediaKind` | string | `"image"` or `"video"` |
| `profileHeroSourceMediaID` | string | Local **`DiveMediaPhoto.id`** last synced (owner debugging) |
| `interests` | array&lt;string&gt; | Onboarding tags: `"Scuba Diving"`, `"Free Diving"`, `"Snorkeling"` |
| `discoverable` | bool | Default `true` |
| `totalDiveCount` | number | Owner’s numbered dive total (synced from local log on launch) |
| `schemaVersion` | number | `3` |
| `createdAt` / `updatedAt` | timestamp | Server timestamps |

Private: `users/{uid}/private/account` → `{ appleUserIdentifier }`.  
Storage avatar: `users/{uid}/profile.jpg`.  
Friend profile hero: `users/{uid}/profileHero.jpg` or `profileHero.mp4` (synced from Profile tagged-media hero via **`GoDiveProfileHeroFirestoreSync`**).

## Client behavior

| Moment | Action |
|--------|--------|
| Launch | `GoDiveFirebaseBootstrap.configureIfNeeded()` |
| Sign in with Apple (returning) | Auth + upsert public/private (`interests`; preserve existing `photoURL`) |
| Sign in with Apple (**new** account) | Auth only; **defer** Firestore until photo step (`GoDiveFirestoreProfilePublishGate`) |
| Post-sign-up **photo** step (save or skip) | Upload JPEG to Storage when present → first Firestore upsert with `photoURL` + `interests` |
| **Profile edit** (name) | Upsert Firestore `displayName` (+ `interests`); keep existing `photoURL` |
| **Profile avatar change** | Re-upload Storage JPEG → upsert `photoURL` + `displayName` |
| **Profile hero tagged media** (Friends) | Export photo/video → Storage + merge `profileHeroURL` / `profileHeroMediaKind` |
| Post-launch (signed in, not deferred) | `syncIfAuthenticated` refreshes display name + interests |
| Sign out | Clears Firebase UID + defer gate + `Auth.auth().signOut()` |
| **Delete account** | Delete Storage avatar + Firestore docs + revoke Apple + Auth delete + wipe local SwiftData |

Helpers: `GoDiveFirebaseAuthSession`, `GoDiveFirestoreUserProfileSync`, `GoDiveFirestoreUserProfileMapping`, `GoDiveFirebaseProfilePhotoStorage`, `GoDiveAccountDeletion`.

## Deferred

`@handle` uniqueness UI; CloudKit Sharing / co-edit of one dive record; Universal Links (HTTPS invites work via custom scheme `godive://` today — HTTPS URLs are generated for sharing).

## Friends graph + shared dives

| Collection | Purpose |
|------------|---------|
| `friendInvites/{token}` | QR / link invites (`fromUid`, status, expiry) |
| `friendships/{sortedUidPair}` | Mutual friendship (`members`, `status`, `inviteToken`) |
| `users/{uid}/sharedDives/{diveId}` | Friend-visible dive projections (notes/media opt-in) |
| Storage `users/{uid}/sharedMedia/...` | Opt-in preview JPEGs |

Client helpers: `GoDiveFriendGraphService`, `GoDiveSharedDiveProjectionSync`, `GoDiveFriendInviteURL` (`godive://invite/{token}` + `https://godiveios.com/invite/{token}`).
