# Boombox

An iPhone app with two faces.

**Listener mode** is a wall of big friendly buttons — each one plays a single
Apple Music playlist. **Parent mode** ("Setup"), behind a PIN, is where
playlists get built and tiles get configured. Built natively on MusicKit so
the listener gets full Apple Music without any of Apple Music's interface.

Designed for one specific person: an adult with Down syndrome and autism.
Every decision flows from four principles:

1. One tap does one obvious thing.
2. Nothing in listener mode can delete, buy, break, or exit.
3. State is always visible: you can see and hear what is playing.
4. Sensory load is adjustable, and defaults are calm.

## Tech

- iOS 17.0+, SwiftUI, SwiftData (local config), MusicKit (all music).
- Playback through `SystemMusicPlayer`: music survives backgrounding and
  force-quit, lock screen / Control Centre / AirPlay work natively, and no
  background-audio entitlement is needed.
- Tile icons: the playlist's own artwork, one recognizable album cover
  picked from the playlist (downloaded once and cached locally), an emoji,
  a curated SF Symbol, or a photo from the camera roll.
- 4-digit parent PIN in the Keychain, behind a 2-second hold on a quiet
  corner gear (72 pt target, 60 pt drift tolerance, progress ring while
  holding). Five failed attempts → one-minute lockout. No recovery in v1.
- Single device, single Apple ID. The app lives on the listener's iPhone.

## Project setup

1. **Xcode 16+** and a **paid Apple Developer account**.
2. Open `Boombox.xcodeproj`, select the Boombox target, and set your own
   **bundle identifier** (currently `com.example.Boombox`) and **team**.
3. In the developer portal, enable the **MusicKit app service** on the App ID:
   Certificates, Identifiers & Profiles → Identifiers → your App ID →
   App Services → MusicKit. Tokens are handled automatically on-device;
   there is no developer token to manage.
4. Run on a **real iPhone signed into an Apple Music account**. The
   simulator cannot play Apple Music DRM content — all playback testing
   happens on-device.
5. `NSAppleMusicUsageDescription` is already set via the target's
   generated Info.plist build settings.

First run: hold the gear in the bottom-right corner for 2 seconds, create a
PIN, then use the Setup Checklist to grant music permission (the permission
dialog is only ever triggered from parent mode, never sprung on the
listener), and add tiles.

## Source layout

```
Boombox/
  BoomboxApp.swift            App entry; SwiftData container
  RootView.swift              Wall + corner gear + parent-mode cover
  Models/
    Tile.swift                SwiftData tile model (playlist ref, icon, colour…)
    AppSettings.swift         Singleton settings row
  Support/
    TilePalette.swift         8 swatches, calm variants, WCAG contrast picking
    PINManager.swift          Keychain PIN + attempt lockout
    SpeechManager.swift       AVSpeechSynthesizer confirmations
    Haptics.swift             Soft haptics only
    PhotoStore.swift          Tile photos in Application Support
  Music/
    MusicService.swift        Auth, subscription, library cache, orphan check
    PlaybackService.swift     SystemMusicPlayer queue/shuffle/repeat
    PreviewPlayer.swift       30-second AVPlayer previews (builder only)
  Listener/
    MusicWallView.swift       Tile grid, debounce, setup card, error card
    TileButton.swift          The tile itself (≥160 pt, press state)
    NowPlayingView.swift      Big artwork, ≤3 controls, no scrubber
    EqualizerBadge.swift      Animated badge; static in Calm Mode
    MessageCardView.swift     The only listener-facing "error" surface
  Parent/
    ParentAreaView.swift      PIN gate → parent mode
    PINGateView.swift         PIN pad, creation flow, lockout
    ParentModeView.swift      Nav shell (Tiles + Settings + Done)
    TileManagerView.swift     Reorder, hide, edit, delete, orphan banner
    TileEditorView.swift      Icon / label / spoken name / colour / playback
    PlaylistPickerView.swift  Tile from an existing library playlist
    PlaylistBuilderView.swift Catalogue search, previews, create playlist
    SettingsView.swift        Columns, labels, speech, Calm Mode, Next, PIN
    SetupChecklistView.swift  Permission, subscription, Guided Access, hearing
    MetricsView.swift         Listening history: chart, top tiles/songs, feed
```

