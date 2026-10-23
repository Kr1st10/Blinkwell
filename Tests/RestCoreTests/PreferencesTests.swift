import XCTest
@testable import RestCore

final class PreferencesTests: XCTestCase {
    func testLegacySettingsSurviveNewFields() throws {
        let oldJSON = #"{"eyesMinutes":35,"bodyMinutes":90,"eyesSeconds":30,"bodyDuration":10,"idleMinutes":7,"eyesEnabled":false,"bodyEnabled":true,"smart":false,"naturalRest":false,"sound":false,"popup":false,"quietEnabled":true,"quietStart":23,"quietEnd":6,"appearance":"dark","personalText":"Hello","personalSymbol":"☕","personalColor":"green"}"#
        let preferences = try JSONDecoder().decode(Preferences.self, from: Data(oldJSON.utf8))
        XCTAssertEqual(preferences.eyesMinutes, 35)
        XCTAssertEqual(preferences.bodyMinutes, 90)
        XCTAssertEqual(preferences.eyesSeconds, 30)
        XCTAssertEqual(preferences.idleMinutes, 7)
        XCTAssertFalse(preferences.eyesEnabled)
        XCTAssertFalse(preferences.smart)
        XCTAssertFalse(preferences.sound)
        XCTAssertEqual(preferences.quietStart, 23)
        XCTAssertEqual(preferences.appearance, "dark")
        XCTAssertEqual(preferences.personalText, "Hello")
        XCTAssertEqual(preferences.exercises, Exercise.allCases)
        XCTAssertTrue(preferences.automaticExercises)
        XCTAssertTrue(preferences.animations)
        XCTAssertTrue(preferences.deferMicrophone)
        XCTAssertTrue(preferences.resumeAfterWake)
    }
    func testNewSelectionAndAnimationPersistAcrossRoundTrip() throws {
        var original = Preferences()
        original.exerciseIDs = ["posture", "distance"]
        original.resumeAfterWake = false; original.deferMicrophone = false; original.animations = false; original.automaticExercises = false
        let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(restored.exercises, [.posture, .distance])
        XCTAssertFalse(restored.resumeAfterWake)
        XCTAssertFalse(restored.deferMicrophone)
        XCTAssertFalse(restored.animations)
        XCTAssertFalse(restored.automaticExercises)
    }
    func testMissingAndInvalidValuesGetSafeDefaults() throws {
        let json = #"{"exerciseIDs":["removed-exercise"],"eyesMinutes":0,"bodyDuration":-1,"quietEnd":99}"#
        let preferences = try JSONDecoder().decode(Preferences.self, from: Data(json.utf8))
        XCTAssertEqual(preferences.exercises, [.walk])
        XCTAssertEqual(preferences.eyesMinutes, 1)
        XCTAssertEqual(preferences.bodyDuration, 5)
        XCTAssertEqual(preferences.quietEnd, 23)
        XCTAssertEqual(preferences.bodyMinutes, 60)
    }
}
