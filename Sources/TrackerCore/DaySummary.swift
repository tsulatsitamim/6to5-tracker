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
