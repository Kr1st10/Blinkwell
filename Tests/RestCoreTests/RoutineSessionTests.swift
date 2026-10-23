import XCTest
@testable import RestCore

final class RoutineSessionTests: XCTestCase {
    func testAutomaticTransitionsAndEnd() {
        var session = RoutineSession(exercises: Exercise.allCases, duration: 120, automatic: true, now: 100)
        session.update(now: 129)
        XCTAssertEqual(session.current, .walk)
        session.update(now: 130)
        XCTAssertEqual(session.current, .shoulders)
        session.update(now: 195)
        XCTAssertEqual(session.current, .distance)
        XCTAssertEqual(session.remaining(at: 195), 25)
        session.update(now: 999)
        XCTAssertEqual(session.remaining(at: 999), 0)
        XCTAssertEqual(session.index, 3)
    }
    func testManualNavigationNeverShortensOverallBreak() {
        var session = RoutineSession(exercises: Exercise.allCases, duration: 300, automatic: true, now: 0)
        session.move(by: 1, now: 10)
        XCTAssertEqual(session.current, .shoulders)
        XCTAssertEqual(session.remaining(at: 10), 290)
        XCTAssertEqual(session.stepRemaining(at: 10), 75)
        session.move(by: -1, now: 20)
        XCTAssertEqual(session.current, .walk)
        XCTAssertEqual(session.deadline, 300)
        session.move(by: -100, now: 21)
        XCTAssertEqual(session.index, 0)
        session.move(by: 100, now: 22)
        XCTAssertEqual(session.index, 3)
        XCTAssertEqual(session.stepRemaining(at: 22), 278)
    }
    func testManualModeDoesNotSwitchAutomatically() {
        var session = RoutineSession(exercises: [.posture, .distance], duration: 120, automatic: false, now: 0)
        session.update(now: 100)
        XCTAssertEqual(session.current, .posture)
        session.move(by: 1, now: 101)
        XCTAssertEqual(session.current, .distance)
    }
    func testEmptyRoutineHasSafeFallback() {
        var session = RoutineSession(exercises: [], duration: 0, automatic: true, now: 0)
        session.update(now: 200)
        XCTAssertEqual(session.exercises, [.walk])
        XCTAssertEqual(session.current, .walk)
        XCTAssertEqual(session.remaining(at: 200), 0)
    }
    func testRunningRoutineKeepsOriginalSelection() {
        var preferences = Preferences()
        preferences.exerciseIDs = ["walk", "distance"]
        let session = RoutineSession(exercises: preferences.exercises, duration: 300, automatic: true, now: 0)
        preferences.exerciseIDs = ["posture"]
        XCTAssertEqual(session.exercises, [.walk, .distance])
    }
}
