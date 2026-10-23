import Foundation

public struct Preferences: Codable {
    public var eyesMinutes = 20
    public var bodyMinutes = 60
    public var eyesSeconds = 20
    public var bodyDuration = 5
    public var idleMinutes = 3
    public var eyesEnabled = true
    public var bodyEnabled = true
    public var smart = true
    public var naturalRest = true
    public var deferMicrophone = true
    public var resumeAfterWake = true
    public var sound = true
    public var popup = true
    public var quietEnabled = false
    public var quietStart = 22
    public var quietEnd = 8
    public var appearance = "system"
    public var personalText = ""
    public var personalSymbol = "🌿"
    public var personalColor = "green"
    public var exerciseIDs = Exercise.allCases.map(\.rawValue)
    public var automaticExercises = true
    public var animations = true

    public init() {}
    private enum CodingKeys: String, CodingKey {
        case eyesMinutes, bodyMinutes, eyesSeconds, bodyDuration, idleMinutes,
             eyesEnabled, bodyEnabled, smart, naturalRest, sound, popup,
             quietEnabled, quietStart, quietEnd, appearance,
             personalText, personalSymbol, personalColor,
             exerciseIDs, automaticExercises, animations, deferMicrophone, resumeAfterWake
    }

    // New preferences must not erase existing settings from an earlier app version.
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        eyesMinutes = min(120, max(1, try c.decodeIfPresent(Int.self, forKey: .eyesMinutes) ?? eyesMinutes))
        bodyMinutes = min(180, max(5, try c.decodeIfPresent(Int.self, forKey: .bodyMinutes) ?? bodyMinutes))
        eyesSeconds = min(120, max(10, try c.decodeIfPresent(Int.self, forKey: .eyesSeconds) ?? eyesSeconds))
        bodyDuration = try c.decodeIfPresent(Int.self, forKey: .bodyDuration) ?? bodyDuration
        if ![2, 5, 10].contains(bodyDuration) { bodyDuration = 5 }
        idleMinutes = min(15, max(1, try c.decodeIfPresent(Int.self, forKey: .idleMinutes) ?? idleMinutes))
        eyesEnabled = try c.decodeIfPresent(Bool.self, forKey: .eyesEnabled) ?? eyesEnabled
        bodyEnabled = try c.decodeIfPresent(Bool.self, forKey: .bodyEnabled) ?? bodyEnabled
        smart = try c.decodeIfPresent(Bool.self, forKey: .smart) ?? smart
        resumeAfterWake = try c.decodeIfPresent(Bool.self, forKey: .resumeAfterWake) ?? resumeAfterWake
        deferMicrophone = try c.decodeIfPresent(Bool.self, forKey: .deferMicrophone) ?? deferMicrophone
        naturalRest = try c.decodeIfPresent(Bool.self, forKey: .naturalRest) ?? naturalRest
        sound = try c.decodeIfPresent(Bool.self, forKey: .sound) ?? sound
        popup = try c.decodeIfPresent(Bool.self, forKey: .popup) ?? popup
        quietEnabled = try c.decodeIfPresent(Bool.self, forKey: .quietEnabled) ?? quietEnabled
        quietStart = min(23, max(0, try c.decodeIfPresent(Int.self, forKey: .quietStart) ?? quietStart))
        quietEnd = min(23, max(0, try c.decodeIfPresent(Int.self, forKey: .quietEnd) ?? quietEnd))
        appearance = try c.decodeIfPresent(String.self, forKey: .appearance) ?? appearance
        personalText = try c.decodeIfPresent(String.self, forKey: .personalText) ?? personalText
        personalSymbol = try c.decodeIfPresent(String.self, forKey: .personalSymbol) ?? personalSymbol
        personalColor = try c.decodeIfPresent(String.self, forKey: .personalColor) ?? personalColor
        exerciseIDs = try c.decodeIfPresent([String].self, forKey: .exerciseIDs) ?? exerciseIDs
        automaticExercises = try c.decodeIfPresent(Bool.self, forKey: .automaticExercises) ?? automaticExercises
        animations = try c.decodeIfPresent(Bool.self, forKey: .animations) ?? animations
        exerciseIDs = exercises.map(\.rawValue)
    }
    public var exercises: [Exercise] {
        let selected = Exercise.allCases.filter { exerciseIDs.contains($0.rawValue) }
        return selected.isEmpty ? [.walk] : selected
    }
}
