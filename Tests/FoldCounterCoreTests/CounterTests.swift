import Foundation
import Testing
@testable import FoldCounterCore

private let utc = TimeZone(secondsFromGMT: 0)!
private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
private let noon = date("2026-09-14T12:00:00Z")

@Test func initialOpenDoesNotCount() {
    var d = FoldDetector()
    #expect({ !d.observe(degrees: 180, timestamp: 1) }())
    #expect({ !d.observe(degrees: 180, timestamp: 2) }())
}

@Test func closedToOpenCountsOnce() {
    var d = FoldDetector()
    #expect({ !d.observe(degrees: 0, timestamp: 0) }())
    #expect({ !d.observe(degrees: 90, timestamp: 1) }())
    #expect({ d.observe(degrees: 180, timestamp: 2) }())
    #expect({ !d.observe(degrees: 180, timestamp: 3) }())
}

@Test func twoCyclesCountTwice() {
    var d = FoldDetector()
    var total = 0
    for (time, angle) in [0.0, 90, 180, 180, 0, 80, 180].enumerated() {
        if d.observe(degrees: angle, timestamp: Double(time)) { total += 1 }
    }
    #expect(total == 2)
}

@Test func partialFoldsDoNotRearm() {
    var d = FoldDetector()
    _ = d.observe(degrees: 0, timestamp: 0)
    #expect({ d.observe(degrees: 180, timestamp: 1) }())
    _ = d.observe(degrees: 20, timestamp: 2)
    #expect({ !d.observe(degrees: 180, timestamp: 3) }())
}

@Test func angleJitterDoesNotInflateCounts() {
    var d = FoldDetector()
    _ = d.observe(degrees: 0, timestamp: 0)
    #expect({ d.observe(degrees: 171, timestamp: 1) }())
    for index in 2...1000 {
        #expect({ !d.observe(degrees: index.isMultiple(of: 2) ? 169 : 171,
                           timestamp: Double(index)) }())
    }
}

@Test func exactThresholdsAreInclusive() {
    var d = FoldDetector()
    _ = d.observe(degrees: 10, timestamp: 0)
    #expect({ d.observe(degrees: 170, timestamp: 1) }())
}

@Test func tooFastTransitionIsConsumedNotDelayed() {
    var d = FoldDetector()
    _ = d.observe(degrees: 0, timestamp: 0)
    #expect({ !d.observe(degrees: 180, timestamp: 0.1) }())
    #expect({ !d.observe(degrees: 180, timestamp: 2) }())
}

@Test func closedDwellDoesNotPostponeArming() {
    var d = FoldDetector()
    _ = d.observe(degrees: 0, timestamp: 0)
    _ = d.observe(degrees: 5, timestamp: 9.9)
    #expect({ d.observe(degrees: 180, timestamp: 10) }())
}

@Test func missingHingeBreaksContinuity() {
    var d = FoldDetector()
    _ = d.observe(degrees: 0, timestamp: 0)
    _ = d.observe(degrees: nil, timestamp: 1)
    #expect({ !d.observe(degrees: 180, timestamp: 2) }())
}

@Test(arguments: [Double.nan, Double.infinity, -1, 181])
func invalidAnglesBreakContinuity(angle: Double) {
    var d = FoldDetector()
    _ = d.observe(degrees: 0, timestamp: 0)
    _ = d.observe(degrees: angle, timestamp: 1)
    #expect({ !d.observe(degrees: 180, timestamp: 2) }())
}

@Test func backwardsMonotonicTimeIsRejected() {
    var d = FoldDetector()
    _ = d.observe(degrees: 0, timestamp: 10)
    #expect({ !d.observe(degrees: 180, timestamp: 9) }())
    #expect({ !d.observe(degrees: 180, timestamp: 11) }())
}

@Test func equalTimestampCannotRearm() {
    var d = FoldDetector()
    _ = d.observe(degrees: 0, timestamp: 0)
    #expect({ d.observe(degrees: 180, timestamp: 1) }())
    _ = d.observe(degrees: 0, timestamp: 1)
    #expect({ !d.observe(degrees: 180, timestamp: 2) }())
}