## Behaviour notes

- Repeat-all defaults **on** per tile so music never runs out into silence;
  shuffle is per-tile and off by default.
- Tapping the already-playing tile opens Now Playing without restarting.
  Repeat taps on the same tile within 500 ms are ignored.
- Orphaned tiles (playlist deleted in the Music app) auto-hide from the wall
  and surface as a banner in the tile manager. Orphan detection only runs
  after a successful library fetch, so a network blip never hides tiles.
- Deleting a tile never touches the underlying Apple Music playlist.
- Calm Mode removes all animation (equaliser goes static, press states stop
  scaling) and swaps every swatch for its muted variant. The system Reduce
  Motion setting is respected independently.
- Label text colour is picked per swatch by WCAG contrast ratio.
- No alerts, no destructive actions, no purchases, no external links, and no
  autoplay anywhere in listener mode.
- Quiet hours (Settings → Schedule): the wall shows a calm "music is
  asleep" card inside the window and music soft-stops — at the end of
  the current song, with a 6-minute hard cap — after a spoken/visual
  "music is almost done" warning two minutes ahead. The sleep timer
  (30/60/90 min) is the one-night version of the same behaviour.
- Daily listening budget (Settings → Schedule, off by default): counted
  while the app runs; at the limit the wall rests for the day. Today's
  minutes show in Settings and in Listening → Signals.
- Reduced-choice mode (Settings → Music Wall → Tiles shown): cap the
  wall at 4, 2, or one giant tile for overwhelming days.
- Per-tile schedules (tile editor → Schedule): a tile can appear only
  during a daily window, e.g. bedtime music in the evening; windows may
  cross midnight.
- Signals (Listening screen): listening minutes today, absorbed extra
  touches (tap-acuity trend), and the loudest playback volume observed.
- Stronger tap feedback (Settings → Touch): heavier haptic so accepted
  taps are felt, which reduces re-tapping at the source.
- Seeing & Hearing (Settings): parent-set text size (Normal/Large/Huge)
  for labels and Now Playing, high-contrast tile borders (auto-contrast
  colour) for low vision, an adjustable speaking speed for spoken
  confirmations, and a soft screen-dim (Off/Low/Medium/High) for light
  sensitivity. Music Haptics (deaf / hard of hearing) is pointed to in
  the Setup Checklist — it's an iOS system feature that taps out the beat
  through the Taptic Engine and works automatically with Boombox's Apple
  Music playback.
- Photo and album-cover tiles fill the whole tile (a big recognizable
  face reads far better than a small square), with a bottom scrim so the
  label stays legible.
- Lyrics (Settings → Lyrics, off by default): big-text, follow-along
  lyrics shown in place of the artwork on Now Playing. Apple Music does
  not expose lyrics to third-party apps via MusicKit, so words come from
  LRCLIB (a free, open community source) with a graceful "no words"
  fallback; synced lyrics highlight and auto-scroll the current line.
- Reduce repeat taps (Settings → Touch, off by default): for listeners
  whose taps land several times. One accepted wall tap per 1.5s across
  all tiles (stray touches often hit a neighbouring tile), pause/play
  and Next cool down 1.5s, and the wall is shielded for 1s after the
  Now Playing back button so a trailing touch can't start a random tile.
- Explicit-content control (Settings → Content): with "Allow explicit
  songs" off, explicit-tagged songs are stripped from the queue before
  playback (slower tile start while filtering) and hidden from the
  playlist builder. Defaults to allowed so updating doesn't change
  existing behaviour; the builder shows an E badge on explicit songs
  when they're allowed.
- Listening metrics (parent mode → chart icon): tile taps are always
  logged; song changes are logged while the app is running (playback lives
  in the Music app's process, so songs played with Boombox fully closed
  are invisible). History is pruned at 90 days, and stays readable after a
  tile is deleted because labels are denormalized into the log.

## Things to verify on-device (can't be checked in CI)

