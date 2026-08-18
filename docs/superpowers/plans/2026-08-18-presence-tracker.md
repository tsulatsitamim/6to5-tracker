# Presence Tracker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A native macOS menu-bar app that tracks daily work time by periodically sampling the webcam for face presence (no manual start/stop).

**Architecture:** Swift Package Manager project with a pure-logic library (`TrackerCore`) and a thin app target (`TrackerApp`). A background timer samples the camera every N seconds via AVFoundation+Vision, feeds a presence state machine (`Active`/`Grace`/`Idle`) that opens/closes `WorkSegment` records (in-memory), surfaced through a `MenuBarExtra` popover. The app is hand-bundled into a `.app` by `Scripts/bundle.sh`.

**Tech Stack:** Swift 5.9+, SwiftUI, AVFoundation, Vision, SwiftData, macOS 14+.

**Spec:** `docs/superpowers/specs/2026-08-18-presence-work-tracker-design.md`

## Global Constraints

- macOS 14.0 minimum (`platforms: [.macOS(.v14)]`).
- No external dependencies — Apple frameworks only.
- Camera frames are in-memory only; never written to disk.
- No Dock icon (`LSUIElement=true` + `NSApplication.shared.setActivationPolicy(.accessory)`).
- Defaults: sample interval 5s, grace period 120s, camera-unavailable counts as present.
- Settings changes take effect on next launch (documented in UI).
- Build via `swift build`; test via `make test` (runs a hand-rolled assertion runner through `swift run TrackerCoreTests` — XCTest and Swift Testing are unavailable without full Xcode, only Command Line Tools). Run the app via `make run` (bundled `.app`).
- Storage is in-memory only: the SwiftData `@Model` macro does not expand under the Command Line Tools toolchain (its compiler plugin ships with Xcode), and hand-writing `PersistentModel` is fragile (crashes with "Invalid access before setting the backing data"). `WorkSegment` is a plain `final class` and `SessionStore` holds an array; work is tracked within a running session but does not persist across launches. Disk persistence is a documented limitation pending a full Xcode install.

---

### Task 1: Project scaffolding

**Files:**
- Create: `Package.swift`
- Create: `Sources/TrackerCore/TrackerCore.swift`
- Create: `Sources/TrackerApp/TrackerApp.swift`
- Create: `Tests/TrackerCoreTests/TestMain.swift`
- Create: `Scripts/Info.plist`
- Create: `Scripts/bundle.sh`
- Create: `Makefile`
- Create: `.gitignore`

**Interfaces:**
- Produces: build targets `TrackerCore` (library), `TrackerApp` (executable), `TrackerCoreTests` (tests). `make run` produces `build/PresenceTracker.app`.

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PresenceTracker",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "TrackerCore"),
        .executableTarget(
            name: "TrackerApp",
            dependencies: ["TrackerCore"]
        ),
        .executableTarget(
            name: "TrackerCoreTests",
            dependencies: ["TrackerCore"],
            path: "Tests/TrackerCoreTests"
        ),
    ]
)
```

- [ ] **Step 2: Write placeholder source files**

`Sources/TrackerCore/TrackerCore.swift`:
```swift
public struct TrackerCore {
    public static let version = "0.1.0"
}
```

`Sources/TrackerApp/TrackerApp.swift`:
```swift
import Foundation
import TrackerCore

print("PresenceTracker \(TrackerCore.version)")
```

`Tests/TrackerCoreTests/TestMain.swift` (hand-rolled test runner — XCTest/Swift Testing are unavailable without full Xcode, per Global Constraints):
```swift
import Darwin
import Foundation
import TrackerCore

// Hand-rolled test runner: XCTest and Swift Testing are unavailable without
// a full Xcode installation, so assertions and the entry point live here.
// Each task adds its suite function to TestMain.main() below.

private(set) var testCount = 0
private(set) var testFailures = 0

func fail(_ message: String, file: String = #file, line: Int = #line) {
    testFailures += 1
    print("FAIL \(file):\(line) - \(message)")
}

func expectTrue(
    _ condition: @autoclosure () -> Bool,
    _ message: @autoclosure () -> String,
    file: String = #file, line: Int = #line
) {
    testCount += 1
    if !condition() { fail(message(), file: file, line: line) }
}