@Test func resetPreventsResumeCount() {
    var d = FoldDetector()
    _ = d.observe(degrees: 0, timestamp: 0)
    d.reset()
    #expect({ !d.observe(degrees: 180, timestamp: 2) }())
}

@Test func onlyLeadingSceneCounts() {
    var s = FoldObservationSession()
    let a = UUID(), b = UUID()
    s.setActive(true, scene: a)
    s.setActive(true, scene: b)
    _ = s.observe(degrees: 0, timestamp: 0, scene: a)
    _ = s.observe(degrees: 0, timestamp: 0.1, scene: b)
    #expect({ s.observe(degrees: 180, timestamp: 1, scene: a) }())
    #expect({ !s.observe(degrees: 180, timestamp: 1.1, scene: b) }())
}

@Test func losingOneSceneDoesNotSuspendAnother() {
    var s = FoldObservationSession()
    let a = UUID(), b = UUID()
    s.setActive(true, scene: a)
    s.setActive(true, scene: b)
    s.setActive(false, scene: b)
    #expect(s.leader == a)
    _ = s.observe(degrees: 0, timestamp: 0, scene: a)
    #expect({ s.observe(degrees: 180, timestamp: 1, scene: a) }())
}

@Test func leaderHandoffResetsObservation() {
    var s = FoldObservationSession()
    let a = UUID(), b = UUID()
    s.setActive(true, scene: a)
    s.setActive(true, scene: b)
    _ = s.observe(degrees: 0, timestamp: 0, scene: a)
    s.setActive(false, scene: a)
    #expect(s.leader == b)
    #expect({ !s.observe(degrees: 180, timestamp: 1, scene: b) }())
}

@Test func backgroundAndRelaunchDoNotInventFolds() {
    var s = FoldObservationSession()
    let a = UUID()
    s.setActive(true, scene: a)
    _ = s.observe(degrees: 0, timestamp: 0, scene: a)
    s.setActive(false, scene: a)
    #expect({ !s.observe(degrees: 180, timestamp: 1, scene: a) }())
    s.setActive(true, scene: a)
    #expect({ !s.observe(degrees: 180, timestamp: 2, scene: a) }())
}

@Test func manualAndAutomaticAreSeparated() throws {
    var a = CounterArchive(now: noon, timeZone: utc)
    try a.record(.hinge, at: noon, timeZone: utc)
    try a.record(.manual, at: noon, timeZone: utc)
    let result = a.summary(now: noon, timeZone: utc)
    #expect(result.today == 2)
    #expect(result.automaticToday == 1)
    #expect(result.manualToday == 1)
    #expect(result.total == 2)
}

@Test func averageIncludesZeroDaysAndToday() throws {
    var a = CounterArchive(now: date("2026-09-12T12:00:00Z"), timeZone: utc)
    try a.record(.hinge, at: noon, timeZone: utc)
    #expect(a.summary(now: noon, timeZone: utc).daysTracked == 3)
    #expect(a.summary(now: noon, timeZone: utc).dailyAverage == 1.0 / 3)
}

@Test func midnightResetsTodayNotTotal() throws {
    var a = CounterArchive(now: noon, timeZone: utc)
    try a.record(.hinge, at: noon, timeZone: utc)
    let next = a.summary(now: date("2026-09-15T00:00:00Z"), timeZone: utc)
    #expect(next.today == 0)
    #expect(next.total == 1)
}

@Test func dayBoundaryUsesLocalTimeZone() throws {
    let ny = TimeZone(identifier: "America/New_York")!
    let at = date("2026-09-15T02:00:00Z")
    var a = CounterArchive(now: at, timeZone: ny)
    try a.record(.hinge, at: at, timeZone: ny)
    #expect(a.days[0].day == "2026-09-14")
    #expect(a.summary(now: at, timeZone: ny).today == 1)
}

@Test func travelDoesNotRebucketPreviouslyRecordedDates() throws {
    var a = CounterArchive(now: noon, timeZone: utc)
    try a.record(.hinge, at: noon, timeZone: utc)
    let original = a.days
    _ = a.summary(now: noon, timeZone: TimeZone(identifier: "Pacific/Auckland")!)
    #expect(a.days == original)
}

