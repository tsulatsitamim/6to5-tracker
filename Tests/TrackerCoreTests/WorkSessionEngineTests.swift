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