func expectEqual<T: Equatable>(
    _ actual: @autoclosure () -> T,
    _ expected: @autoclosure () -> T,
    _ message: @autoclosure () -> String,
    file: String = #file, line: Int = #line
) {
    testCount += 1
    let a = actual()
    let e = expected()
    if a != e { fail("\(message()) - expected \(e), got \(a)", file: file, line: line) }
}

func expectNil(
    _ actual: @autoclosure () -> Any?,
    _ message: @autoclosure () -> String,
    file: String = #file, line: Int = #line
) {
    testCount += 1
    if actual() != nil { fail("\(message()) - expected nil", file: file, line: line) }
}

func expectNotNil(
    _ actual: @autoclosure () -> Any?,
    _ message: @autoclosure () -> String,
    file: String = #file, line: Int = #line
) {
    testCount += 1
    if actual() == nil { fail("\(message()) - expected non-nil", file: file, line: line) }
}

private func runVersionTests() {
    expectEqual(TrackerCore.version, "0.1.0", "TrackerCore.version should be 0.1.0")
}

@main
struct TestMain {
    static func main() {
        runVersionTests()

        print("== \(testCount) assertions, \(testFailures) failures ==")
        if testFailures > 0 {
            exit(1)
        }
        print("ALL TESTS PASSED")
    }
}
```

- [ ] **Step 3: Write `Scripts/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>PresenceTracker</string>
    <key>CFBundleDisplayName</key><string>Presence Tracker</string>
    <key>CFBundleIdentifier</key><string>com.presencetracker.app</string>
    <key>CFBundleExecutable</key><string>PresenceTracker</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSCameraUsageDescription</key>
    <string>PresenceTracker samples your webcam to detect whether you are at your desk so it can automatically track your working time. Frames are processed on-device and never saved or recorded.</string>
</dict>
</plist>
```

- [ ] **Step 4: Write `Scripts/bundle.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
swift build -c release
APP="$ROOT/build/PresenceTracker.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/Scripts/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/.build/release/TrackerApp" "$APP/Contents/MacOS/PresenceTracker"
codesign --force --sign - "$APP"
echo "Built $APP"
```

- [ ] **Step 5: Write `Makefile` and `.gitignore`**

`Makefile`:
```make
.PHONY: build test bundle run clean
build:
	swift build
test:
	swift run TrackerCoreTests
bundle:
	bash Scripts/bundle.sh
run: bundle
	open build/PresenceTracker.app
clean:
	swift package clean
	rm -rf build
```

`.gitignore`:
```
.build/
build/
.DS_Store
.swiftpm/
```

- [ ] **Step 6: Build and test**

Run: `swift build` then `swift run TrackerCoreTests`
Expected: build succeeds; the runner prints `ALL TESTS PASSED` and exits 0.

- [ ] **Step 7: Commit**

```bash
git init
git add .
git commit -m "chore: scaffold PresenceTracker Swift package"
```

---

### Task 2: Core types, settings, and protocols

**Files:**
- Create: `Sources/TrackerCore/PresenceDetecting.swift`
- Create: `Sources/TrackerCore/SessionRecording.swift`
- Create: `Sources/TrackerCore/EngineState.swift`
- Create: `Sources/TrackerCore/Settings.swift`
- Modify: `Sources/TrackerCore/TrackerCore.swift` (remove version stub, or leave as-is)

**Interfaces:**
- Consumes: nothing.
- Produces: `PresenceResult`, `PresenceDetecting`, `SessionRecording`, `EngineState`, `Settings` — used by Tasks 3, 4, 5, 6.

- [ ] **Step 1: Write `PresenceDetecting.swift`**

```swift
import Foundation

public enum PresenceResult: Equatable {
    case present
    case absent
    case cameraUnavailable
}

public protocol PresenceDetecting {
    func detectPresence() -> PresenceResult
}
```

- [ ] **Step 2: Write `SessionRecording.swift`**

```swift
import Foundation

public protocol SessionRecording: AnyObject {
    func startSegment(at date: Date)
    func endSegment(at date: Date)
}
```

- [ ] **Step 3: Write `EngineState.swift`**

```swift
import Foundation

public enum EngineState: Equatable {
    case idle
    case active
    case grace
}
```

- [ ] **Step 4: Write `Settings.swift`**

```swift
import Foundation

