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
