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