public enum Settings {
    public static let defaultSampleInterval: TimeInterval = 5
    public static let defaultGracePeriod: TimeInterval = 120
    public static let defaultCameraUnavailableCountsAsPresent = true

    public static let sampleIntervalKey = "sampleInterval"
    public static let gracePeriodKey = "gracePeriod"
    public static let cameraUnavailableCountsAsPresentKey = "cameraUnavailableCountsAsPresent"
}
```

- [ ] **Step 5: Build**

Run: `swift build`
Expected: compiles (no tests added; existing test still passes).

- [ ] **Step 6: Commit**

```bash
git add Sources/TrackerCore
git commit -m "feat: add core types, settings, and protocols"
```

---

### Task 3: WorkSessionEngine state machine

**Files:**
- Create: `Sources/TrackerCore/WorkSessionEngine.swift`
- Create: `Tests/TrackerCoreTests/WorkSessionEngineTests.swift`

**Interfaces:**
- Consumes: `PresenceResult`, `PresenceDetecting`, `SessionRecording`, `EngineState`, `Settings` (Task 2).
- Produces:
  - `WorkSessionEngine` with `init(detector:recorder:sampleInterval:gracePeriod:cameraUnavailableCountsAsPresent:clock:)`, `start()`, `stop()`, `state: EngineState`, `onStateChange: ((EngineState) -> Void)?`, and public `handle(result:at:)` (callable directly from the hand-rolled test executable). Detection runs on a background queue; state transitions + recorder calls run on main.

- [ ] **Step 1: Write the failing test file**

`Tests/TrackerCoreTests/WorkSessionEngineTests.swift`:
```swift
import Foundation
import TrackerCore

final class FakeDetector: PresenceDetecting {
    func detectPresence() -> PresenceResult { .absent }
}

final class FakeRecorder: SessionRecording {
    private(set) var started: [Date] = []
    private(set) var ended: [Date] = []

    func startSegment(at date: Date) { started.append(date) }
    func endSegment(at date: Date) { ended.append(date) }
}

private let engineBaseDate = Date(timeIntervalSince1970: 1_000)

private func makeEngine(
    recorder: FakeRecorder,
    gracePeriod: TimeInterval = 120,
    cameraUnavailableCountsAsPresent: Bool = true
) -> WorkSessionEngine {
    WorkSessionEngine(
        detector: FakeDetector(),
        recorder: recorder,
        sampleInterval: 5,
        gracePeriod: gracePeriod,
        cameraUnavailableCountsAsPresent: cameraUnavailableCountsAsPresent,
        clock: { engineBaseDate }
    )
}

private func testPresenceStartsSegmentAndActive() {
    let r = FakeRecorder()
    let engine = makeEngine(recorder: r)

    engine.handle(result: .present, at: engineBaseDate)

    expectEqual(engine.state, .active, "presence should activate the engine")
    expectEqual(r.started.count, 1, "one segment should start")
    expectEqual(r.ended.count, 0, "no segment should end")
}

private func testAbsenceMovesActiveToGraceWithoutEnding() {
    let r = FakeRecorder()
    let engine = makeEngine(recorder: r)

    engine.handle(result: .present, at: engineBaseDate)
    engine.handle(result: .absent, at: engineBaseDate.addingTimeInterval(5))

    expectEqual(engine.state, .grace, "absence should move active to grace")
    expectEqual(r.ended.count, 0, "segment should stay open during grace")
}

private func testGraceExpiryEndsSegment() {
    let r = FakeRecorder()
    let engine = makeEngine(recorder: r, gracePeriod: 120)

    engine.handle(result: .present, at: engineBaseDate)
    engine.handle(result: .absent, at: engineBaseDate.addingTimeInterval(5))
    engine.handle(result: .absent, at: engineBaseDate.addingTimeInterval(126))

    expectEqual(engine.state, .idle, "grace expiry should idle the engine")
    expectEqual(r.ended.count, 1, "segment should end on grace expiry")
    expectEqual(r.ended.first, engineBaseDate.addingTimeInterval(126) as Date?, "endedAt should match expiry sample time")
}

private func testFaceDuringGraceReturnsToActive() {
    let r = FakeRecorder()
    let engine = makeEngine(recorder: r)

    engine.handle(result: .present, at: engineBaseDate)
    engine.handle(result: .absent, at: engineBaseDate.addingTimeInterval(5))
    engine.handle(result: .present, at: engineBaseDate.addingTimeInterval(10))

    expectEqual(engine.state, .active, "face during grace should re-activate")
    expectEqual(r.started.count, 1, "re-activation should not start a new segment")
    expectEqual(r.ended.count, 0, "segment should remain open")
}

