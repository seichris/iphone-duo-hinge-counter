import Foundation
import Testing
@testable import FoldCounterCore

private let utc = TimeZone(secondsFromGMT: 0)!
private let midnight = ISO8601DateFormatter().date(from: "2026-11-07T00:00:00Z")!

@Test(arguments: [false, true])
func versionOneUpgradesWithoutChangingTotalsOrPause(enabled: Bool) throws {
    let legacy = Data("""
        {"schemaVersion":1,"createdAt":"2026-11-05T00:00:00Z","startedOn":"2026-11-05",
         "automaticTrackingEnabled":\(enabled),"days":[{"day":"2026-11-06","automatic":3,"manual":2}]}
        """.utf8)
    let upgraded = try ArchiveFile.decode(legacy)
    #expect(upgraded.schemaVersion == 2)
    #expect(upgraded.countingMethod == .foreground)
    #expect(upgraded.observesHinge == enabled)
    #expect(upgraded.days == [DayCount(day: "2026-11-06", automatic: 3, manual: 2)])
    #expect(try ArchiveFile.decode(ArchiveFile.encode(upgraded)) == upgraded)
}

@Test func damagedShortcutHistoryIsNeverReplacedWithZero() throws {
    let missingCount = Data("""
        {"schemaVersion":2,"createdAt":"2026-11-07T00:00:00Z","startedOn":"2026-11-07",
         "automaticTrackingEnabled":true,"countingMethod":"shortcuts",
         "days":[{"day":"2026-11-07","automatic":2,"manual":1}]}
        """.utf8)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    try missingCount.write(to: url)
    #expect(throws: (any Error).self) { try ArchiveFile(url: url).load(orCreate: CounterArchive()) }
    #expect(try Data(contentsOf: url) == missingCount)
}

@Test func sourceSwitchInvalidatesAnArmedSensorAndAcceptsOnlyOneSource() throws {
    var archive = CounterArchive(now: midnight, timeZone: utc)
    var session = FoldObservationSession()
    let scene = UUID()
    session.setActive(true, scene: scene)
    let original = session.observationID
    _ = session.observe(degrees: 0, timestamp: 0, scene: scene, observationID: original)
    #expect(throws: (any Error).self) { try archive.record(.shortcut, at: midnight, timeZone: utc) }

    archive.countingMethod = .shortcuts
    session.setEnabled(archive.observesHinge)
    #expect(session.subscription(for: scene) == nil)
    let staleOpening = session.observe(degrees: 180, timestamp: 1, scene: scene, observationID: original)
    #expect(!staleOpening)
    #expect(throws: (any Error).self) { try archive.record(.hinge, at: midnight, timeZone: utc) }
    try archive.record(.shortcut, at: midnight, timeZone: utc)
    archive.automaticTrackingEnabled = false
    #expect(throws: (any Error).self) { try archive.record(.shortcut, at: midnight, timeZone: utc) }
    archive.countingMethod = .foreground
    archive.automaticTrackingEnabled = true
    session.setEnabled(archive.observesHinge)
    let initialPose = session.observe(degrees: 180, timestamp: 2, scene: scene, observationID: session.observationID)
    #expect(!initialPose)
    #expect(archive.days == [DayCount(day: "2026-11-07", shortcuts: 1)])
}

@Test func shortcutCountsSurviveColdLaunchAndLocalMidnight() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let file = ArchiveFile(url: url)
    let before = midnight.addingTimeInterval(-1)
    var archive = CounterArchive(now: before, timeZone: utc)
    try archive.record(.hinge, at: before, timeZone: utc)
    try archive.record(.manual, at: before, timeZone: utc)
    archive.countingMethod = .shortcuts
    try archive.record(.shortcut, at: before, timeZone: utc)
    try file.save(archive)
    var relaunched = try file.load(orCreate: CounterArchive())
    try relaunched.record(.shortcut, at: midnight, timeZone: utc)
    let summary = relaunched.summary(now: midnight, timeZone: utc)
    #expect(summary.shortcutsToday == 1)
    #expect(summary.automaticToday == 0 && summary.manualToday == 0)
    #expect(summary.total == 4)
    #expect(relaunched.csv().hasSuffix("2026-11-06,1,1,3,1\r\n2026-11-07,0,0,1,1\r\n"))
    let calendar = DayKey.calendar(in: utc)
    #expect(relaunched.count(for: .today, now: midnight, calendar: calendar).total == 1)
    for period in [CounterPeriod.allTime, .week, .month] {
        #expect(relaunched.count(for: period, now: midnight, calendar: calendar) == PeriodCount(automatic: 1, manual: 1, shortcuts: 2))
    }
    #expect(relaunched.recordedHistory(timeZone: utc).map(\.shortcuts) == [1, 1])
    #expect(relaunched.history(last: 2, now: midnight, timeZone: utc).map(\.shortcuts) == [1, 1])
    relaunched.startedOn = "2005-01-01"
    #expect(relaunched.historySeries(last: nil, now: midnight, timeZone: utc).points.map(\.shortcuts) == [2])
}

@Test(arguments: [-1, Int.max, CounterArchive.maximumTotal])
func invalidOrOverflowingShortcutTotalsFail(shortcuts: Int) {
    var archive = CounterArchive(now: midnight, timeZone: utc)
    archive.days = [DayCount(day: "2026-11-07", automatic: 1, shortcuts: shortcuts)]
    #expect(throws: (any Error).self) { try ArchiveFile.encode(archive) }
}
