import XCTest
@testable import RestCore

final class TimerEngineTests: XCTestCase {
    func testSharedStateChangesReminderButPreservesLocalStatistics() {
        var engine = TimerEngine(); engine.configuration.naturalRest = false
        for second in 0...10 { tick(&engine, Double(second)) }
        engine.applyShared(eyes: 1199, body: 1800, eyesRemaining: 1, bodyRemaining: 1800)
        XCTAssertEqual(engine.activeTotal, 10)
        tick(&engine, 11); XCTAssertEqual(engine.pending, .eyes)
        engine.applyShared(eyes: 0, body: 0, eyesRemaining: 1200, bodyRemaining: 3600)
        tick(&engine, 12); XCTAssertNil(engine.pending); XCTAssertEqual(engine.activeTotal, 12)
    }
    private func tick(_ engine: inout TimerEngine, _ now: Double, idle: Double = 0,
                      available: Bool = true, paused: Bool = false, reading: Bool = false, takingBreak: Bool = false) {
        engine.tick(now: now, idle: idle, available: available, paused: paused, reading: reading, takingBreak: takingBreak)
    }
    func testConcurrentRemindersGiveBodyPriority() {
        var engine = TimerEngine()
        engine.configuration.eyesInterval = 10; engine.configuration.bodyInterval = 10
        for second in 0...10 { tick(&engine, Double(second)) }
        XCTAssertEqual(engine.pending, .body)
        XCTAssertEqual(engine.activeTotal, 10)
    }
    func testSleepDoesNotAccumulateAndNaturalRestResetsBoth() {
        var engine = TimerEngine()
        for second in 0...20 { tick(&engine, Double(second)) }
        tick(&engine, 21, available: false)
        engine.rebase()
        tick(&engine, 401)
        XCTAssertEqual(engine.activeTotal, 20)
        XCTAssertEqual(engine.eyes, 0); XCTAssertEqual(engine.body, 0)
    }
    func testUnexpectedGapNeverAddsMoreThanFiveSeconds() {
        var engine = TimerEngine()
        tick(&engine, 0); tick(&engine, 3600)
        XCTAssertEqual(engine.activeTotal, 5)
    }
    func testIdleThresholdAndNaturalReset() {
        var engine = TimerEngine()
        for second in 0...179 { tick(&engine, Double(second), idle: Double(second)) }
        XCTAssertEqual(engine.activeTotal, 179)
        tick(&engine, 180, idle: 180)
        XCTAssertFalse(engine.isCounting)
        XCTAssertEqual(engine.eyes, 0)
        XCTAssertEqual(engine.body, 179)
        tick(&engine, 301, idle: 301)
        XCTAssertEqual(engine.body, 0)
        tick(&engine, 302)
        XCTAssertEqual(engine.body, 1)
    }
    func testReadingKeepsCountingWithoutInput() {
        var engine = TimerEngine()
        for second in 0...400 { tick(&engine, Double(second), idle: 9999, reading: true) }
        XCTAssertEqual(engine.activeTotal, 400)
        XCTAssertEqual(engine.eyes, 400)
    }
    func testSimpleModeIgnoresIdleButHonorsLock() {
        var engine = TimerEngine(); engine.configuration.smart = false
        for second in 0...20 { tick(&engine, Double(second), idle: 9999) }
        tick(&engine, 21, available: false)
        XCTAssertEqual(engine.activeTotal, 20)
    }
    func testSnoozeUsesActiveTimeAndSkipDoesNotCompleteBreak() {
        var engine = TimerEngine(); engine.configuration.eyesInterval = 10
        for second in 0...10 { tick(&engine, Double(second)) }
        XCTAssertEqual(engine.pending, .eyes)
        engine.snooze(.eyes, seconds: 5)
        tick(&engine, 11, paused: true)
        XCTAssertNil(engine.pending); XCTAssertEqual(engine.remaining(.eyes), 5)
        for second in 12...16 { tick(&engine, Double(second)) }
        XCTAssertEqual(engine.pending, .eyes)
        engine.reset(.eyes)
        XCTAssertNil(engine.pending); XCTAssertEqual(engine.body, 15)
    }
    func testEyeBreakDoesNotResetBodyAndBodyBreakResetsBoth() {
        var engine = TimerEngine()
        for second in 0...100 { tick(&engine, Double(second)) }
        tick(&engine, 101, takingBreak: true)
        XCTAssertEqual(engine.activeTotal, 100)
        engine.reset(.eyes)
        XCTAssertEqual(engine.body, 100); XCTAssertEqual(engine.eyes, 0)
        engine.reset(.body)
        XCTAssertEqual(engine.body, 0)
    }
    func testDisabledRemindersNeverBecomePending() {
        var engine = TimerEngine()
        engine.configuration.eyesEnabled = false; engine.configuration.bodyEnabled = false
        for second in 0...4000 { tick(&engine, Double(second)) }
        XCTAssertNil(engine.pending)
    }
    func testPauseSuppressesPendingUntilResume() {
        var engine = TimerEngine(); engine.configuration.eyesInterval = 5
        for second in 0...5 { tick(&engine, Double(second)) }
        tick(&engine, 6, paused: true)
        XCTAssertFalse(engine.isCounting)
        XCTAssertEqual(engine.activeTotal, 5)
    }
    func testIncreasingIntervalClearsStaleReminder() {
        var engine = TimerEngine(); engine.configuration.eyesInterval = 5
        for second in 0...5 { tick(&engine, Double(second)) }
        XCTAssertEqual(engine.pending, .eyes)
        engine.configuration.eyesInterval = 100
        tick(&engine, 6)
        XCTAssertNil(engine.pending)
        XCTAssertEqual(engine.remaining(.eyes), 94)
    }
}
