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
