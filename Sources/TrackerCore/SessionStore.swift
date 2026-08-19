import Foundation

public final class SessionStore: SessionRecording {
    private static let fileName = "segments.json"

    private var segments: [WorkSegment] = []
    private var currentSegment: WorkSegment?
    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? SessionStore.defaultFileURL()
        load()
    }

    public func startSegment(at date: Date) {
        let segment = WorkSegment(startedAt: date, createdAt: date)
        segments.append(segment)
        currentSegment = segment
        save()
    }

    public func endSegment(at date: Date) {
        guard let segment = currentSegment else { return }
        segment.endedAt = date
        currentSegment = nil
        save()
    }

    public func openSegment() -> WorkSegment? {
        currentSegment
    }

    public func allSegments() -> [WorkSegment] {
        segments.sorted { $0.startedAt < $1.startedAt }
    }

    public static func defaultFileURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let dir = support.appendingPathComponent("PresenceTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([WorkSegment].self, from: data)
        else { return }
        segments = decoded

        // Finalize any segment left open from a previous run so it is not
        // counted as "still working" across an app relaunch.
        let now = Date()
        var changed = false
        for index in segments.indices where segments[index].endedAt == nil {
            segments[index].endedAt = now
            changed = true
        }
        if changed { save() }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(segments) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}