import Foundation

/// A rest has its own clock; opening its instructions does not start it.
public struct BreakSession {
    public let duration: TimeInterval
    public private(set) var startedAt: TimeInterval?
    public init(duration: TimeInterval) { self.duration = max(1,duration) }
    public mutating func start(at now: TimeInterval) {
        guard startedAt == nil else { return }
        startedAt = now
    }
    public func remaining(at now: TimeInterval) -> TimeInterval {
        guard let startedAt else { return duration }
        return max(0,duration-max(0,now-startedAt))
    }
}
