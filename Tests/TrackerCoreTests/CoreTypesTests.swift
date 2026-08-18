import Foundation
import TrackerCore

// Task 2: core types, settings, and protocols.

private final class StubPresenceDetector: PresenceDetecting {
    var result: PresenceResult = .present
    var callCount = 0

    func detectPresence() -> PresenceResult {
        callCount += 1
        return result
    }
}

private final class StubSessionRecorder: SessionRecording {
    var startedAt: [Date] = []
    var endedAt: [Date] = []

    func startSegment(at date: Date) { startedAt.append(date) }
    func endSegment(at date: Date) { endedAt.append(date) }
}

func runCoreTypesTests() {
    // PresenceResult is Equatable with three distinct cases.
    expectEqual(PresenceResult.present, .present, "PresenceResult.present equality")
    expectTrue(PresenceResult.absent != .present, "PresenceResult.absent differs from .present")
    expectTrue(
        PresenceResult.cameraUnavailable != .absent,
        "PresenceResult.cameraUnavailable differs from .absent")

    // PresenceDetecting protocol is callable and returns the detector's result.
    let detector = StubPresenceDetector()
    detector.result = .cameraUnavailable
    expectEqual(detector.detectPresence(), .cameraUnavailable, "detectPresence returns stubbed result")
    expectEqual(detector.callCount, 1, "detectPresence was called once")

    // SessionRecording protocol receives segment boundaries.
    let recorder = StubSessionRecorder()
    let t0 = Date(timeIntervalSince1970: 1000)
    let t1 = Date(timeIntervalSince1970: 1005)
    recorder.startSegment(at: t0)
    recorder.endSegment(at: t1)
    expectEqual(recorder.startedAt, [t0], "startSegment records start date")
    expectEqual(recorder.endedAt, [t1], "endSegment records end date")

    // EngineState is Equatable with three distinct cases.
    expectEqual(EngineState.idle, .idle, "EngineState.idle equality")
    expectTrue(EngineState.active != .idle, "EngineState.active differs from .idle")
    expectTrue(EngineState.grace != .active, "EngineState.grace differs from .active")

    // Settings defaults (verbatim from brief).
    expectEqual(Settings.defaultSampleInterval, 5, "default sample interval is 5s")
    expectEqual(Settings.defaultGracePeriod, 120, "default grace period is 120s")
    expectTrue(
        Settings.defaultCameraUnavailableCountsAsPresent,
        "cameraUnavailableCountsAsPresent defaults to true")

    // Settings UserDefaults keys (verbatim from brief).
    expectEqual(Settings.sampleIntervalKey, "sampleInterval", "sampleInterval key")
    expectEqual(Settings.gracePeriodKey, "gracePeriod", "gracePeriod key")
    expectEqual(
        Settings.cameraUnavailableCountsAsPresentKey,
        "cameraUnavailableCountsAsPresent",
        "cameraUnavailableCountsAsPresent key")
}
