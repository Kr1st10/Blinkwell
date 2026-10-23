/// Coalesces screen, lock and sleep notifications. Recovery happens once, only
/// after all availability blockers have cleared; duplicate wake events do nothing.
public struct WakeRecovery {
    private var awaitingAvailability = false
    public init() {}
    public mutating func update(available: Bool) -> Bool {
        if !available { awaitingAvailability = true; return false }
        guard awaitingAvailability else { return false }
        awaitingAvailability = false
        return true
    }
}
