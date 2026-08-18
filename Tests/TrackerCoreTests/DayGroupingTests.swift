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

func runDayGroupingTests() {
    testSummarizeGroupsByDay()
    testOpenSegmentCountsUntilNow()
}