- **MusicKit playlist editability**: MusicKit reliably edits playlists the
  app created; playlists created elsewhere may be read-only to the app. The
  design absorbs this — tiles reference playlists by ID, so edits made
  directly in the Music app sync onto the wall automatically.
- `MusicLibraryRequest` paging with very large libraries (limit is set
  to 500 playlists).
- Spoken confirmation timing vs. playback start (AVSpeech vs. the Music
  app's audio session ducking).

## Accessibility ship gates

- Every interactive element in listener mode ≥ 88 × 88 pt.
- Full VoiceOver pass; sensible focus order.
- Full Switch Control pass on the wall and Now Playing.
- Voice Control: "Tap Music", "Tap Pause" work as printed (labels match
  visible text).
- Text contrast meets WCAG AA on every swatch.
- Reduce Motion and Calm Mode verified to remove all animation.
- A live session with the actual listener before calling v1 done. This
  session outranks every other test.

## Widgets

Home Screen and Lock Screen widgets (BoomboxWidgets target), Timery-style:
small = 1 tile, medium = 2, large = a 2×2 or 2×3 grid depending on how many
tiles are widget-enabled. Lock Screen circular/rectangular widgets play the
first widget tile. Tapping any widget tile deep-links (`boombox://play/<id>`)
into the app, which starts playback immediately — widgets can't drive Apple
Music playback from their own process on iOS 17.

Data flow: the app writes a JSON snapshot plus pre-rendered icon files into
the App Group container whenever tiles change (launch and parent-mode exit);
the widget only reads files. Which tiles appear is the per-tile
"Show in widget" toggle, first six in wall order.

**App Group (required, single source of truth):** the `APP_GROUP_ID` build
setting (project level, inherited by both targets) is *the* group ID. Both
entitlements reference `$(APP_GROUP_ID)`, and both targets' Info.plist carry
an `AppGroupID` key set from the same variable — so the value the app is
entitled to and the value the code reads at runtime are always the same
string. Set `APP_GROUP_ID` once to `group.<your-bundle-id>` and make sure
the App Groups capability (Signing & Capabilities, both targets) has that
group checked. If the widget shows "Open Boombox to set up tiles," the App
Group isn't lining up — verify both targets have the App Groups capability
enabled with the group matching `APP_GROUP_ID`, then run the app once.

## Onboarding & caregiver setup

First entry to Setup runs a short guided flow (`OnboardingView`): welcome,
Apple Music permission priming, a hearing-safety step (Reduce Loud Sounds —
the app can't cap volume, so this is raised up front, not buried), and a
"make it theirs" step that nudges toward *their* words and *their* photos.
Shown once (`AppSettings.hasOnboarded`). Settings is organised into
categories (Music Wall, Sound & Speech, Seeing & Hearing, Touch, Schedule &
Limits, Lyrics, Content) rather than one long form. Language is
caregiver-neutral, never "parent," so the framing respects an adult listener.

## Business model

Free, everything unlocked, forever. A tip jar (Settings → Support Boombox,
behind the parent PIN — money never exists in listener mode) offers three
one-time consumable tips that unlock nothing.

App Store Connect setup: create three **consumable** in-app purchases with
product IDs `<your-bundle-id>.tip.small`, `.tip.medium`, `.tip.large`
(suggested display names "Nice Tip" / "Generous Tip" / "Amazing Tip";
suggested prices $2.99 / $9.99 / $19.99 — any tiers work, the UI sorts by
price and shows localized names/prices from the store). The product IDs
derive from the bundle ID at runtime, so they track a bundle-ID change
automatically. Tips load only once the IAPs exist in App Store Connect;
TestFlight uses the sandbox and won't charge real money.

## Distribution

TestFlight via the paid developer account. Builds are valid 90 days;
refresh by pushing a new build. Recommend pairing with iOS Guided Access
for full lockdown (linked from the Setup Checklist).

## Out of scope for v1

Sleep timer, multiple listener profiles, remote management from a second
device, iPad layout, song-level tiles, lock screen widget, in-app volume
capping, and Siri. Best v1.1 candidate: an App Intent per tile so
"Hey Siri, play the dragon music" works from anywhere.
