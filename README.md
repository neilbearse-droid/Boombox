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

## Distribution

TestFlight via the paid developer account. Builds are valid 90 days;
refresh by pushing a new build. Recommend pairing with iOS Guided Access
for full lockdown (linked from the Setup Checklist).

## Out of scope for v1

Sleep timer, multiple listener profiles, remote management from a second
device, iPad layout, song-level tiles, lock screen widget, in-app volume
capping, and Siri. Best v1.1 candidate: an App Intent per tile so
"Hey Siri, play the dragon music" works from anywhere.