@Test func springDSTDoesNotDropHistoryDay() {
    let ny = TimeZone(identifier: "America/New_York")!
    let a = CounterArchive(now: noon, timeZone: ny)
    let points = a.history(last: 7, now: date("2026-03-10T16:00:00Z"), timeZone: ny)
    #expect(points.count == 7)
    #expect(Set(points.map(\.day)).count == 7)
    #expect(points.map(\.day).contains("2026-03-08"))
}

@Test func fallDSTDoesNotDuplicateHistoryDay() {
    let ny = TimeZone(identifier: "America/New_York")!
    let a = CounterArchive(now: noon, timeZone: ny)
    let points = a.history(last: 7, now: date("2026-11-03T17:00:00Z"), timeZone: ny)
    #expect(Set(points.map(\.day)).count == 7)
    #expect(points.map(\.day).contains("2026-11-01"))
}

@Test func zeroFilledChartIsChronological() {
    let a = CounterArchive(now: noon, timeZone: utc)
    let points = a.history(last: 7, now: noon, timeZone: utc)
    #expect(points.first?.day == "2026-09-08")
    #expect(points.last?.day == "2026-09-14")
    #expect(points.allSatisfy { $0.total == 0 })
}

@Test func invalidDayAndUnsupportedVersionAreRejected() throws {
    var a = CounterArchive(now: noon, timeZone: utc)
    a.days = [DayCount(day: "2026-02-30", automatic: 1)]
    #expect(throws: (any Error).self) { try a.validated() }
    a.days = []
    a.schemaVersion = 999
    #expect(throws: (any Error).self) { try a.validated() }
}

@Test func duplicateDaysAndNegativeCountsAreRejected() {
    var a = CounterArchive(now: noon, timeZone: utc)
    a.days = [DayCount(day: "2026-09-14"), DayCount(day: "2026-09-14")]
    #expect(throws: (any Error).self) { try a.validated() }
    a.days = [DayCount(day: "2026-09-14", automatic: -1)]
    #expect(throws: (any Error).self) { try a.validated() }
}

@Test func hostileLargeCountsCannotOverflow() {
    var a = CounterArchive(now: noon, timeZone: utc)
    a.days = [DayCount(day: "2026-09-14", automatic: Int.max, manual: Int.max)]
    #expect(throws: (any Error).self) { try a.validated() }
}

@Test func archiveRoundTripAndCSV() throws {
    var a = CounterArchive(now: noon, timeZone: utc)
    try a.record(.manual, at: noon, timeZone: utc)
    let data = try ArchiveFile.encode(a)
    #expect(try ArchiveFile.decode(data) == a)
    #expect(a.csv().contains("2026-09-14,0,1,1\r\n"))
}

@Test func oversizedImportIsRejected() {
    let data = Data(repeating: 32, count: ArchiveFile.maximumBytes + 1)
    #expect(throws: (any Error).self) { try ArchiveFile.decode(data) }
}

@Test func filePersistenceSurvivesNewStore() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = ArchiveFile(url: folder.appendingPathComponent("counts.json"))
    var a = try store.load(orCreate: CounterArchive(now: noon, timeZone: utc))
    try a.record(.hinge, at: noon, timeZone: utc)
    try store.save(a)
    let reopened = try ArchiveFile(url: store.url).load(orCreate: CounterArchive())
    #expect(reopened == a)
}

@Test func corruptedFileIsNotOverwrittenWithZero() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let file = folder.appendingPathComponent("counts.json")
    let damaged = Data("{broken".utf8)
    try damaged.write(to: file)
    #expect(throws: (any Error).self) {
        try ArchiveFile(url: file).load(orCreate: CounterArchive(now: noon, timeZone: utc))
    }
    #expect(try Data(contentsOf: file) == damaged)
}

@Test func invalidSaveLeavesExistingFileUntouched() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = ArchiveFile(url: folder.appendingPathComponent("counts.json"))
    let a = CounterArchive(now: noon, timeZone: utc)
    try store.save(a)
    var invalid = a
    invalid.days = [DayCount(day: "2026-09-14", manual: -1)]
    #expect(throws: (any Error).self) { try store.save(invalid) }
    #expect(try store.load(orCreate: CounterArchive()) == a)
}
