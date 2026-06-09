# Focus

A simple, clean iOS app for showing up — press one button, watch a calm countdown
toward your daily goal (e.g. 8h of music), build the hours up over time, and work
toward a reward you choose. Discipline over motivation, accountability without the
guilt trip.

<p>&nbsp;</p>

## ⚠️ First: you need Xcode

This project is complete, but your Mac currently has only the **Command Line Tools**,
not full **Xcode** — which is required to build and run an iOS app.

1. Install **Xcode** (free) from the **Mac App Store**. It's a big download, so start it first.
2. After it installs, open it once and let it finish "Installing components."
3. (Optional, makes the command line point at Xcode):
   `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`

Requires **Xcode 16 or newer** (the project uses the modern synchronized‑folder format).

<p>&nbsp;</p>

## Run it

### On the Simulator (easiest)
1. Open the project:  `open Focus.xcodeproj`
2. In the toolbar, pick a simulator (e.g. **iPhone 16**) from the device menu.
3. Press **▶ Run** (or ⌘R). First build takes a minute.

### On your iPhone
1. Plug in your phone and select it in the device menu.
2. Select the **Focus** target → **Signing & Capabilities** tab → set **Team** to your
   Apple ID (Xcode → Settings → Accounts to add it). A free Apple ID works.
3. The bundle id is `com.brandon.focus`; if Xcode says it's taken, change it to something
   unique like `com.yourname.focus`.
4. Press **▶ Run**. On the phone, approve the developer profile under
   *Settings → General → VPN & Device Management* the first time.

<p>&nbsp;</p>

## How it works

- **Today** — One big **Start / Pause** button and a ring. Starting counts a session;
  the ring fills and the center counts **down** toward today's goal. Pause anytime —
  your progress is saved, so 8h is chipped away across the day, never one daunting block.
  Hit the goal and you get a little celebration.
- **Progress** — All‑time hours, days practiced, current streak, a 7‑day chart, and your
  **reward** progress bar. Tap **+** to add or fix time by hand (in case you forgot to hit
  start — the app is forgiving on purpose).
- **Settings** — Add activities (name, icon, color, daily goal) and set each one's reward
  (e.g. *"Buy that pedal" after 100 hours*). Turn on a **gentle daily reminder** with a
  time of your choosing.

It ships with one starter activity — **Music, 8h/day** — so it's usable immediately.

<p>&nbsp;</p>

## Notes

- **Private & offline.** No accounts, no network. Your data is a single JSON file in the
  app's Application Support folder, on‑device only.
- **No app icon yet.** It runs with a placeholder. To add one: open `Assets.xcassets` →
  `AppIcon` in Xcode and drag in a 1024×1024 image.
- **Make it yours.** Daily goals, rewards, colors, and the reminder are all editable in the
  app — no code changes needed.

<p>&nbsp;</p>

## Project layout

```
Focus.xcodeproj          The Xcode project
Focus/
  FocusApp.swift         App entry point
  Models.swift           Activity, FocusSession
  Store.swift            Data, persistence, timer logic, stats, reminders
  Theme.swift            Colors + time formatting
  RootView.swift         The three tabs
  TodayView.swift        The timer screen (ring + countdown + button)
  StatsView.swift        Progress: totals, chart, reward, recent sessions, add‑time
  SettingsView.swift     Activities + reminder settings
  ActivityEditView.swift Add / edit an activity and its reward
  Components.swift       Ring, pills, stat cards, progress bar
  Assets.xcassets        App icon + accent color
```
