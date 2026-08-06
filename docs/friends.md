# Friends

Connect with other GoDive divers using a **QR code** or **shareable link** — there is no public people search.

## Add a friend

1. Open **Profile → menu (☰) → Buddies**.
2. Tap the **QR** button.
3. Show the code, or use **Share link** / **Copy link**.
4. Your friend scans the QR code or opens the link on their phone (signed in with Apple). Links use **`https://links.godiveios.com/invite/…`** and open the GoDive app when it’s installed.
5. They confirm **Connect**. GoDive then opens **Logbook** on that friend’s **profile** page (header media, name, shared dive count).

The **Buddies** title uses the same collapsible large-title header as Settings and Certifications.

Invites expire after about a week. You can revoke an unused invite from the share sheet.

## When someone accepts your invite

If you shared a QR code or link and notifications are allowed for GoDive, you get a push when they tap **Connect** — for example, *"Alex accepted your invite."* Tap the notification to open your **Buddies** list in the Logbook tab.

You need to be signed in with Apple (Firebase social sign-in) and allow notifications when iOS asks. If you decline notifications, friends still connect; you just won’t get the alert.

## When a buddy shares new activities

If notifications are allowed, you also get a push when someone in your friend network shares **new** dives or snorkels — for example, *"Alex logged a new dive."* Activities that were already shared (already visible in Buddy Feed) do not notify again after your buddy reinstalls or rebuilds the app. The Home **Notifications** list keeps each activity’s original share time after rebuilds (it does not jump everything to “just now”). When a buddy shares several **new** activities at once (like a batch import), they arrive as **one** notification: *"Alex shared 5 new activities."*

If they **tag you** on a shared activity, the push uses that wording instead — for example, *"Alex tagged you in a new dive."* When several shared activities in one batch tag you, you get *"Alex tagged you in 5 new activities."*

Tap the notification to open that shared activity (the most recent one when several were shared). GoDive loads Buddy Feed data first so the activity is ready, then opens it — going back returns you to the feed. You are only notified the first time an activity is shared; edits and re-shares of the same activity don’t alert you again.

You can turn these alerts off (and back on) with **Settings → Buddy activity notifications** — the invite-accepted push above is not affected by that toggle.

## What friends can see

Once connected, open a friend from **Buddies** to browse their **shared dives** (tap their row — friends show a badge on the avatar).

By default (when **Share activities with buddies** is on in Settings), buddies can see dive and snorkel details such as site, date, depth, duration, conditions, tags, and marine life. **Notes** and **photos** stay private unless you turn on those Settings toggles. When **Share media with buddies** is on, buddies see thumbnails quickly in **Buddy Feed**, then full-quality photos (up to 20 per activity) and short video clips (up to 10, 30 seconds each) when they open the activity.

### Publishing a new activity

New activities start **local only** — nothing is shared automatically when you import or log them. Take your time to tag marine life, add notes, and pick photos first. If you have buddies in your network, a bright blue **Share with Buddies?** banner sits just above the details sheet on the map (visible when the sheet is expanded). It notes that you can change sharing anytime from the **⋯** menu, with:

- **Share** — publish the activity to your buddy network. Buddies see it in their **Buddy Feed** and get a notification.
- **Dismiss (×)** — hide the banner. The activity stays private on your devices. You can still share it later from **Activity Settings** (⋯ menu).

Opening **Activity Settings** also dismisses the banner for that activity. The banner hides when you collapse the sheet and comes back when you expand it again (until you dismiss it or open settings).

### Per-activity sharing

On any **owned** dive or snorkel, tap the **⋯** button (top right) to open **Activity Settings** for that activity only:

- **Share activity with buddies** — include or exclude this entry from your buddy network (Settings must still have **Share activities with buddies** on).
- **Share media with buddies** — turn media on for this activity and choose which photos/videos to include in a checkbox grid.
- **Share private notes with buddies** — include your private activity notes for buddies on this entry.
- **Status** — **Upload in progress…** banner while publishing, then an **Activity / Media / Private Notes** checklist (**Shared**, **Uploading**, or **Off**).
- **Delete dive** / **Delete snorkel** — pinned at the bottom of the sheet.

Per-activity choices override the global defaults for that entry once you change them in **Activity Settings**. New activities snapshot your media and notes defaults when created but always start unshared until you publish them (see **Publishing a new activity** above); changing Settings later does not alter activities you already have (unless you edit them in **Activity Settings**). Turning sharing off for an activity removes its Firebase projection and shared media from Storage. Global **Share activities with buddies** remains the master on/off switch for the buddy network.

## Buddy Feed posts

On **Logbook → Buddies**, each shared activity looks like a social post:

