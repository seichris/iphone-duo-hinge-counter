import Foundation
import Observation
import WidgetKit

@MainActor @Observable
final class CounterModel {
    // Both SwiftUI and the app-target-only Shortcuts action use this serial writer.
    static let shared = CounterModel()
    private(set) var archive: CounterArchive?
    private(set) var storageError: String?
    var actionError: String?
    private(set) var widgetStatus = "Open the app to publish a widget snapshot."
    private(set) var angle: Double?
    private var receivedHingeUpdate = false
    private(set) var foreground = false
    private(set) var observationID: UUID?
    private(set) var sensorLeader: UUID?
    private(set) var pendingSave = false
    private(set) var isUITesting = false

    @ObservationIgnored private let file: ArchiveFile
    @ObservationIgnored private var pendingArchive: CounterArchive?
    @ObservationIgnored private var session = FoldObservationSession()
    @ObservationIgnored private let clock = ContinuousClock()
    @ObservationIgnored private let origin = ContinuousClock.now

    private init() {
        var directory = URL.applicationSupportDirectory.appendingPathComponent("FoldCounter", isDirectory: true)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            isUITesting = true
            directory = directory.appendingPathComponent("UITests", isDirectory: true)
            if ProcessInfo.processInfo.arguments.contains("--reset-test-data") {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        #endif
        file = ArchiveFile(url: directory.appendingPathComponent("counter-v1.json"))
        #if DEBUG
        if isUITesting,
           ProcessInfo.processInfo.arguments.contains("--reset-test-data"),
           ProcessInfo.processInfo.arguments.contains("--history-fixture") {
            // Explicit UI-test fixture, confined to UITests and never shared
            // with widgets. Normal launches cannot seed synthetic history.
            var fixture = CounterArchive()
            fixture.startedOn = "2001-01-01"
            fixture.days = [DayCount(day: "2001-01-01", automatic: 7, manual: 2),
                            DayCount(day: "2024-01-01", automatic: 3)]
            do { try file.save(fixture) }
            catch { actionError = error.localizedDescription }
        }
        #endif
        reload()
    }

    var rawArchiveURL: URL { file.url }
    var canEdit: Bool { archive != nil && storageError == nil && !pendingSave }

    static var supportsOpeningAutomation: Bool {
        #if DUO_HINGE_API
        if #available(iOS 27.2, *) { return true }
        #endif
        return false
    }

    var trackingTitle: String {
        if storageError != nil { return "Storage needs attention" }
        if archive?.automaticTrackingEnabled == false { return "Tracking paused" }
        if archive?.countingMethod == .shortcuts {
            return Self.supportsOpeningAutomation ? "Shortcuts selected" : "Opening automation unavailable"
        }
        #if DUO_HINGE_API
        if #available(iOS 27.1, *) {
            if !foreground { return "Observation paused" }
            if angle != nil { return "Observing while active" }
            if receivedHingeUpdate { return "Hinge reading unavailable" }
            return "Waiting for a hinge update"
        }
        return "iOS 27.1 required for the hinge"
        #else
        return "Manual mode · Duo SDK not enabled"
        #endif
    }

    var trackingDetail: String {
        if archive?.countingMethod == .shortcuts {
            return "Each run of Record Opening saves one Shortcuts entry. Set up one opening automation on an iPhone Duo with iOS 27.2 or later. Missed runs cannot be recovered."
        }
        var detail = "The foreground sensor counts a complete close-to-open movement while this app is active. Openings outside that session are not recovered."
        if Self.supportsOpeningAutomation {
            detail += " To count while using another app on iPhone Duo, choose Shortcuts in Settings."
        }
        return detail
    }

    func setScene(_ id: UUID, active: Bool) {
        session.setActive(active, scene: id)
        foreground = session.leader != nil
        updateObservation()
    }

    func subscription(for scene: UUID) -> UUID? {
        sensorLeader == scene ? observationID : nil
    }

    func receive(degrees: Double?, scene: UUID, observationID: UUID) {
        guard session.subscription(for: scene) == observationID else { return }
        receivedHingeUpdate = true
        angle = degrees.flatMap { $0.isFinite && (0...180).contains($0) ? $0 : nil }
        let duration = origin.duration(to: clock.now).components
        let seconds = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
        if session.observe(degrees: degrees, timestamp: seconds, scene: scene, observationID: observationID) {
            record(.hinge)
        }
    }

