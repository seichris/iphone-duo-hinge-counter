import Foundation

public enum CounterPeriod: String, CaseIterable, Sendable {
    case allTime, today, week, month
}

public struct PeriodCount: Equatable, Sendable {
    public let automatic: Int
    public let manual: Int
    public var total: Int { automatic + manual }
}

extension CounterArchive {
    /// Uses the device's time zone and week-start preference, with Gregorian
    /// date keys matching the archive. Past days are never rebucketed on travel.
    /// Current periods stop at today; all-time retains every saved date.
    public func count(for period: CounterPeriod, now: Date, calendar: Calendar) -> PeriodCount {
        var local = DayKey.calendar(in: calendar.timeZone)
        local.firstWeekday = calendar.firstWeekday
        local.minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        let today = DayKey.make(now, in: local.timeZone)
        let start: String?
        switch period {
        case .allTime: start = nil
        case .today: start = today
        case .week:
            start = local.dateInterval(of: .weekOfYear, for: now).map { DayKey.make($0.start, in: local.timeZone) }
        case .month:
            start = local.dateInterval(of: .month, for: now).map { DayKey.make($0.start, in: local.timeZone) }
        }
        var automatic = 0
        var manual = 0
        for day in days {
            guard period == .allTime || (start.map { day.day >= $0 && day.day <= today } ?? false) else { continue }
            automatic += day.automatic
            manual += day.manual
        }
        return PeriodCount(automatic: automatic, manual: manual)
    }
}

public enum CounterSnapshotTimeline {
    /// Schedule local-midnight presentations in advance, including week/month
    /// rollovers, even when iOS delays the requested next-day refresh.
    public static func dates(now: Date, calendar: Calendar) -> [Date] {
        let midnight = calendar.startOfDay(for: now)
        return [now] + (1...35).compactMap { calendar.date(byAdding: .day, value: $0, to: midnight) }
    }
}