- **Header** — your buddy’s avatar and name (tap either to open their profile), a short “logged a dive/snorkel” line, and a compact time stamp.
- **Hero** — their featured photo or video when shared, and/or the dive depth profile (or snorkel map). Swipe when both are available.
- **Caption** — site, place, and key stats (notes stay on the full activity, not the feed post).
- **with** — avatars for divers tagged on that activity (no GoDive pin on these chips). When you are tagged, your avatar matches **Profile** (your photo on this device). Linked friends use their GoDive profile photos (or a photo already saved on their Buddies roster row), cached on-device like other feed avatars. Tap the **with** row to open that activity on **Map** and scroll to the **Buddies** section.
- **👌 like** — at the bottom of the post, below a divider. The OK emoji tints blue when you like; the tally updates right away and is saved for everyone who can see the post. Your buddy gets a push: *"{Your name} liked your dive/snorkel."* Tap that notification (or the matching row in Home **Notifications**) to open the activity in their logbook. Tap again to unlike.
- **Comments** — next to the like control. Tap the comment bubble to open the shared activity, then the comment thread sheet (scrollable comments with a text field pinned at the bottom). Commenter avatars match Buddy Feed rules — your comments show your **Profile** photo; friends show their cached GoDive photos. Type **`@`** to mention a GoDive friend (autocomplete by name); in the thread, mentioned names show in bold blue (without the `@`). Your buddy gets a push: *"{Your name} commented on your dive/snorkel: {preview}"* (first ~50 characters of the comment). Anyone you `@mention` gets *"{Your name} mentioned you in a comment"* (with a short preview when present). Tap either notification (or the matching row in Home **Notifications**) to open the activity with the comment thread already open.

Tap the caption area to open the full shared activity. On the shared activity **Map** tab (expanded details), like and comment icons sit under the dive stats (comment count when there are comments), with **Add a comment…** under those controls. Shared notes, marine life, and buddies (when present) appear below the like/comment row. Tap the comment icon to open the thread; tap **Add a comment…** to open the same thread with the keyboard ready.

On **your own** dive or snorkel (when sharing with friends is on), the same like and comment row appears on the **Map** tab so you can read and reply to buddy comments. You can see like tallies but cannot like your own activity.

## Viewing friend photos and videos

**Buddy Feed** loads small thumbnails first so the list stays fast. Friend profile photos (and tagged / commenter avatars from the friend graph) are cached on-device so the same buddy’s avatar does not re-download for every post. Your own avatar on tags and comments uses your local **Profile** photo so it stays in sync with Profile. When a post’s **featured** shared item is a photo, the hero crossfades to full quality when the content file is available. When it is a video, it **auto-plays once** (muted) after you scroll it into view — preferring a cached copy when one exists, otherwise streaming while the clip downloads. Tap an activity to open the same map / tank / media layout you use on your own dives — photos crossfade from the thumbnail to full quality when available, and videos play from the shared clip (poster thumbnail first). Opening a friend activity refreshes shared media from Firestore and starts loading **all** shared photos and videos in the background.

Tap a photo in the media grid or on the hero to open **fullscreen** — pinch to zoom on full-quality stills, swipe between items, and stream videos with the same controls.

Buddy media downloads use **Wi‑Fi or cellular**. Use **Settings → Activity Sharing → Upload media on wifi only** if you want your own full-quality **uploads** to wait for Wi‑Fi.

Your own full logbook on your devices (and private iCloud sync) is unchanged — friends see a read-only shared copy, not co-edit rights. When you edit a shared dive (details, tags, buddies, media, and so on), GoDive updates that shared copy so friends see the latest info.

## Background uploads

Buddy-share uploads (activity projections, thumbnails, and full-quality media) continue while GoDive is in the background for a limited time, and **resume automatically** when you reopen the app or after a force-quit. If **Upload media on wifi only** is on, full-quality uploads wait for Wi‑Fi and resume when you are back on Wi‑Fi. Progress is saved on-device so finished pieces are not re-uploaded from scratch.

## @mentions in notes

When editing **notes** on a dive or snorkel, type **`@`** to mention a GoDive friend (same autocomplete as comments). On the notes card, mentioned names show in bold blue (without the `@`). Saving notes **tags them on that activity** if they are not already tagged. When you later **publish/share** the activity, they get the usual *tagged you* notification — there is no separate “mentioned in notes” push, and editing notes after the activity is already shared only updates tags (no new push).

## Tag friends on dives

When you connect with someone (or they connect with you), GoDive links them to your **Dive Buddies** roster. If you already had a buddy with a matching name, that roster row becomes the friend link instead of creating a duplicate — your existing dive and trip tags stay on the same person. The same name check runs when you **import a dive**, **tag a buddy on a dive or photo**, or **add a buddy** to your roster.

Linked friends show the GoDive pin on the lower-right of their avatar (Buddies list, friend profile, Home, activities, trips, and search). Tap them from a dive, trip, search, or **Profile → Buddies** to open their **friend profile** (not the local-only buddy detail page). Buddies who are not friends yet show an **Invite** button — it creates your invite link and opens Messages (prefilled to their linked contact when you connected them in Contacts).

Tag friends on a dive from the dive overview **Buddies** sheet like any other buddy. Linked friends show their GoDive profile photo on the overview **Buddies** row (and on friend-shared activity **Buddies**) even when you have not saved a local Contacts photo for them. If they tagged you on a dive they shared, their shared dive detail can show that you were tagged.

## Remove a friend

Swipe a friend in **Buddies** and choose **Unfriend**, or use the confirmation alert. They will no longer see your newly shared dives (and you won’t see theirs).

## Friend profile

Tap a friend’s name in **Buddies** (or their avatar or name on a **Buddy Feed** post) to open their profile. The layout matches your own Profile page: featured header media, avatar, name, and a count of dives they’ve shared with you. The sheet area stays empty (no DAN or certification details).

Use the **book** icon in the top bar to open their **shared dives** logbook.

Your **featured profile media** (the tagged photo or looping video in your Profile header) is uploaded to Firebase so friends can see it on your friend profile. It updates when your header media changes.
