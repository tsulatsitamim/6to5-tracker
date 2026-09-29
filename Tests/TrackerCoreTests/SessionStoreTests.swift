import Foundation
import TrackerCore

private func makeStore() -> SessionStore {
    SessionStore(fileURL: tempStoreURL())
}

private func tempStoreURL() -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("segments.json")
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

private func testPersistenceRoundTrip() {
    let url = tempStoreURL()

    let store = SessionStore(fileURL: url)
    let start = Date(timeIntervalSince1970: 1_000)
    store.startSegment(at: start)
    store.endSegment(at: start.addingTimeInterval(60))

    let reloaded = SessionStore(fileURL: url)
    let segments = reloaded.allSegments()
    expectEqual(segments.count, 1, "reloaded store should have one persisted segment")
    expectEqual(segments.first?.startedAt, start as Date?, "reloaded startedAt should match")
    expectEqual(segments.first?.endedAt, start.addingTimeInterval(60) as Date?, "reloaded endedAt should match")
}

private func testOpenSegmentFinalizedOnReload() {
    let url = tempStoreURL()

    let store = SessionStore(fileURL: url)
    store.startSegment(at: Date(timeIntervalSince1970: 2_000))

    let reloaded = SessionStore(fileURL: url)
    let segments = reloaded.allSegments()
    expectEqual(segments.count, 1, "reloaded store should still have the segment")
    expectNotNil(segments.first?.endedAt, "open segment should be finalized on reload, not left open")
}

private func testAddManualSegment() {
    let store = makeStore()
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let duration: TimeInterval = 45 * 60

    let added = store.addManualSegment(startedAt: start, duration: duration)

    expectNotNil(added, "addManualSegment should return the new segment")
    expectEqual(store.allSegments().count, 1, "store should contain the manual segment")
    expectEqual(added?.startedAt, start as Date?, "startedAt should match")
    expectEqual(added?.endedAt, start.addingTimeInterval(duration) as Date?, "endedAt should be start + duration")
    expectNil(store.openSegment(), "manual segment must not become the open segment")
}

private func testAddManualSegmentRejectsNonPositiveDuration() {
    let store = makeStore()
    let start = Date(timeIntervalSince1970: 1_700_000_000)

    expectNil(store.addManualSegment(startedAt: start, duration: 0), "zero duration should be rejected")
    expectNil(store.addManualSegment(startedAt: start, duration: -60), "negative duration should be rejected")
    expectEqual(store.allSegments().count, 0, "rejected entries must not be stored")
}

private func testAddManualSegmentPersists() {
    let url = tempStoreURL()
    let store = SessionStore(fileURL: url)
    let start = Date(timeIntervalSince1970: 1_700_000_000)

    _ = store.addManualSegment(startedAt: start, duration: 30 * 60)

    let reloaded = SessionStore(fileURL: url)
    let segments = reloaded.allSegments()
    expectEqual(segments.count, 1, "manual segment should persist")
    expectEqual(segments.first?.endedAt, start.addingTimeInterval(30 * 60) as Date?, "persisted endedAt should match")
}

func runStoreTests() {
    testStartAndEndSegment()
    testMultipleSegmentsSortedByStart()
    testPersistenceRoundTrip()
    testOpenSegmentFinalizedOnReload()
    testAddManualSegment()
    testAddManualSegmentRejectsNonPositiveDuration()
    testAddManualSegmentPersists()
}