private func testAbsentWhileIdleStaysIdle() {
    let r = FakeRecorder()
    let engine = makeEngine(recorder: r)

    engine.handle(result: .absent, at: engineBaseDate)

    expectEqual(engine.state, .idle, "absent while idle should stay idle")
    expectEqual(r.started.count, 0, "no segment should start")
}

private func testCameraUnavailableCountsAsPresent() {
    let r = FakeRecorder()
    let engine = makeEngine(recorder: r, cameraUnavailableCountsAsPresent: true)

    engine.handle(result: .cameraUnavailable, at: engineBaseDate)

    expectEqual(engine.state, .active, "camera unavailable should count as present")
    expectEqual(r.started.count, 1, "a segment should start")
}

private func testCameraUnavailableCountsAsAbsent() {
    let r = FakeRecorder()
    let engine = makeEngine(recorder: r, cameraUnavailableCountsAsPresent: false)

    engine.handle(result: .cameraUnavailable, at: engineBaseDate)

    expectEqual(engine.state, .idle, "camera unavailable should count as absent")
    expectEqual(r.started.count, 0, "no segment should start")
}

private func testStopClosesOpenSegment() {
    let r = FakeRecorder()
    let engine = makeEngine(recorder: r)

    engine.handle(result: .present, at: engineBaseDate)
    engine.stop()

    expectEqual(engine.state, .idle, "stop should idle the engine")
    expectEqual(r.ended.count, 1, "stop should close the open segment")
}

func runEngineTests() {
    testPresenceStartsSegmentAndActive()
    testAbsenceMovesActiveToGraceWithoutEnding()
    testGraceExpiryEndsSegment()
    testFaceDuringGraceReturnsToActive()
    testAbsentWhileIdleStaysIdle()
    testCameraUnavailableCountsAsPresent()
    testCameraUnavailableCountsAsAbsent()
    testStopClosesOpenSegment()
}
```

Then register the suite in `Tests/TrackerCoreTests/TestMain.swift` — change `main()`:
```swift
        runVersionTests()

        print("== \(testCount) assertions, \(testFailures) failures ==")
```
to:
```swift
        runVersionTests()
        runEngineTests()

        print("== \(testCount) assertions, \(testFailures) failures ==")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift run TrackerCoreTests`
Expected: FAIL at build — `cannot find 'WorkSessionEngine' in scope` (the test file references the not-yet-written type).

- [ ] **Step 3: Implement `WorkSessionEngine.swift`**

```swift
import Foundation

public final class WorkSessionEngine {
    public var onStateChange: ((EngineState) -> Void)?

    public private(set) var state: EngineState = .idle {
        didSet { if oldValue != state { onStateChange?(state) } }
    }

    private let detector: PresenceDetecting
    private let recorder: SessionRecording
    private let sampleInterval: TimeInterval
    private let gracePeriod: TimeInterval
    private let cameraUnavailableCountsAsPresent: Bool
    private let clock: () -> Date

    private var graceDeadline: Date?
    private var timer: Timer?

    public init(
        detector: PresenceDetecting,
        recorder: SessionRecording,
        sampleInterval: TimeInterval = Settings.defaultSampleInterval,
        gracePeriod: TimeInterval = Settings.defaultGracePeriod,
        cameraUnavailableCountsAsPresent: Bool = Settings.defaultCameraUnavailableCountsAsPresent,
        clock: @escaping () -> Date = { Date() }
    ) {
        self.detector = detector
        self.recorder = recorder
        self.sampleInterval = sampleInterval
        self.gracePeriod = gracePeriod
        self.cameraUnavailableCountsAsPresent = cameraUnavailableCountsAsPresent
        self.clock = clock
    }

