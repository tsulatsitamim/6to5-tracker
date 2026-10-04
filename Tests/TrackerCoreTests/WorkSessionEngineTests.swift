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

private func testKeepWorkingStartsSegmentFromIdle() {
    let r = FakeRecorder()
    let engine = makeEngine(recorder: r)

    engine.setMode(.keepWorking, at: engineBaseDate)

    expectEqual(engine.mode, .keepWorking, "mode should be keepWorking")
    expectEqual(engine.state, .active, "keepWorking should activate the engine")
    expectEqual(r.started.count, 1, "keepWorking should start a segment")
    expectEqual(r.ended.count, 0, "no segment should end")
}

private func testKeepWorkingIgnoresAbsence() {
    let r = FakeRecorder()
    let engine = makeEngine(recorder: r)

    engine.setMode(.keepWorking, at: engineBaseDate)
    engine.handle(result: .absent, at: engineBaseDate.addingTimeInterval(5))
    engine.handle(result: .absent, at: engineBaseDate.addingTimeInterval(500))

    expectEqual(engine.state, .active, "absence must be ignored while keepWorking")
    expectEqual(r.ended.count, 0, "segment must stay open while keepWorking")
}

private func testKeepWorkingDuringGraceReactivates() {
    let r = FakeRecorder()
    let engine = makeEngine(recorder: r)

    engine.handle(result: .present, at: engineBaseDate)
    engine.handle(result: .absent, at: engineBaseDate.addingTimeInterval(5))
    expectEqual(engine.state, .grace, "absence should reach grace first")

    engine.setMode(.keepWorking, at: engineBaseDate.addingTimeInterval(10))

    expectEqual(engine.state, .active, "keepWorking should pull state out of grace")
    expectEqual(r.started.count, 1, "no new segment should start")
    expectEqual(r.ended.count, 0, "segment should remain open")
}

private func testKeepIdleEndsSegmentImmediately() {
    let r = FakeRecorder()
    let engine = makeEngine(recorder: r)

    engine.handle(result: .present, at: engineBaseDate)
    engine.setMode(.keepIdle, at: engineBaseDate.addingTimeInterval(5))

    expectEqual(engine.mode, .keepIdle, "mode should be keepIdle")
    expectEqual(engine.state, .idle, "keepIdle should idle the engine without grace")
    expectEqual(r.ended.count, 1, "keepIdle should close the open segment at once")
    expectEqual(r.ended.first, engineBaseDate.addingTimeInterval(5) as Date?, "endedAt should be the switch time")
}

private func testKeepIdleSuppressesCameraPresence() {
    let r = FakeRecorder()
    let engine = makeEngine(recorder: r)

    engine.setMode(.keepIdle, at: engineBaseDate)
    engine.handle(result: .present, at: engineBaseDate.addingTimeInterval(5))

    expectEqual(engine.state, .idle, "camera presence must be ignored while keepIdle")
    expectEqual(r.started.count, 0, "no segment should start while keepIdle")
}

private func testReturningToAutomaticReevaluatesCamera() {
    let r = FakeRecorder()
    let engine = makeEngine(recorder: r)

    engine.handle(result: .present, at: engineBaseDate)
    engine.setMode(.keepIdle, at: engineBaseDate.addingTimeInterval(5))
    engine.setMode(.automatic, at: engineBaseDate.addingTimeInterval(10))

    expectEqual(engine.mode, .automatic, "mode should be automatic")
    expectEqual(engine.state, .idle, "returning to automatic should not force a state by itself")

    engine.handle(result: .present, at: engineBaseDate.addingTimeInterval(15))

    expectEqual(engine.state, .active, "camera should drive state again in automatic")
    expectEqual(r.started.count, 2, "a fresh segment should start on camera presence")
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
    testKeepWorkingStartsSegmentFromIdle()
    testKeepWorkingIgnoresAbsence()
    testKeepWorkingDuringGraceReactivates()
    testKeepIdleEndsSegmentImmediately()
    testKeepIdleSuppressesCameraPresence()
    testReturningToAutomaticReevaluatesCamera()
}
