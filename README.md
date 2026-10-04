# Presence Tracker

A native macOS menu-bar app that tracks daily work time automatically by
sampling the webcam for face presence. No manual start/stop toggle — just
optional **Keep working** / **Keep idle** overrides for when the camera
cannot tell the whole story.

## Requirements
- macOS 14.0+
- Xcode command line tools (`swift`, `codesign`)

## Install
Download the `.dmg` from the latest GitHub release, open it, and drag
`PresenceTracker.app` into `Applications`.

The app is **not notarized** (no Apple Developer certificate), so macOS
Gatekeeper blocks it on first launch with *"Apple could not verify…"*.
Right-click → Open does **not** bypass this. Clear the quarantine flag once,
then launch normally:

```
xattr -dr com.apple.quarantine /Applications/PresenceTracker.app
open /Applications/PresenceTracker.app
```

## Build & run
make run          # builds release and opens the bundled .app
make test         # runs unit tests

## Usage
- Grant camera permission on first launch.
- Sit in front of the camera: the timer counts automatically.
- Step away: after the grace period (default 2 min) the clock pauses.
- Click the menu-bar item for today's total and daily history.
- Use the **Tracking** selector in the popover to override the camera:
  - **Automatic** — the camera decides when the clock runs (default; always
    restored on launch).
  - **Keep working** — count continuously with the camera off, e.g. when you
    work on another device.
  - **Keep idle** — pause with the camera off even if you are in frame.
- The popover opens the full-screen **Dashboard** (today, this week,
  current sitting streak, live camera thumbnail) and **Settings**.
- Work history persists to
  `~/Library/Application Support/PresenceTracker/segments.json`.

## Privacy
Webcam frames are processed on-device with the Vision framework and never
written to disk or recorded. Only the derived work-time segments (start/end
timestamps) are stored locally. No data leaves the machine.
