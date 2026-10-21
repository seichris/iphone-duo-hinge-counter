import Foundation
import Testing
@testable import FoldCounterCore

private let historyUTC = TimeZone(secondsFromGMT: 0)!
private func moment(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
private func localCalendar(_ zone: String = "UTC", firstWeekday: Int = 2) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    calendar.firstWeekday = firstWeekday
    calendar.minimumDaysInFirstWeek = 4
    return calendar
}
private func historyArchive(_ days: [DayCount], startedOn: String = "2026-01-01") -> CounterArchive {
    var archive = CounterArchive(now: moment(startedOn + "T12:00:00Z"), timeZone: historyUTC)
    archive.days = days
    return archive
}

@Test func decadesOfHistorySurviveSavingAndRemainVisible() throws {
    let original = historyArchive([
        DayCount(day: "2001-03-02", automatic: 7),
        DayCount(day: "2024-01-01", manual: 3),
        DayCount(day: "2026-10-21", automatic: 2)
    ], startedOn: "2001-03-02")
    let restored = try ArchiveFile.decode(ArchiveFile.encode(original))
    #expect(restored.recordedHistory(timeZone: historyUTC).map(\.day) == ["2001-03-02", "2024-01-01", "2026-10-21"])
    #expect(restored.csv().contains("2001-03-02,7,0,7"))
    let series = restored.historySeries(last: nil, now: moment("2026-10-21T12:00:00Z"), timeZone: historyUTC)
    #expect(series.grouping == .year)
    #expect(series.points.reduce(0) { $0 + $1.total } == 12)
    #expect(series.points.first?.day == "2001-01-01")
}

@Test func allHistoryGroupsMonthsWithoutLosingAttribution() {
    let archive = historyArchive([
        DayCount(day: "2025-01-01", automatic: 2, manual: 1),
        DayCount(day: "2025-01-31", automatic: 3, manual: 4),
        DayCount(day: "2026-10-21", automatic: 7)
    ], startedOn: "2025-01-01")
    let series = archive.historySeries(last: nil, now: moment("2026-10-21T12:00:00Z"), timeZone: historyUTC)
    #expect(series.grouping == .month)
    #expect(series.points.map(\.day) == ["2025-01-01", "2026-10-01"])
    #expect(series.points.first?.automatic == 5)
    #expect(series.points.first?.manual == 5)
    #expect(archive.recordedHistory(timeZone: historyUTC).count == 3)
}

@Test func shortAllHistoryKeepsDailyDetailAndEmptyArchiveHasNoFakePoints() {
    let now = moment("2026-10-21T12:00:00Z")
    let empty = historyArchive([], startedOn: "2026-10-01")
    #expect(empty.historySeries(last: nil, now: now, timeZone: historyUTC).points.isEmpty)
    let archive = historyArchive([DayCount(day: "2026-10-01", automatic: 3)], startedOn: "2026-10-01")
    let series = archive.historySeries(last: nil, now: now, timeZone: historyUTC)
    #expect(series.grouping == .day)
    #expect(series.points.first?.day == "2026-10-01")
    #expect(archive.historySeries(last: 7, now: now, timeZone: historyUTC).points.count == 7)
}

@Test func travelToZoneWithSkippedDateDoesNotHideSavedHistory() {
    let archive = historyArchive([DayCount(day: "2011-12-30", automatic: 4)], startedOn: "2011-12-30")
    let apia = TimeZone(identifier: "Pacific/Apia")!
    #expect(archive.recordedHistory(timeZone: apia).first?.day == "2011-12-30")
    #expect(archive.recordedHistory(timeZone: apia).first?.automatic == 4)
}

@Test func periodsKeepManualAndObservedSeparateAndExcludeFutureDates() {
    let archive = historyArchive([
        DayCount(day: "2001-01-01", automatic: 11),
        DayCount(day: "2026-09-30", automatic: 13),
        DayCount(day: "2026-10-01", automatic: 2),
        DayCount(day: "2026-10-18", automatic: 3),
        DayCount(day: "2026-10-19", automatic: 5),
        DayCount(day: "2026-10-21", automatic: 7, manual: 1),
        DayCount(day: "2026-10-22", automatic: 17)
    ], startedOn: "2001-01-01")
    let now = moment("2026-10-21T12:00:00Z")
    let calendar = localCalendar()
    #expect(archive.count(for: .today, now: now, calendar: calendar) == PeriodCount(automatic: 7, manual: 1))
    #expect(archive.count(for: .week, now: now, calendar: calendar) == PeriodCount(automatic: 12, manual: 1))
    #expect(archive.count(for: .month, now: now, calendar: calendar) == PeriodCount(automatic: 17, manual: 1))
    #expect(archive.count(for: .allTime, now: now, calendar: calendar) == PeriodCount(automatic: 58, manual: 1))
}

