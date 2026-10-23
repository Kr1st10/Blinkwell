import Foundation

public struct IdleReview: Equatable, Identifiable {
    public let id = UUID()
    public let start: TimeInterval
    public let end: TimeInterval
    public let idleDuration: TimeInterval
    public var missingActivity: TimeInterval { max(0, end - start) }
}

/// Distinguishes absence of input from confirmed rest. Uses monotonic time only.
public struct ActivityContext {
    public private(set) var review: IdleReview?
    public private(set) var microphoneActive = false
    public private(set) var graceUntil: TimeInterval = 0
    public var manualUntil: TimeInterval = 0
    private var idleStart: TimeInterval?
    private var longestIdle: TimeInterval = 0
    private var previous: TimeInterval?
    private var manualWasActive = false
    private var returnedAt: TimeInterval = 0
    public init() {}

    public mutating func update(now: TimeInterval, idle: TimeInterval, threshold: TimeInterval,
                                available: Bool, paused: Bool, reading: Bool, smart: Bool,
                                microphone: Bool, takingBreak: Bool) {
        let delta = previous.map { max(0, min(5, now - $0)) } ?? 0
        previous = now
        if microphoneActive && !microphone { graceUntil = max(graceUntil, now + 60) }
        microphoneActive = microphone
        if manualWasActive && manualUntil <= now { graceUntil = max(graceUntil, now + 60) }
        manualWasActive = manualUntil > now
        guard available, !paused, !takingBreak, smart else {
            idleStart = nil; longestIdle = 0
            // A confirmed lock/sleep or an explicit break supersedes an old ambiguity.
            if !available || paused || takingBreak || !smart { review = nil }
            return
        }
        if reading || microphone || manualUntil > now {
            // If reading is explicitly enabled during an idle episode, retain its
            // excluded part so it can be recovered rather than silently discarded.
            if let start = idleStart {
                review = IdleReview(start:start,end:max(start,now-delta),idleDuration:longestIdle)
                returnedAt = now
            }
            idleStart = nil; longestIdle = 0
            return
        }
        if idle >= threshold {
            if idleStart == nil { idleStart = now - delta }
            longestIdle = max(longestIdle, idle)
        } else if let start = idleStart {
            // Last interval ends with new input, so it belongs to activity again.
            review = IdleReview(start:start,end:max(start,now-delta),idleDuration:longestIdle)
            returnedAt = now; idleStart = nil; longestIdle = 0
            graceUntil = max(graceUntil, now + 60)
        }
    }
    public func suppression(at now: TimeInterval) -> String? {
        if microphoneActive { return "Микрофон используется · напоминания отложены" }
        if manualUntil > now { return "Не отвлекать · напоминания отложены" }
        if review != nil && now-returnedAt < 120 { return "Уточни: ты читал или отходил?" }
        if graceUntil > now { return "Минута на возвращение · время учитывается" }
        return nil
    }
    public mutating func dismissReview() { review = nil }
    public mutating func clearReview() { review = nil; idleStart = nil; longestIdle = 0 }
    public mutating func rebase() { previous = nil }
}
