import Foundation

public enum HistoryGrouping: Sendable {
    case day, month, year

    public var calendarComponent: Calendar.Component {
        switch self {
        case .day: .day
        case .month: .month
        case .year: .year
        }
    }

    var axisLabelFormat: Date.FormatStyle {
        switch self {
        case .day: .dateTime.day().month(.abbreviated)
        case .month: .dateTime.month(.abbreviated).year()
        case .year: .dateTime.year()
        }
    }
}

public struct HistorySeries: Sendable {
    public let points: [HistoryPoint]
    public let grouping: HistoryGrouping

    /// Label saved buckets in the All chart. Automatic date ticks can label
    /// the same bar several times when the series contains just one bucket.
    var axisDates: [Date] {
        let maximumLabels = 5
        guard points.count > maximumLabels else { return points.map(\.date) }
        let last = points.count - 1
        return (0..<maximumLabels).map { index in
            points[index * last / (maximumLabels - 1)].date
        }
    }
}

extension CounterArchive {
    /// Every saved day, including dates outside a recent chart window or ahead
    /// of today's local date after travel. No history expires when it gets older.
    public func recordedHistory(timeZone: TimeZone, latest limit: Int? = nil) -> [HistoryPoint] {
        let sorted = days.sorted { $0.day < $1.day }
        let visible = sorted.suffix(limit.map { max(0, $0) } ?? sorted.count)
        return visible.compactMap { day in
            guard let date = DayKey.date(day.day, in: timeZone)
                ?? DayKey.date(day.day, in: TimeZone(secondsFromGMT: 0)!) else { return nil }
            return HistoryPoint(day: day.day, date: date, automatic: day.automatic, manual: day.manual)
        }
    }

    /// Recent windows include zero days. All history uses saved buckets and
    /// groups long spans so decades of records don't create tens of thousands
    /// of chart marks. The daily breakdown remains available separately.
    public func historySeries(last count: Int?, now: Date, timeZone: TimeZone) -> HistorySeries {
        if let count {
            return HistorySeries(points: history(last: count, now: now, timeZone: timeZone), grouping: .day)
        }
        let today = DayKey.make(now, in: timeZone)
        let first = min(startedOn, days.map(\.day).min() ?? today)
        let last = max(today, days.map(\.day).max() ?? today)
        let span = DayKey.inclusiveDays(from: first, through: last)
        let grouping: HistoryGrouping = span <= 90 ? .day : (span <= 3_660 ? .month : .year)
        var buckets: [String: DayCount] = [:]
        for day in days {
            let key: String
            switch grouping {
            case .day: key = day.day
            case .month: key = String(day.day.prefix(7)) + "-01"
            case .year: key = String(day.day.prefix(4)) + "-01-01"
            }
            var bucket = buckets[key] ?? DayCount(day: key)
            bucket.automatic += day.automatic
            bucket.manual += day.manual
            buckets[key] = bucket
        }
        let points = buckets.values.sorted { $0.day < $1.day }.compactMap { day -> HistoryPoint? in
            guard let date = DayKey.date(day.day, in: timeZone)
                ?? DayKey.date(day.day, in: TimeZone(secondsFromGMT: 0)!) else { return nil }
            return HistoryPoint(day: day.day, date: date, automatic: day.automatic, manual: day.manual)
        }
        return HistorySeries(points: points, grouping: grouping)
    }
}