@Test func weekHonorsSundayOrMondayPreferenceAcrossYearBoundary() {
    let archive = historyArchive([
        DayCount(day: "2025-12-28", automatic: 2), // Sunday
        DayCount(day: "2025-12-29", automatic: 3), // Monday
        DayCount(day: "2026-01-01", automatic: 5)
    ], startedOn: "2025-12-28")
    let now = moment("2026-01-01T12:00:00Z")
    #expect(archive.count(for: .week, now: now, calendar: localCalendar(firstWeekday: 1)).total == 10)
    #expect(archive.count(for: .week, now: now, calendar: localCalendar(firstWeekday: 2)).total == 8)
    #expect(archive.count(for: .month, now: now, calendar: localCalendar()).total == 5)
}

@Test func leapDayAndMonthRolloverUseCalendarDates() {
    let archive = historyArchive([
        DayCount(day: "2024-01-31", automatic: 2),
        DayCount(day: "2024-02-01", automatic: 3),
        DayCount(day: "2024-02-29", automatic: 5)
    ], startedOn: "2024-01-31")
    let february = moment("2024-02-29T23:59:59Z")
    let march = moment("2024-03-01T00:00:00Z")
    #expect(archive.count(for: .month, now: february, calendar: localCalendar()).total == 8)
    #expect(archive.count(for: .month, now: march, calendar: localCalendar()).total == 0)
    #expect(archive.count(for: .allTime, now: march, calendar: localCalendar()).total == 10)
}

@Test func timeZoneTravelKeepsOriginalBucketsAndUsesLocalToday() {
    let archive = historyArchive([DayCount(day: "2026-10-21", automatic: 2)])
    let now = moment("2026-10-22T02:00:00Z")
    #expect(archive.count(for: .today, now: now, calendar: localCalendar("America/New_York")).total == 2)
    #expect(archive.count(for: .today, now: now, calendar: localCalendar()).total == 0)
    #expect(archive.count(for: .allTime, now: now, calendar: localCalendar("Pacific/Auckland")).total == 2)
    #expect(archive.days.first?.day == "2026-10-21")
}

@Test(arguments: ["2026-03-07T17:00:00Z", "2026-10-31T16:00:00Z"])
func snapshotMidnightsRemainDistinctAcrossDST(start: String) {
    let calendar = localCalendar("America/New_York")
    let now = moment(start)
    let dates = CounterSnapshotTimeline.dates(now: now, calendar: calendar)
    #expect(dates.count == 36)
    #expect(dates.first == now)
    #expect(Set(dates.map { DayKey.make($0, in: calendar.timeZone) }).count == 36)
    #expect(dates.dropFirst().allSatisfy { calendar.component(.hour, from: $0) == 0 })
    let transitionLength = dates[2].timeIntervalSince(dates[1])
    #expect(transitionLength == (start.contains("03-07") ? 23 : 25) * 3_600)
}

@Test func sameSavedSnapshotResetsDayWeekAndMonthAtTheirBoundaries() {
    let archive = historyArchive([DayCount(day: "2026-10-31", automatic: 9, manual: 1)], startedOn: "2026-10-31")
    let calendar = localCalendar(firstWeekday: 1)
    let dates = CounterSnapshotTimeline.dates(now: moment("2026-10-31T23:59:00Z"), calendar: calendar)
    #expect(archive.count(for: .today, now: dates[0], calendar: calendar).total == 10)
    for period in [CounterPeriod.today, .week, .month] {
        #expect(archive.count(for: period, now: dates[1], calendar: calendar).total == 0)
    }
    #expect(archive.count(for: .allTime, now: dates[35], calendar: calendar).total == 10)
}

@Test func nonGregorianDeviceCalendarStillMatchesGregorianArchiveKeys() {
    var calendar = Calendar(identifier: .hebrew)
    calendar.timeZone = historyUTC
    let archive = historyArchive([DayCount(day: "2026-10-01", automatic: 3)])
    #expect(archive.count(for: .month, now: moment("2026-10-21T12:00:00Z"), calendar: calendar).total == 3)
}

@Test func historyPagesExposeOlderDatesWithoutChangingTheArchive() {
    let archive = historyArchive([
        DayCount(day: "2026-10-21", automatic: 3),
        DayCount(day: "2001-01-01", automatic: 7),
        DayCount(day: "2024-01-01", manual: 2)
    ], startedOn: "2001-01-01")
    #expect(archive.recordedHistory(timeZone: historyUTC, latest: 2).map(\.day) == ["2024-01-01", "2026-10-21"])
    #expect(archive.recordedHistory(timeZone: historyUTC, latest: 90).map(\.day) == ["2001-01-01", "2024-01-01", "2026-10-21"])
    #expect(archive.days.count == 3)
}
