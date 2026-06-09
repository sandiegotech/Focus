# Shipping Focus to TestFlight

A step‑by‑step for getting **Focus** into testers' hands. You're already enrolled in the
Apple Developer Program ✅, so this is mostly mechanical. Budget ~30 minutes the first time
(plus Xcode's download and Apple's build processing).

> ⚠️ You must do the Apple sign‑in, signing, and upload steps yourself — they involve your
> Apple credentials and Apple's agreements. This guide makes each one a known click.

---

## 0. One‑time prerequisites

- **Install Xcode** from the Mac App Store, open it once, let it "Install additional components."
  (Optional: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.)
- **Pick a Bundle ID you own** — reverse‑DNS, globally unique, e.g. `com.brandonLASTNAME.focus`.
  The project currently uses `com.brandon.focus`; change it to something unique to you.

---

## 1. Configure signing

1. `open Focus.xcodeproj`
2. Select the **Focus** project (top of the navigator) → **Focus** target → **Signing & Capabilities**.
3. Tick **Automatically manage signing**.
4. **Team** → choose your Apple Developer team.
5. **Bundle Identifier** → set your unique id from step 0. Xcode registers the App ID for you.

If Xcode shows a signing error, it's almost always the Team not selected or a non‑unique bundle id.

---

## 2. Add an app icon  (required)

App Store Connect rejects builds without a marketing icon.

- `Assets.xcassets` → **AppIcon** → drag in a **1024×1024 PNG** (no transparency/alpha).
- Modern Xcode generates the rest of the sizes from that one image.

> Don't have one? Ask me — I'll generate a clean 1024px icon in the app's indigo theme that you
> can replace later.

---

## 3. Set version & build numbers

- **Version** (`MARKETING_VERSION`) is `1.0`, **Build** (`CURRENT_PROJECT_VERSION`) is `1` — fine for the first upload.
- **Every** subsequent upload needs a **higher Build number**. Bump it (1 → 2 → 3…) before each archive,
  or App Store Connect rejects the duplicate.

---

## 4. Silence the export‑compliance prompt (recommended)

Focus uses no non‑exempt encryption, so you can answer this once at the project level instead of
on every upload:

- Target → **Info** tab → add row: **App Uses Non‑Exempt Encryption** → **NO**
  (key `ITSAppUsesNonExemptEncryption`).

> Want me to bake this into the project (`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`)? Just ask.

---

## 5. Create the app record in App Store Connect

1. Go to **appstoreconnect.apple.com** → **Apps** → **➕** → **New App**.
2. **Platform:** iOS · **Name:** your app's public name. *"Focus" is almost certainly taken on the
   App Store* — use something distinct like **"Focus — Discipline Timer"** (this is the store name, not
   the on‑device name).
3. **Primary language**, **Bundle ID** (the one you set in step 1), **SKU** (any unique string, e.g. `focus-001`).
4. Create.

---

## 6. Archive the build

1. In Xcode's toolbar, set the run destination to **Any iOS Device (arm64)**.
   *(Archive is greyed out while a Simulator is selected.)*
2. **Product ▸ Archive**. Wait for the build; the **Organizer** opens when it's done.

---

## 7. Upload to TestFlight

1. In the Organizer, select the new archive → **Distribute App**.
2. Choose **TestFlight & App Store** (or **TestFlight Internal Only** for the fastest path).
3. **Automatically manage signing** → **Upload**.
4. The build shows up in App Store Connect as **Processing** for ~5–15 min (you'll get an email when ready).

---

## 8. Add testers

In App Store Connect → your app → **TestFlight** tab:

- **Internal testing** (fastest): add yourself / team members (up to 100). Available the moment the
  build finishes processing — **no review**.
- **External testing**: create a group, add tester emails or enable a **public link**. Requires a one‑time
  **Beta App Review** (usually < 24h) and you must fill in **Test Information** (what to test + a contact email).

Testers install the **TestFlight** app on their iPhone and tap your invite. **They need iOS 17 or newer.**

---

## Recurring releases

Bump **Build** number → **Product ▸ Archive** → **Distribute App** → **Upload**. The new build appears
under TestFlight automatically; internal testers get it right away.

---

## Focus‑specific notes

- **Deployment target is iOS 17+** — testers on iOS 16 or earlier can't install it. (Lower it in the target's
  *Minimum Deployments* if you need older devices — ask me and I'll confirm nothing breaks.)
- **Daily reminder**: the notification permission prompt appears on‑device the first time a tester enables
  the reminder — that's expected and works on a signed TestFlight build.
- **No backend, no accounts, no network** — there's nothing server‑side to configure or break.
- **"Cannot Be Installed" on a tester's phone** → almost always an iOS version below 17, or a provisioning
  glitch; re‑archive and re‑upload.

---

## Optional: one‑command uploads (ask me)

I can add a **Fastlane** `beta` lane + `ExportOptions.plist` so future releases are a single
`fastlane beta`, authenticated with an **App Store Connect API key** (a `.p8` key — no password). Say the
word and I'll wire it up.