    public func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: sampleInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        closeIfNeeded(at: clock())
    }

    private func tick() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = self?.detector.detectPresence() ?? .cameraUnavailable
            DispatchQueue.main.async {
                guard let self else { return }
                self.handle(result: result, at: self.clock())
            }
        }
    }

    public func handle(result: PresenceResult, at date: Date) {
        let isPresent = result == .present
            || (result == .cameraUnavailable && cameraUnavailableCountsAsPresent)

        if isPresent {
            if state == .idle {
                state = .active
                recorder.startSegment(at: date)
            } else if state == .grace {
                state = .active
            }
            graceDeadline = nil
        } else {
            switch state {
            case .idle:
                break
            case .active:
                state = .grace
                graceDeadline = date.addingTimeInterval(gracePeriod)
            case .grace:
                if let deadline = graceDeadline, date >= deadline {
                    state = .idle
                    recorder.endSegment(at: date)
                    graceDeadline = nil
                }
            }
        }
    }

    private func closeIfNeeded(at date: Date) {
        if state == .active || state == .grace {
            state = .idle
            recorder.endSegment(at: date)
        }
        graceDeadline = nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift run TrackerCoreTests`
Expected: `ALL TESTS PASSED` (8 engine assertions).

- [ ] **Step 5: Commit**

```bash
git add Sources/TrackerCore/WorkSessionEngine.swift Tests/TrackerCoreTests/WorkSessionEngineTests.swift
git commit -m "feat: presence state machine engine with tests"
```

---

### Task 4: WorkSegment model, SessionStore, and day grouping

**Files:**
- Create: `Sources/TrackerCore/WorkSegment.swift`
- Create: `Sources/TrackerCore/SessionStore.swift`
- Create: `Sources/TrackerCore/DaySummary.swift`
- Create: `Tests/TrackerCoreTests/SessionStoreTests.swift`
- Create: `Tests/TrackerCoreTests/DayGroupingTests.swift`

**Interfaces:**
- Consumes: `SessionRecording` (Task 2).
- Produces:
  - `WorkSegment` (plain `final class`, `id: UUID`, `startedAt: Date`, `endedAt: Date?`, `createdAt: Date`, init with defaults).
  - `SessionStore: SessionRecording` with `init()`, `startSegment(at:)`, `endSegment(at:)`, `openSegment() -> WorkSegment?`, `allSegments() -> [WorkSegment]`.
  - `DaySummary` (`day: Date`, `total: TimeInterval`, `Equatable`) and `DayGrouping.summarize(_:calendar:now:) -> [DaySummary]`.

- [ ] **Step 1: Write the failing tests**

`Tests/TrackerCoreTests/DayGroupingTests.swift`:
```swift
import Foundation
import TrackerCore

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func testSummarizeGroupsByDay() {
    let calendar = utcCalendar()
    let day1 = calendar.date(from: DateComponents(year: 2026, month: 8, day: 17))!
    let day2 = calendar.date(from: DateComponents(year: 2026, month: 8, day: 18))!
    let s1 = WorkSegment(startedAt: day1.addingTimeInterval(3600), endedAt: day1.addingTimeInterval(7200))
    let s2 = WorkSegment(startedAt: day1.addingTimeInterval(10800), endedAt: day1.addingTimeInterval(12600))
    let s3 = WorkSegment(startedAt: day2.addingTimeInterval(3600), endedAt: day2.addingTimeInterval(5400))

    let summaries = DayGrouping.summarize([s1, s2, s3], calendar: calendar)

    expectEqual(summaries.count, 2, "should group into two days")
    expectEqual(summaries[0].total, 5400.0, "day1 total should be 3600 + 1800")
    expectEqual(summaries[1].total, 1800.0, "day2 total should be 1800")
}

private func testOpenSegmentCountsUntilNow() {
    let calendar = utcCalendar()
    let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 18))!
    let open = WorkSegment(startedAt: day.addingTimeInterval(3600))
    let now = day.addingTimeInterval(7200)

    let summaries = DayGrouping.summarize([open], calendar: calendar, now: now)

    expectEqual(summaries.count, 1, "should produce one summary")
    expectEqual(summaries[0].total, 3600.0, "open segment should count until now")
}

func runDayGroupingTests() {
    testSummarizeGroupsByDay()
    testOpenSegmentCountsUntilNow()
}
```

`Tests/TrackerCoreTests/SessionStoreTests.swift`:
```swift
import Foundation
import TrackerCore

private func makeStore() -> SessionStore {
    SessionStore()
}

