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
        var byDay: [Date: [(start: Date, end: Date)]] = [:]

        for segment in segments {
            let start = segment.startedAt
            let end = segment.endedAt ?? now
            guard end > start else { continue }
            let day = calendar.startOfDay(for: start)
            byDay[day, default: []].append((start, end))
        }

        return byDay
            .map { DaySummary(day: $0.key, total: unionDuration($0.value)) }
            .sorted { $0.day < $1.day }
    }

    /// Sum of covered time after merging overlapping intervals.
    private static func unionDuration(_ intervals: [(start: Date, end: Date)]) -> TimeInterval {
        guard !intervals.isEmpty else { return 0 }
        let sorted = intervals.sorted { $0.start < $1.start }
        var total: TimeInterval = 0
        var mergeStart = sorted[0].start
        var mergeEnd = sorted[0].end

        for interval in sorted.dropFirst() {
            if interval.start <= mergeEnd {
                if interval.end > mergeEnd {
                    mergeEnd = interval.end
                }
            } else {
                total += mergeEnd.timeIntervalSince(mergeStart)
                mergeStart = interval.start
                mergeEnd = interval.end
            }
        }
        total += mergeEnd.timeIntervalSince(mergeStart)
        return max(0, total)
    }
}
