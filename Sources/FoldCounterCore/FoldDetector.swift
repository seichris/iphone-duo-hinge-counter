import Foundation

/// Counts an observed near-closed -> near-flat transition, not every hinge callback.
/// Thresholds are app policy, NOT an Apple durability rating or a calibrated sensor spec.
public struct FoldDetector: Sendable {
    public static let closedDegrees = 10.0
    public static let openDegrees = 170.0
    public static let minimumCycleSeconds = 0.35
    private var closedAt: TimeInterval?
    private var lastTimestamp: TimeInterval?

    public init() {}

    public mutating func reset() {
        closedAt = nil
        lastTimestamp = nil
    }

    /// Supply monotonic elapsed seconds. An unavailable sample invalidates continuity.
    /// Opening the app on an already-open device deliberately does not count a fold.
    public mutating func observe(degrees: Double?, timestamp: TimeInterval) -> Bool {
        guard let degrees, degrees.isFinite, (0...180).contains(degrees),
              timestamp.isFinite, timestamp >= 0 else {
            reset()
            return false
        }
        if let lastTimestamp, timestamp < lastTimestamp {
            reset()
            return false
        }
        // Duplicated callbacks must neither count nor rearm the detector.
        if timestamp == lastTimestamp { return false }
        lastTimestamp = timestamp

        if degrees <= Self.closedDegrees {
            if closedAt == nil { closedAt = timestamp }
            return false
        }
        if degrees >= Self.openDegrees, let start = closedAt {
            closedAt = nil
            return timestamp - start >= Self.minimumCycleSeconds
        }
        return false
    }
}

/// One observer leads even when iPhone Duo has two windows for this app.
/// A leader change is a discontinuity: never synthesize folds across it.
public struct FoldObservationSession: Sendable {
    private var activeScenes: [UUID] = []
    private var detector = FoldDetector()
    public var leader: UUID? { activeScenes.first }
    public private(set) var isEnabled = true
    /// Identifies one uninterrupted subscription. A callback retained by SwiftUI
    /// across pause/resume or a scene handoff must not enter a newer session.
    public private(set) var observationID = UUID()

    public init() {}

    public mutating func setActive(_ active: Bool, scene: UUID) {
        let previous = leader
        if active {
            if !activeScenes.contains(scene) { activeScenes.append(scene) }
        } else {
            activeScenes.removeAll { $0 == scene }
        }
        if leader != previous { invalidate() }
    }

    public mutating func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        isEnabled = enabled
        invalidate()
    }

    public func subscription(for scene: UUID) -> UUID? {
        isEnabled && leader == scene ? observationID : nil
    }

    public mutating func invalidate() {
        detector.reset()
        observationID = UUID()
    }

    public mutating func observe(degrees: Double?, timestamp: TimeInterval, scene: UUID,
                                 observationID: UUID) -> Bool {
        guard subscription(for: scene) == observationID else { return false }
        return detector.observe(degrees: degrees, timestamp: timestamp)
    }
}