private func testStartAndEndSegment() {
    let store = makeStore()
    let start = Date(timeIntervalSince1970: 1_000)

    store.startSegment(at: start)
    expectNotNil(store.openSegment(), "openSegment should be non-nil after startSegment")

    store.endSegment(at: start.addingTimeInterval(60))
    expectNil(store.openSegment(), "openSegment should be nil after endSegment")

    let segments = store.allSegments()
    expectEqual(segments.count, 1, "there should be one segment")
    expectEqual(segments.first?.endedAt, start.addingTimeInterval(60) as Date?, "endedAt should match")
}

private func testMultipleSegmentsSortedByStart() {
    let store = makeStore()
    let t1 = Date(timeIntervalSince1970: 2_000)
    let t0 = Date(timeIntervalSince1970: 1_000)

    store.startSegment(at: t0)
    store.endSegment(at: t0.addingTimeInterval(30))

    store.startSegment(at: t1)
    store.endSegment(at: t1.addingTimeInterval(30))

    let segments = store.allSegments()
    expectEqual(segments.count, 2, "there should be two segments")
    expectEqual(segments.first?.startedAt, t0 as Date?, "segments should be sorted by startedAt ascending")
}

func runStoreTests() {
    testStartAndEndSegment()
    testMultipleSegmentsSortedByStart()
}
```

Then register both suites in `Tests/TrackerCoreTests/TestMain.swift` — change `main()`:
```swift
        runVersionTests()
        runEngineTests()

        print("== \(testCount) assertions, \(testFailures) failures ==")
```
to:
```swift
        runVersionTests()
        runEngineTests()
        runStoreTests()
        runDayGroupingTests()

        print("== \(testCount) assertions, \(testFailures) failures ==")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift run TrackerCoreTests`
Expected: FAIL at build — `cannot find 'WorkSegment' in scope` (the test files reference the not-yet-written types).

- [ ] **Step 3: Implement `WorkSegment.swift`**

```swift
import Foundation

public final class WorkSegment {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 4: Implement `SessionStore.swift`**

```swift
import Foundation

public final class SessionStore: SessionRecording {
    private var segments: [WorkSegment] = []
    private var currentSegment: WorkSegment?

    public init() {
        self.currentSegment = findOpenSegment()
    }

    public func startSegment(at date: Date) {
        let segment = WorkSegment(startedAt: date, createdAt: date)
        segments.append(segment)
        currentSegment = segment
    }

    public func endSegment(at date: Date) {
        guard let segment = currentSegment else { return }
        segment.endedAt = date
        currentSegment = nil
    }

    public func openSegment() -> WorkSegment? {
        currentSegment
    }

    public func allSegments() -> [WorkSegment] {
        segments.sorted { $0.startedAt < $1.startedAt }
    }

    private func findOpenSegment() -> WorkSegment? {
        segments.last(where: { $0.endedAt == nil })
    }
}
```

- [ ] **Step 5: Implement `DaySummary.swift`**

```swift
import Foundation

public struct DaySummary: Equatable {
    public let day: Date
    public let total: TimeInterval

    public init(day: Date, total: TimeInterval) {
        self.day = day
        self.total = total
    }
}

public enum DayGrouping {
    public static func summarize(
        _ segments: [WorkSegment],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [DaySummary] {
        var byDay: [Date: TimeInterval] = [:]

        for segment in segments {
            let start = calendar.startOfDay(for: segment.startedAt)
            let duration = (segment.endedAt ?? now).timeIntervalSince(segment.startedAt)
            byDay[start, default: 0] += max(0, duration)
        }

        return byDay
            .map { DaySummary(day: $0.key, total: $0.value) }
            .sorted { $0.day < $1.day }
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift run TrackerCoreTests`
Expected: `ALL TESTS PASSED` (version + engine + store + grouping suites).

- [ ] **Step 7: Commit**

```bash
git add Sources/TrackerCore Tests/TrackerCoreTests
git commit -m "feat: WorkSegment, SessionStore, and day grouping (in-memory)"
```

---

### Task 5: PresenceDetector (AVFoundation + Vision)

**Files:**
- Create: `Sources/TrackerApp/PresenceDetector.swift`

**Interfaces:**
- Consumes: `PresenceDetecting`, `PresenceResult` (Task 2).
- Produces: `PresenceDetector: PresenceDetecting` (internal to app target) used by `TrackerModel` (Task 6).

- [ ] **Step 1: Implement `PresenceDetector.swift`**

```swift
import AVFoundation
import Vision
import TrackerCore

final class FrameGrabber: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let semaphore = DispatchSemaphore(value: 0)
    private(set) var pixelBuffer: CVPixelBuffer?

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard pixelBuffer == nil else { return }
        if let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            pixelBuffer = buffer
            semaphore.signal()
        }
    }
}

final class PresenceDetector: PresenceDetecting {
    func detectPresence() -> PresenceResult {
        let session = AVCaptureSession()
        session.sessionPreset = .low

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return .cameraUnavailable }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        output.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(output) else { return .cameraUnavailable }
        session.addOutput(output)

        let grabber = FrameGrabber()
        let queue = DispatchQueue(label: "com.presencetracker.capture")
        output.setSampleBufferDelegate(grabber, queue: queue)

        session.startRunning()
        let gotFrame = grabber.semaphore.wait(timeout: .now() + 3) == .success
        session.stopRunning()
        output.setSampleBufferDelegate(nil, queue: nil)

        guard gotFrame, let buffer = grabber.pixelBuffer else {
            return .cameraUnavailable
        }

        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, options: [:])
        try? handler.perform([request])

        let hasFace = (request.results?.isEmpty == false)
        return hasFace ? .present : .absent
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: compiles. (Detector is hardware-bound; verified manually when the app runs.)

- [ ] **Step 3: Commit**

```bash
git add Sources/TrackerApp/PresenceDetector.swift
git commit -m "feat: AVFoundation + Vision presence detector"
```

---

### Task 6: TrackerModel, menu bar UI, and settings popover

**Files:**
- Modify: `Sources/TrackerApp/TrackerApp.swift` (replace print stub with real app)
- Create: `Sources/TrackerApp/TrackerModel.swift`
- Create: `Sources/TrackerApp/PopoverView.swift`
- Create: `Sources/TrackerApp/SettingsView.swift`

**Interfaces:**
- Consumes: `WorkSessionEngine`, `SessionStore`, `DayGrouping`, `DaySummary`, `EngineState`, `Settings`, `PresenceDetector`, `WorkSegment` (Tasks 2–5).
- Produces: runnable menu-bar app.

- [ ] **Step 1: Write `TrackerModel.swift`**

```swift
import SwiftUI
import SwiftData
import TrackerCore

@MainActor
final class TrackerModel: ObservableObject {
    @Published var state: EngineState = .idle
    @Published var todayElapsed: TimeInterval = 0
    @Published var history: [DaySummary] = []
    @Published var cameraUnavailable = false

