# Presence-based Work Tracker — Design Spec

Date: 2026-08-18

## Overview

A simple native macOS menu-bar app that tracks daily work usage automatically.
Instead of a manual start/stop toggle, it periodically samples the webcam and
detects whether a person is sitting in front of the machine. Presence maps to
"working"; absence (beyond a short grace period) pauses the clock.

Similar in spirit to TopTracker, but simpler and fully automatic.

## Goals & Non-Goals

**Goals**
- Automatically track daily work time via webcam presence detection.
- Show a live timer in the menu bar and a per-day history in a popover.
- Store everything locally; no network, no account.
- Light on CPU/battery.

**Non-Goals**
- No manual start/stop toggle (presence detection replaces it).
- No keyboard/mouse idle detection.
- No charts, weekly views, or export.
- No cross-platform support; macOS only.
- No video recording or frame persistence of any kind.

## Tech Stack

- Swift + SwiftUI, native macOS app.
- AVFoundation (`AVCaptureSession`) for on-demand camera sampling.
- Vision (`VNDetectFaceRectanglesRequest`) for face detection.
- SwiftData for persistence.
- Menu-bar-only app (no Dock icon).

## Architecture

Single-process menu-bar app with four components:

1. **PresenceDetector** — owns the camera. On each tick: opens an
   `AVCaptureSession`, grabs one frame, runs
   `VNDetectFaceRectanglesRequest`, returns `faceDetected: Bool`, then
   releases the session. Abstracted behind a protocol so the engine can be
   driven by a fake in tests.

2. **WorkSessionEngine** — timer + state machine. A `Timer` fires every
   `sampleInterval` seconds, queries the detector, and updates state.

3. **SessionStore** — SwiftData persistence for daily records.

4. **Settings** — persisted via `@AppStorage`: sample interval (default 5s),
   grace period (default 2 min), camera-busy behavior (default treat-as-present),
   launch-at-login.

UI: a `MenuBarExtra` showing a live timer, plus a popover with today's total
and a daily history list.

## State Machine

States: `Active` / `Grace` / `Idle`.

- Face detected → `Active` (counting), grace timer reset.
- No face while `Active` → `Grace` (still counting, grace countdown running).
- No face while `Grace`, grace expired → `Idle` (stop counting, close the open segment).
- Face returns during `Grace` → back to `Active`.

Grace period counts as work (it stays inside the open segment).

## Data Model

SwiftData entity:

```
WorkSegment {
  id: UUID
  startedAt: Date
  endedAt: Date?
  createdAt: Date
}
```

- While `Active`/`Grace`, one open segment exists (`endedAt == nil`).
- On entering `Idle`, `endedAt` is stamped and saved.
- On quit/crash, the open segment is closed on next launch using last known
  state (best-effort).
- A "day" is derived at query time: group segments by `startedAt`'s calendar
  day, sum durations. No aggregate table.
- Menu bar shows today's running total; popover lists last ~30 days.

## Permissions & Edge Cases

**Permissions**
- `NSCameraUsageDescription` in Info.plist with a clear purpose string.
- First launch prompts for camera access; if denied, menu bar shows a
  "camera denied" state with a button to open System Settings.

**Edge cases**
- **Camera busy** (Zoom/FaceTime in use): session start fails or yields no
  frame → configurable, default treat-as-present (keep counting), with a
  subtle "camera unavailable — assuming present" indicator.
- **Camera LED blink**: inherent to on-demand sampling; accepted.
- **Multiple faces**: any face = present.
- **No face but present** (head turned, dim light): absorbed by grace period.
- **Screen locked / sleep**: timer paused; on wake treated as idle until a
  face is seen (no phantom time).
- **Lid closed (MacBook)**: no camera → same as "camera busy" path.

**Error handling**
- Detector errors are caught, surfaced as a non-blocking state; the timer
  keeps running and shows the last known state (never crashes).
- SwiftData save failures are logged; timing continues in-memory.

## Testing

- Unit tests on `WorkSessionEngine` using a fake detector with scripted
  `faceDetected` sequences; assert `Active`→`Grace`→`Idle`, grace expiry,
  segment open/close.
- Unit tests on day-grouping logic in `SessionStore` (in-memory container).
- Detector is thin/hardware-bound; covered manually, kept behind a protocol.
- Buildable via `xcodebuild`/Swift Package so tests run without the GUI.