    #if DEBUG
    func recordManualOpening() {
        record(.manual)
    }
    #endif

    private func record(_ source: FoldSource) {
        guard canEdit, var candidate = archive else { return }
        do {
            try candidate.record(source, at: Date(), timeZone: .current)
            persist(candidate)
        } catch { actionError = error.localizedDescription }
    }

    func setAutomaticTracking(_ enabled: Bool) {
        guard canEdit, var candidate = archive else { return }
        session.invalidate()
        candidate.automaticTrackingEnabled = enabled
        persist(candidate)
    }

    func setCountingMethod(_ method: CountingMethod) {
        guard canEdit, var candidate = archive, candidate.countingMethod != method else { return }
        session.invalidate()
        candidate.countingMethod = method
        persist(candidate)
    }

    func recordShortcutOpening() throws {
        // A cold launch may have happened before protected storage was available.
        if storageError != nil && !pendingSave { reload() }
        guard canEdit, var candidate = archive else {
            throw CounterDataError.invalid(storageError ?? "Open Hinge Counter to check storage.")
        }
        try candidate.record(.shortcut, at: Date(), timeZone: .current)
        do {
            try saveAndPublish(candidate)
        } catch {
            // Report failure to Shortcuts. Retaining this invocation for a later UI
            // retry as well could count a failed action twice if the user reruns it.
            storageError = "The Shortcuts opening could not be saved. " + error.localizedDescription
            updateObservation()
            throw error
        }
    }

    func restore(_ candidate: CounterArchive) {
        guard !pendingSave else { return }
        do {
            try candidate.validated()
            session.invalidate()
            persist(candidate)
        } catch { actionError = error.localizedDescription }
    }

    func erase() {
        session.invalidate()
        var empty = CounterArchive()
        if let archive {
            empty.countingMethod = archive.countingMethod
            empty.automaticTrackingEnabled = archive.automaticTrackingEnabled
        }
        persist(empty)
    }

    func retrySaveOrLoad() {
        if let pendingArchive { persist(pendingArchive) }
        else { reload() }
    }

    private func reload() {
        defer { updateObservation() }
        do {
            let loaded = try file.load(orCreate: CounterArchive())
            archive = loaded
            storageError = nil
            publishWidget(loaded)
        } catch {
            archive = nil
            storageError = "Your existing file was left untouched. " + error.localizedDescription
        }
    }

    /// Write before publishing. On failure retain exactly one pending transaction for retry;
    /// stop accepting samples so an error cannot silently become a lost or duplicate count.
    private func persist(_ candidate: CounterArchive) {
        defer { updateObservation() }
        do {
            try saveAndPublish(candidate)
        } catch {
            pendingArchive = candidate
            pendingSave = true
            storageError = "The change is not saved yet. Counting is paused. " + error.localizedDescription
            session.invalidate()
        }
    }

    private func saveAndPublish(_ candidate: CounterArchive) throws {
        try file.save(candidate)
        archive = candidate
        pendingArchive = nil
        pendingSave = false
        storageError = nil
        publishWidget(candidate)
    }

    private func updateObservation() {
        session.setEnabled(canEdit && archive?.observesHinge == true)
        sensorLeader = session.isEnabled ? session.leader : nil
        let nextID = sensorLeader.map { _ in session.observationID }
        if observationID != nextID {
            angle = nil
            receivedHingeUpdate = false
            observationID = nextID
        }
    }

    private func publishWidget(_ value: CounterArchive) {
        // UI tests never overwrite the real app group's widget snapshot.
        guard !isUITesting else { return }
        guard let group = Bundle.main.object(forInfoDictionaryKey: "FoldCounterAppGroup") as? String,
              !group.isEmpty,
              let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
            widgetStatus = "Widgets need matching App Group signing on the app and extension. Your counts are saved in the app."
            return
        }
        do {
            try ArchiveFile(url: directory.appendingPathComponent("widget-v1.json")).save(value)
            WidgetCenter.shared.reloadAllTimelines()
            widgetStatus = "Saved counts shared with widgets. Widget refresh timing is controlled by iOS."
        } catch {
            // Widget failure must not roll back an already durable counter transaction.
            widgetStatus = "Counts saved, but the widget snapshot could not be updated: " + error.localizedDescription
        }
    }
}