    private let store: SessionStore
    private var engine: WorkSessionEngine
    private var uiTimer: Timer?

    var formattedToday: String { Self.format(todayElapsed) }

    init() {
        store = SessionStore()

        engine = WorkSessionEngine(
            detector: PresenceDetector(),
            recorder: store,
            sampleInterval: Self.load(Settings.sampleIntervalKey, Settings.defaultSampleInterval),
            gracePeriod: Self.load(Settings.gracePeriodKey, Settings.defaultGracePeriod),
            cameraUnavailableCountsAsPresent: Self.load(
                Settings.cameraUnavailableCountsAsPresentKey,
                Settings.defaultCameraUnavailableCountsAsPresent
            )
        )
        engine.onStateChange = { [weak self] newState in
            Task { @MainActor in
                self?.state = newState
                self?.refresh()
            }
        }
    }

    func start() {
        refresh()
        engine.start()

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        uiTimer = timer

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.shutdown()
        }
    }

    func refresh() {
        let now = Date()
        let summaries = DayGrouping.summarize(store.allSegments(), now: now)
        history = Array(summaries.reversed())
        let today = Calendar.current.startOfDay(for: now)
        todayElapsed = summaries.first(where: { $0.day == today })?.total ?? 0
    }

    private func shutdown() {
        uiTimer?.invalidate()
        engine.stop()
    }

    private static func load<T>(_ key: String, _ fallback: T) -> T {
        UserDefaults.standard.object(forKey: key) as? T ?? fallback
    }

