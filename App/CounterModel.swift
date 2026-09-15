import Foundation
import Observation
import WidgetKit

@MainActor @Observable
final class CounterModel {
    private(set) var archive: CounterArchive?
    private(set) var storageError: String?
    var actionError: String?
    private(set) var widgetStatus = "Open the app to publish a widget snapshot."
    private(set) var angle: Double?
    private(set) var hingeDetected: Bool?
    private(set) var foreground = false
    private(set) var pendingSave = false
    private(set) var isUITesting = false

    @ObservationIgnored private let file: ArchiveFile
    @ObservationIgnored private var pendingArchive: CounterArchive?
    @ObservationIgnored private var session = FoldObservationSession()
    @ObservationIgnored private let clock = ContinuousClock()
    @ObservationIgnored private let origin = ContinuousClock.now

    init() {
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
        reload()
    }

    var rawArchiveURL: URL { file.url }
    var canEdit: Bool { archive != nil && storageError == nil && !pendingSave }

    var trackingTitle: String {
        if storageError != nil { return "Storage needs attention" }
        if archive?.automaticTrackingEnabled == false { return "Tracking paused" }
        #if DUO_HINGE_API
        if #available(iOS 27.1, *) {
            if !foreground { return "Observation paused" }
            if hingeDetected == false { return "No hinge on this device" }
            if hingeDetected == true { return "Observing while active" }
            return "Waiting for a hinge update"
        }
        return "iOS 27.1 required for the hinge"
        #else
        return "Manual mode · Duo SDK not enabled"
        #endif
    }

    var trackingDetail: String {
        "Automatic counts require this app to be active and a complete close-to-open transition to be observed. "
        + "Openings while locked, in another app, suspended, or terminated are not recovered."
    }

    func setScene(_ id: UUID, active: Bool) {
        let previous = session.leader
        session.setActive(active, scene: id)
        foreground = session.leader != nil
        if previous != session.leader {
            angle = nil
            hingeDetected = nil
        }
    }

    func receive(degrees: Double?, scene: UUID) {
        guard session.leader == scene else { return }
        hingeDetected = degrees != nil
        angle = degrees.flatMap { $0.isFinite && (0...180).contains($0) ? $0 : nil }
        guard canEdit, archive?.automaticTrackingEnabled == true else {
            session.invalidate()
            return
        }
        let duration = origin.duration(to: clock.now).components
        let seconds = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
        if session.observe(degrees: degrees, timestamp: seconds, scene: scene) {
            record(.hinge)
        }
    }

    func record(_ source: FoldSource) {
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
        persist(CounterArchive())
    }

    func retrySaveOrLoad() {
        if let pendingArchive { persist(pendingArchive) }
        else { reload() }
    }

    private func reload() {
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
        do {
            try file.save(candidate)
            archive = candidate
            pendingArchive = nil
            pendingSave = false
            storageError = nil
            publishWidget(candidate)
        } catch {
            pendingArchive = candidate
            pendingSave = true
            storageError = "The change is not saved yet. Counting is paused. " + error.localizedDescription
            session.invalidate()
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
            WidgetCenter.shared.reloadTimelines(ofKind: "FoldCounterWidget")
            widgetStatus = "Saved counts shared with widgets. Widget refresh timing is controlled by iOS."
        } catch {
            // Widget failure must not roll back an already durable counter transaction.
            widgetStatus = "Counts saved, but the widget snapshot could not be updated: " + error.localizedDescription
        }
    }
}
