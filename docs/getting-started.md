# Getting started

## Before you sign in

Whenever you open GoDive while logged out, onboarding walks you through what the app offers:

### 1. Welcome — pick your activities

Choose one or more (**Scuba Diving** is selected by default):

- **Scuba Diving**
- **Snorkeling**

Tap **Get Started** to continue, or **Already have an account? Sign in** at the bottom to open the dedicated sign-in screen (skips the feature slides). Use the **back** chevron on that screen to return to welcome (or to the feature slides if you skipped from there). Activity picks on welcome are saved when you tap **Get Started**; if you sign in from welcome instead and Apple creates a new account, you’ll choose activities again in the post–sign-in setup.

### 2. Feature slides (personalized)

Slides are tailored to what you selected:

| Slide | Shown when |
|-------|------------|
| **Log every dive** | Scuba diving |
| **Track your snorkeling activities** | Snorkeling |
| **Explore sites across the world** | Always |
| **Share experiences with your friends** | Always |
| **Monitor your equipment** | Always |
| **Learn from thousands of marine species** | Scuba and/or snorkeling |

Swipe or tap **Continue** on earlier slides. On the **first** feature slide, **Back** returns to the welcome activity picker so you can change scuba or snorkeling. On later slides, **Back** goes to the previous slide. On the last slide, use **Sign in with Apple** at the bottom (**Skip** on earlier slides opens the dedicated sign-in screen).

### 3. Sign in with Apple

Create your on-device log with **Sign in with Apple** — either on the last feature slide or from the dedicated sign-in screen if you skipped ahead.

**New accounts** then walk through setup:

1. **Activities** — only if you signed in from the dedicated sign-in screen without picking activities on welcome (**Already have an account? Sign in**). Choose scuba diving or snorkeling, then **Continue**.
2. **Profile photo** — **Welcome,** *your name*; subtitle **Add a profile photo**. After you crop a photo, the wizard advances automatically; or **Skip for now**. A **back** chevron on later steps returns to the previous one.
3. **DAN insurance** — only if you chose scuba diving; optional. **Continue** appears after you enter a member number; or **Skip for now**.
4. **Certification** — only if you chose scuba diving. **Continue** appears after agency, certification name, and number are filled in; or **Skip for now**.
5. **Welcome** — title **Welcome**, subtitle **Let's Dive In**, with your photo, name, optional DAN and certification, and activity interests.

Tap **Let's dive in** on the preview.

6. **Contacts & Photos** — explains why GoDive needs access; tap **Continue** and approve each iOS prompt (or deny — you can change this later in Settings).

7. **Bring your old dives** — only if you chose scuba diving. Tap **Import dives** for **UDDF import** (choose a **.uddf** file or open the **MacDive Import** guide — no back button; **Skip** top-right exits to celebration), or **Skip for now** on the offer slide to go straight to celebration.

A **bubble celebration** plays, then GoDive opens to **Home**.

Returning visits while logged out start onboarding again from the welcome screen (activity picker). **Skip** on a feature slide or **Already have an account? Sign in** on welcome opens the dedicated sign-in screen. If that Sign in with Apple creates a **new** account (no prior GoDive profile), you still get activities → profile photo → permissions → optional import — not a jump straight to Home.

## Sign in

When you open GoDive after onboarding, sign in with **Sign in with Apple**. GoDive uses your Apple ID to keep your dive profile tied to your account.

- If Apple provides your name once, GoDive uses it for your display name.
- Otherwise your name starts as **Diver** — you can change it anytime from **Profile → menu → Edit Profile**.
- On devices signed into **iCloud**, your dive log can sync across your Apple devices (**CloudKit**) over Wi‑Fi or cellular, including in the background when iOS allows.
- GoDive may also create a lightweight **Firebase** social profile (display name) for future friends features — that is separate from your dive log. See the [Privacy Policy](privacy-and-data.md).

### First-time welcome

Returning sign-ins skip profile setup and open Home after the bubble celebration. Permissions for **Contacts** and **Photos** are requested during new-account onboarding (after profile setup, before the optional import slide).

## Your first dive

You can add dives in three ways:

1. **Import a file** — Garmin **.fit** or UDDF **.uddf** (including MacDive exports). See [Import dives](import.md).
2. **Manual entry** — add a dive yourself from **Logbook → + → Add activity**.
3. **Use another Apple device** — when signed into the same **iCloud** account, your dive log can sync across devices; photos stay in **iCloud Photos** and rematch on each phone.

After a successful import, GoDive usually opens the new dive so you can review map, tank, and media tabs.

## Quick tour

### Home

Your dashboard shows rotating highlights from dive photos and four lifetime stat tiles (deepest, longest, top site, top species). Tap a tile to see a top-five list.

### Logbook

All dives appear here, newest first. Use **+** to import or add a dive. Swipe a row left to delete.

### Open a dive

Tap any dive to open **dive detail** with three tabs across the top:

- **Map** — location and overview sheet  
- **Tank** — gas, cylinder, depth profile  
- **Media** — photos and videos from your library  

Drag the bottom sheet up or down to change how much detail you see.

### Field Guide

Browse categories of marine life and open a species page. Tag species on dive photos from the **Media** tab. To find a species by name, use the **Search** tab and pick **Marine life** (or type in the search field).

### Explore

Switch between **map** and **list** to browse dive sites. Toggle **My Sites** vs **All Sites** from the **center of the top bar** (map/list on the left, **+** on the right). Tap a site for dives logged there and tagged media. To find a site by name, use the **Search** tab — **Sites** includes both your logbook sites and the full **All Sites** catalog.

### Search

Tap the **Search** tab (magnifying glass). Pick a category tile or type to search dives, buddies, sites, species, tags, trips, gear, and certifications. **Sites** results match what you see under **Explore → All Sites**. See [Search](search.md).

### Profile

From **Home**, tap your avatar (top of the screen) to open **Profile**:

- Buddy-style blue sheet: your tagged media in the header, photo on the seam  
- Name and dive count beside your avatar  
- Sheet **Details** page: DAN insurance number and featured certification (tap the cert to open it; **View all certifications** when you have more than one)  
- Tap the **menu** (☰) for **Trips**, **Certifications**, **Equipment locker**, **Buddies**, **Friends**, **Edit Profile**, and **Settings**, with **Sign out** pinned at the bottom  
- Change your photo by tapping the avatar on Profile

## Permissions GoDive may ask for

| Permission | Why |
|------------|-----|
| **Photos** | Attach dive photos and videos; optional auto-upload by capture time |
| **Contacts** | Optionally link a dive buddy to someone in your address book |

You can decline either permission and still use most of GoDive. Photo attach and auto-upload need Photos access when you turn those features on.

## Units and defaults

Open **Profile → menu (☰) → Settings** to choose:

- **Imperial vs metric** display (depth, temperature, etc.)  
- **Default tank size** for gas calculations on new imports  
- **Automatically renumber dives**  
- **Auto-upload media to activities**

Details are in [Settings](settings.md).
