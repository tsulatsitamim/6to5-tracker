# Presence Tracker

A native macOS menu-bar app that tracks daily work time automatically by
sampling the webcam for face presence. No manual start/stop toggle.

## Requirements
- macOS 14.0+
- Xcode command line tools (`swift`, `codesign`)

## Build & run
make run          # builds release and opens the bundled .app
make test         # runs unit tests

## Usage
- Grant camera permission on first launch.
- Sit in front of the camera: the timer counts automatically.
- Step away: after the grace period (default 2 min) the clock pauses.
- Click the menu-bar item for today's total and daily history.
- Settings (sample interval, grace period, camera-busy behavior) apply
  after restarting.

## Privacy
Webcam frames are processed on-device with the Vision framework and never
written to disk or recorded. No data leaves the machine.
