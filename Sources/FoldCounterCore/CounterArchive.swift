import Foundation

public enum FoldSource: String, Codable, Sendable {
    case hinge, manual
}

public enum CounterDataError: Error, LocalizedError {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let reason): return reason }
    }
}

/// A day is the Gregorian LOCAL date when recorded. Travel never rewrites history.
public enum DayKey {
    public static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    public static func make(_ date: Date, in timeZone: TimeZone) -> String {
        let c = calendar(in: timeZone).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public static func date(_ key: String, in timeZone: TimeZone) -> Date? {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard key.count == 10, parts.count == 3,
              let year = Int(parts[0]), (2000...9999).contains(year),
              let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        let calendar = calendar(in: timeZone)
        // Noon avoids nonexistent local midnights in historical time-zone transitions.
        guard let date = calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: 12)),
              make(date, in: timeZone) == key else { return nil }
        return date
    }

    public static func inclusiveDays(from start: String, through end: String) -> Int {
        let utc = TimeZone(secondsFromGMT: 0)!
        guard let a = date(start, in: utc), let b = date(end, in: utc) else { return 1 }
        return max(1, (calendar(in: utc).dateComponents([.day], from: a, to: b).day ?? 0) + 1)
    }
}

public struct DayCount: Codable, Equatable, Identifiable, Sendable {
    public var day: String
    public var automatic: Int
    public var manual: Int
    public var id: String { day }
    public var total: Int { automatic + manual }

    public init(day: String, automatic: Int = 0, manual: Int = 0) {
        self.day = day
        self.automatic = automatic
        self.manual = manual
    }
}

public struct HistoryPoint: Identifiable, Equatable, Sendable {
    public let day: String
    public let date: Date
    public let automatic: Int
    public let manual: Int
    public var id: String { day }
    public var total: Int { automatic + manual }
}

public struct CounterSummary: Equatable, Sendable {
    public let today: Int
    public let automaticToday: Int
    public let manualToday: Int
    public let total: Int
    public let dailyAverage: Double
    public let daysTracked: Int
}

/// Aggregate daily buckets keep storage bounded by days, not 60 Hz sensor samples.
public struct CounterArchive: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var createdAt: Date
    public var startedOn: String
    public var automaticTrackingEnabled = true
    public var days: [DayCount] = []
    public static let maximumTotal = 1_000_000_000
    public static let maximumDays = 50_000

    public init(now: Date = Date(), timeZone: TimeZone = .current) {
        createdAt = now
        startedOn = DayKey.make(now, in: timeZone)
    }

    @discardableResult
    public func validated() throws -> Self {
        guard schemaVersion == 1 else {
            throw CounterDataError.invalid("Unsupported backup version. Nothing was changed.")
        }
        let utc = TimeZone(secondsFromGMT: 0)!
        guard createdAt.timeIntervalSince1970.isFinite,
              DayKey.date(startedOn, in: utc) != nil,
              days.count <= Self.maximumDays else {
            throw CounterDataError.invalid("Invalid tracking dates or too many daily records.")
        }
        var seen = Set<String>()
        var total = 0
        for day in days {
            guard DayKey.date(day.day, in: utc) != nil, seen.insert(day.day).inserted,
                  day.automatic >= 0, day.manual >= 0,
                  day.automatic <= Self.maximumTotal, day.manual <= Self.maximumTotal else {
                throw CounterDataError.invalid("Invalid or duplicated daily record.")
            }
            total += day.automatic + day.manual
            guard total <= Self.maximumTotal else {
                throw CounterDataError.invalid("The backup exceeds the supported counter limit.")
            }
        }
        return self
    }

    public mutating func record(_ source: FoldSource, at date: Date, timeZone: TimeZone) throws {
        try validated()
        guard date.timeIntervalSince1970.isFinite else {
            throw CounterDataError.invalid("Invalid event date.")
        }
        let key = DayKey.make(date, in: timeZone)
        guard days.reduce(0, { $0 + $1.total }) < Self.maximumTotal else {
            throw CounterDataError.invalid("The counter limit has been reached.")
        }
        if !days.contains(where: { $0.day == key }) {
            days.append(DayCount(day: key))
        }
        let index = days.firstIndex(where: { $0.day == key })!
        switch source {
        case .hinge: days[index].automatic += 1
        case .manual: days[index].manual += 1
        }
        // Allows an explicit manual entry or clock/time-zone correction to precede setup.
        startedOn = min(startedOn, key)
        days.sort { $0.day < $1.day }
        try validated()
    }

    public func summary(now: Date, timeZone: TimeZone) -> CounterSummary {
        let key = DayKey.make(now, in: timeZone)
        let today = days.first { $0.day == key } ?? DayCount(day: key)
        let total = days.reduce(0) { $0 + $1.total }
        let tracked = DayKey.inclusiveDays(from: startedOn, through: key)
        return CounterSummary(today: today.total, automaticToday: today.automatic,
                              manualToday: today.manual, total: total,
                              dailyAverage: Double(total) / Double(tracked), daysTracked: tracked)
    }

    public func history(last count: Int, now: Date, timeZone: TimeZone) -> [HistoryPoint] {
        let calendar = DayKey.calendar(in: timeZone)
        let totals = Dictionary(days.map { ($0.day, $0) }, uniquingKeysWith: { a, _ in a })
        return (0..<min(max(count, 0), 366)).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let key = DayKey.make(date, in: timeZone)
            let day = totals[key] ?? DayCount(day: key)
            return HistoryPoint(day: key, date: date, automatic: day.automatic, manual: day.manual)
        }
    }

    public func csv() -> String {
        // Only validated ISO day keys and integers are exported; no formula-capable user strings.
        "local_date,observed_opens,manual_opens,total\r\n" + days.sorted { $0.day < $1.day }
            .map { "\($0.day),\($0.automatic),\($0.manual),\($0.total)\r\n" }.joined()
    }
}