    static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
```

- [ ] **Step 2: Write `PopoverView.swift`**

```swift
import SwiftUI
import TrackerCore

struct PopoverView: View {
    @EnvironmentObject private var model: TrackerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(model.formattedToday)
                        .font(.title2)
                        .monospacedDigit()
                }
                Spacer()
                statusBadge
            }

            Divider()

            if model.history.isEmpty {
                Text("No sessions yet")
                    .foregroundStyle(.secondary)
            } else {
                List(Array(model.history.prefix(30)), id: \.day) { day in
                    HStack {
                        Text(day.day, format: .dateTime.day().month().weekday(.abbreviated))
                        Spacer()
                        Text(TrackerModel.format(day.total))
                            .monospacedDigit()
                    }
                }
            }

            Divider()

            HStack {
                SettingsView()
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding()
        .frame(width: 280)
    }

    private var statusBadge: some View {
        switch model.state {
        case .idle:
            return Label("Away", systemImage: "person.slash")
        case .active:
            return Label("Working", systemImage: "person.fill")
        case .grace:
            return Label("Away (grace)", systemImage: "person.fill.questionmark")
        }
    }
}
```

- [ ] **Step 3: Write `SettingsView.swift`**

```swift
import SwiftUI
import TrackerCore

struct SettingsView: View {
    @AppStorage(Settings.sampleIntervalKey) private var sampleInterval = Settings.defaultSampleInterval
    @AppStorage(Settings.gracePeriodKey) private var gracePeriod = Settings.defaultGracePeriod
    @AppStorage(Settings.cameraUnavailableCountsAsPresentKey) private var cameraPolicy = Settings.defaultCameraUnavailableCountsAsPresent

    var body: some View {
        Form {
            Picker("Check every", selection: $sampleInterval) {
                Text("3 seconds").tag(3.0)
                Text("5 seconds").tag(5.0)
                Text("10 seconds").tag(10.0)
                Text("30 seconds").tag(30.0)
            }
            Picker("Grace period", selection: $gracePeriod) {
                Text("30 seconds").tag(30.0)
                Text("1 minute").tag(60.0)
                Text("2 minutes").tag(120.0)
                Text("5 minutes").tag(300.0)
            }
            Toggle("Camera busy counts as present", isOn: $cameraPolicy)
            Text("Changes apply after restarting the app.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .formStyle(.grouped)
    }
}
```

- [ ] **Step 4: Replace `TrackerApp.swift` with the app entry point**

```swift
import SwiftUI
import TrackerCore

@main
struct PresenceTrackerApp: App {
    @StateObject private var model: TrackerModel

    init() {
        let model = TrackerModel()
        _model = StateObject(wrappedValue: model)
        NSApplication.shared.setActivationPolicy(.accessory)
        model.start()
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(model)
        } label: {
            Image(systemName: iconName)
            Text(model.formattedToday)
        }
        .menuBarExtraStyle(.window)
    }

    private var iconName: String {
        switch model.state {
        case .idle: return "person.slash"
        case .active: return "person.fill"
        case .grace: return "person.fill.questionmark"
        }
    }
}
```

- [ ] **Step 5: Build**

Run: `swift build`
Expected: compiles.

- [ ] **Step 6: Manual verification**

Run: `make run`
Expected: a menu-bar item appears (person icon + timer). Grant camera permission when prompted; sit in front of the camera and confirm the timer runs and state shows "Working". Step away >2 min and confirm it flips to "Away" and stops. Reopen the popover to confirm history entries appear.

- [ ] **Step 7: Commit**

```bash
git add Sources/TrackerApp
git commit -m "feat: menu bar UI, tracker model, and settings"
```

---

### Task 7: README and final verification

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write `README.md`**

```markdown
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
```

- [ ] **Step 2: Full verification**

Run: `make test` then `make bundle`
Expected: `ALL TESTS PASSED`; `build/PresenceTracker.app` is produced and code-signed ad-hoc.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add README"
```

---

## Spec Coverage Checklist

- PresenceDetector (on-demand sampling) → Task 5
- WorkSessionEngine state machine (`Active`/`Grace`/`Idle`) → Task 3
- SessionStore + day grouping → Task 4
- Settings defaults (sample 5s, grace 120s, camera-busy=present) → Tasks 2, 6
- Menu bar timer + popover history → Task 6
- `NSCameraUsageDescription` permission → Task 1 (Info.plist)
- Camera-busy / lid-closed → engine policy (Task 3) + detector returns `.cameraUnavailable` (Task 5)
- Error handling (detector errors non-crashing, save failures logged) → Tasks 4, 5
- Testing (engine + store + grouping unit tests) → Tasks 3, 4
