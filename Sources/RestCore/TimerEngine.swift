import Foundation

public enum BreakKind: String, Codable, CaseIterable {
    case eyes, body
    public var title: String { self == .eyes ? "Отдых для глаз" : "Перерыв для тела" }
}

public struct TimerConfiguration: Equatable {
    public var eyesInterval: TimeInterval = 20 * 60
    public var bodyInterval: TimeInterval = 60 * 60
    public var idleThreshold: TimeInterval = 180
    public var smart = true
    public var eyesEnabled = true
    public var bodyEnabled = true
    public var naturalRest = true
    public init() {}
}

/// Pure state machine. Receives monotonic time and an idle duration, never input contents.
public struct TimerEngine {
    public var configuration = TimerConfiguration()
    public private(set) var eyes: TimeInterval = 0
    public private(set) var body: TimeInterval = 0
    public private(set) var pending: BreakKind?
    public private(set) var activeTotal: TimeInterval = 0
    public private(set) var isCounting = false
    private var previous: TimeInterval?
    private var eyesTarget: TimeInterval?
    private var bodyTarget: TimeInterval?
    private var restStarted: TimeInterval?
    private var eyesRestApplied = false
    private var bodyRestApplied = false

    public init() {}

    public mutating func tick(now: TimeInterval, idle: TimeInterval, available: Bool,
                              paused: Bool, reading: Bool, takingBreak: Bool, confirmIdleRest: Bool = true) {
        let delta = previous.map { max(0, min(now - $0, 5)) } ?? 0
        previous = now
        if !available || paused {
            if restStarted == nil { restStarted = now - delta }
        }
        // Do not mistake a short spell of reading for a natural break. The idle
        // threshold must first confirm inactivity; then use the full idle span.
        let idleRest = configuration.smart && !reading && idle >= configuration.idleThreshold ? max(0, idle) : 0
        let rest = max(confirmIdleRest ? idleRest : 0, restStarted.map { max(0, now - $0) } ?? 0)
        if available && !paused { restStarted = nil }
        if configuration.naturalRest && !takingBreak {
            if rest >= 60 && !eyesRestApplied {
                reset(.eyes); eyesRestApplied = true
            }
            if rest >= 300 && !bodyRestApplied {
                reset(.body); bodyRestApplied = true
            }
        }
        if rest < 1 { eyesRestApplied = false; bodyRestApplied = false }
        isCounting = available && !paused && !takingBreak &&
            (!configuration.smart || reading || idle < configuration.idleThreshold)
        // Confirmed natural rest must not immediately accrue idle seconds again.
        if isCounting && !(configuration.naturalRest && rest >= 60) {
            eyes += delta; body += delta; activeTotal += delta
        }
        if !configuration.eyesEnabled && pending == .eyes { pending = nil }
        if !configuration.bodyEnabled && pending == .body { pending = nil }
        guard !takingBreak, isCounting else { return }
        if configuration.bodyEnabled && body >= (bodyTarget ?? configuration.bodyInterval) {
            pending = .body
        } else if configuration.eyesEnabled && eyes >= (eyesTarget ?? configuration.eyesInterval) {
            pending = .eyes
        } else {
            pending = nil
        }
    }

    public func remaining(_ kind: BreakKind) -> TimeInterval {
        max(0, kind == .eyes ? (eyesTarget ?? configuration.eyesInterval) - eyes :
                (bodyTarget ?? configuration.bodyInterval) - body)
    }

    public mutating func snooze(_ kind: BreakKind, seconds: TimeInterval = 300) {
        if kind == .eyes { eyesTarget = eyes + seconds } else { bodyTarget = body + seconds }
        pending = nil
    }

    public mutating func reset(_ kind: BreakKind) {
        if kind == .eyes {
            eyes = 0; eyesTarget = nil
            if pending == .eyes { pending = nil }
        } else {
            body = 0; bodyTarget = nil
            eyes = 0; eyesTarget = nil; pending = nil
        }
    }

    /// Explicit correction after the user confirms that a no-input span was reading.
    public mutating func restoreReading(seconds: TimeInterval) {
        let added = max(0, seconds)
        eyes += added; body += added; activeTotal += added
    }

    public mutating func applyShared(eyes: Double, body: Double, eyesRemaining: Double, bodyRemaining: Double) {
        self.eyes = max(0, eyes); self.body = max(0, body)
        eyesTarget = self.eyes + max(0, eyesRemaining); bodyTarget = self.body + max(0, bodyRemaining)
        pending = nil
    }

    public mutating func rebase() { previous = nil }
}
