import Foundation

public enum Exercise: String, CaseIterable, Codable, Identifiable {
    case walk, shoulders, posture, distance
    public var id: String { rawValue }
    public var symbol: String {
        switch self {
        case .walk: "figure.walk"
        case .shoulders: "figure.stand"
        case .posture: "figure.flexibility"
        case .distance: "leaf"
        }
    }
    public var title: String {
        switch self {
        case .walk: "Встань и пройдись"
        case .shoulders: "Расслабь плечи"
        case .posture: "Смени положение"
        case .distance: "Побудь без экрана"
        }
    }
    public var instruction: String {
        switch self {
        case .walk: "Отойди от рабочего места, сделай несколько спокойных шагов."
        case .shoulders: "Мягко подними и опусти плечи несколько раз. Дыши спокойно."
        case .posture: "Выбери удобную позу, расслабь руки. Не тянись через боль."
        case .distance: "Продолжи прогулку или просто посмотри вдаль. Возвращайся без спешки."
        }
    }
}

/// A snapshot of the chosen routine. Changing settings cannot change an ongoing break.
/// Changing the guidance never shortens the overall rest duration.
public struct RoutineSession {
    public let exercises: [Exercise]
    public let deadline: TimeInterval
    public let automatic: Bool
    public private(set) var index = 0
    public private(set) var stepDeadline: TimeInterval
    private let stepDuration: TimeInterval

    public init(exercises: [Exercise], duration: TimeInterval, automatic: Bool, now: TimeInterval) {
        self.exercises = exercises.isEmpty ? [.walk] : exercises
        let duration = max(1, duration)
        self.deadline = now + duration
        self.automatic = automatic
        stepDuration = duration / Double(self.exercises.count)
        stepDeadline = now + stepDuration
    }
    public var current: Exercise { exercises[index] }
    public func remaining(at now: TimeInterval) -> TimeInterval { max(0, deadline - now) }
    public func stepRemaining(at now: TimeInterval) -> TimeInterval { max(0, min(stepDeadline, deadline) - now) }
    public mutating func update(now: TimeInterval) {
        guard automatic else { return }
        while now >= stepDeadline && index < exercises.count - 1 {
            index += 1
            stepDeadline = index == exercises.count - 1 ? deadline : min(deadline, stepDeadline + stepDuration)
        }
    }
    public mutating func move(by offset: Int, now: TimeInterval) {
        index = max(0, min(exercises.count - 1, index + offset))
        stepDeadline = index == exercises.count - 1 ? deadline : min(deadline, now + stepDuration)
    }
}
