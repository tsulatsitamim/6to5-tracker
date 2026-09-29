import Foundation
import TrackerCore

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func testSummarizeGroupsByDay() {
    let calendar = utcCalendar()
    let day1 = calendar.date(from: DateComponents(year: 2026, month: 8, day: 17))!
    let day2 = calendar.date(from: DateComponents(year: 2026, month: 8, day: 18))!
    let s1 = WorkSegment(startedAt: day1.addingTimeInterval(3600), endedAt: day1.addingTimeInterval(7200))
    let s2 = WorkSegment(startedAt: day1.addingTimeInterval(10800), endedAt: day1.addingTimeInterval(12600))
    let s3 = WorkSegment(startedAt: day2.addingTimeInterval(3600), endedAt: day2.addingTimeInterval(5400))

    let summaries = DayGrouping.summarize([s1, s2, s3], calendar: calendar)

    expectEqual(summaries.count, 2, "should group into two days")
    expectEqual(summaries[0].total, 5400.0, "day1 total should be 3600 + 1800")
    expectEqual(summaries[1].total, 1800.0, "day2 total should be 1800")
}

private func testOpenSegmentCountsUntilNow() {
    let calendar = utcCalendar()
    let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 18))!
    let open = WorkSegment(startedAt: day.addingTimeInterval(3600))
    let now = day.addingTimeInterval(7200)

    let summaries = DayGrouping.summarize([open], calendar: calendar, now: now)

    expectEqual(summaries.count, 1, "should produce one summary")
    expectEqual(summaries[0].total, 3600.0, "open segment should count until now")
}

private func testOverlappingSegmentsCountUnionOnly() {
    let calendar = utcCalendar()
    let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 18))!
    // 09:00–10:00 and 09:30–11:00 → union is 09:00–11:00 = 2h
    let a = WorkSegment(
        startedAt: day.addingTimeInterval(9 * 3600),
        endedAt: day.addingTimeInterval(10 * 3600)
    )
    let b = WorkSegment(
        startedAt: day.addingTimeInterval(9.5 * 3600),
        endedAt: day.addingTimeInterval(11 * 3600)
    )

    let summaries = DayGrouping.summarize([a, b], calendar: calendar)

    expectEqual(summaries.count, 1, "overlapping segments stay on one day")
    expectEqual(summaries[0].total, 2 * 3600.0, "overlap must not double-count duration")
}

private func testNestedSegmentDoesNotAddDuration() {
    let calendar = utcCalendar()
    let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 18))!
    let outer = WorkSegment(
        startedAt: day.addingTimeInterval(9 * 3600),
        endedAt: day.addingTimeInterval(12 * 3600)
    )
    let inner = WorkSegment(
        startedAt: day.addingTimeInterval(10 * 3600),
        endedAt: day.addingTimeInterval(11 * 3600)
    )

    let summaries = DayGrouping.summarize([outer, inner], calendar: calendar)

    expectEqual(summaries[0].total, 3 * 3600.0, "nested segment must not add duration")
}

private func testAdjacentSegmentsDoNotDoubleCount() {
    let calendar = utcCalendar()
    let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 18))!
    let a = WorkSegment(
        startedAt: day.addingTimeInterval(9 * 3600),
        endedAt: day.addingTimeInterval(10 * 3600)
    )
    let b = WorkSegment(
        startedAt: day.addingTimeInterval(10 * 3600),
        endedAt: day.addingTimeInterval(11 * 3600)
    )

    let summaries = DayGrouping.summarize([a, b], calendar: calendar)

    expectEqual(summaries[0].total, 2 * 3600.0, "adjacent segments should total 2h")
}

private func testSeparateClustersSumIndependently() {
    let calendar = utcCalendar()
    let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 18))!
    // Cluster 1: 09:00–10:00 ∪ 09:30–10:30 = 1.5h
    let a = WorkSegment(
        startedAt: day.addingTimeInterval(9 * 3600),
        endedAt: day.addingTimeInterval(10 * 3600)
    )
    let b = WorkSegment(
        startedAt: day.addingTimeInterval(9.5 * 3600),
        endedAt: day.addingTimeInterval(10.5 * 3600)
    )
    // Cluster 2: 14:00–15:00 = 1h
    let c = WorkSegment(
        startedAt: day.addingTimeInterval(14 * 3600),
        endedAt: day.addingTimeInterval(15 * 3600)
    )

    let summaries = DayGrouping.summarize([a, b, c], calendar: calendar)

    expectEqual(summaries[0].total, 2.5 * 3600.0, "separate clusters sum as unions")
}

func runDayGroupingTests() {
    testSummarizeGroupsByDay()
    testOpenSegmentCountsUntilNow()
    testOverlappingSegmentsCountUnionOnly()
    testNestedSegmentDoesNotAddDuration()
    testAdjacentSegmentsDoNotDoubleCount()
    testSeparateClustersSumIndependently()
}
