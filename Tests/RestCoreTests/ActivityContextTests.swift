import XCTest
@testable import RestCore

final class ActivityContextTests: XCTestCase {
    private func update(_ policy: inout ActivityContext, _ time: Double, idle: Double = 0,
                        available: Bool = true, paused: Bool = false, reading: Bool = false,
                        microphone: Bool = false, takingBreak: Bool = false) {
        policy.update(now:time,idle:idle,threshold:180,available:available,paused:paused,
            reading:reading,smart:true,microphone:microphone,takingBreak:takingBreak)
    }
    func testUnknownIdleDoesNotResetLoadAndReadingRestoresIt() {
        var engine = TimerEngine(), policy = ActivityContext()
        for second in 0...400 {
            update(&policy,Double(second),idle:Double(second))
            engine.tick(now:Double(second),idle:Double(second),available:true,paused:false,reading:false,takingBreak:false,confirmIdleRest:false)
        }
        XCTAssertEqual(engine.eyes,179); XCTAssertEqual(engine.body,179)
        update(&policy,401)
        XCTAssertEqual(policy.review?.missingActivity,221)
        XCTAssertNotNil(policy.suppression(at:401))
        engine.restoreReading(seconds:policy.review!.missingActivity)
        XCTAssertEqual(engine.eyes,400); XCTAssertEqual(engine.activeTotal,400)
        policy.dismissReview(); XCTAssertNil(policy.review)
    }
    func testEngagementStartingDuringIdleDoesNotDoubleCountItsFirstTick() {
        var engine = TimerEngine(), policy = ActivityContext()
        for second in 0...300 {
            let engaged = second == 300
            update(&policy,Double(second),idle:Double(second),microphone:engaged)
            engine.tick(now:Double(second),idle:Double(second),available:true,paused:false,reading:engaged,takingBreak:false,confirmIdleRest:false)
        }
        engine.restoreReading(seconds:policy.review!.missingActivity)
        XCTAssertEqual(engine.activeTotal,300)
        XCTAssertEqual(policy.review?.end,299)
    }
    func testConfirmedLockStillCountsAsRestAndDoesNotAskReadingQuestion() {
        var engine = TimerEngine(), policy = ActivityContext()
        for second in 0...30 { engine.tick(now:Double(second),idle:0,available:true,paused:false,reading:false,takingBreak:false,confirmIdleRest:false) }
        update(&policy,180,idle:180)
        update(&policy,181,idle:181,available:false)
        engine.tick(now:31,idle:0,available:false,paused:false,reading:false,takingBreak:false,confirmIdleRest:false)
        engine.tick(now:400,idle:0,available:false,paused:false,reading:false,takingBreak:false,confirmIdleRest:false)
        XCTAssertEqual(engine.eyes,0); XCTAssertEqual(engine.body,0)
        update(&policy,500); XCTAssertNil(policy.review)
    }
    func testMicrophoneSuppressesRemindersWithoutCreatingIdleReview() {
        var policy = ActivityContext()
        update(&policy,0,microphone:true)
        update(&policy,600,idle:600,microphone:true)
        XCTAssertNil(policy.review); XCTAssertNotNil(policy.suppression(at:600))
        update(&policy,601,microphone:false)
        XCTAssertNotNil(policy.suppression(at:660)); XCTAssertNil(policy.suppression(at:661))
    }
    func testReviewDoesNotBlockForeverAndDoesNotResetWithoutDecision() {
        var policy = ActivityContext()
        update(&policy,179,idle:179); update(&policy,180,idle:180); update(&policy,300,idle:300); update(&policy,301)
        let review=policy.review
        XCTAssertNotNil(review); XCTAssertNotNil(policy.suppression(at:301))
        XCTAssertNil(policy.suppression(at:421)); XCTAssertEqual(policy.review,review)
        update(&policy,422,paused:true); XCTAssertNil(policy.review)
    }
    func testManualProtectionAndReadingDoNotBecomeNaturalRest() {
        var policy = ActivityContext(); policy.manualUntil=1800
        update(&policy,500,idle:500); XCTAssertNil(policy.review); XCTAssertNotNil(policy.suppression(at:500))
        update(&policy,1000,idle:1000,reading:true); XCTAssertNil(policy.review)
        var engine = TimerEngine()
        for second in 0...400 { engine.tick(now:Double(second),idle:9999,available:true,paused:false,reading:true,takingBreak:false,confirmIdleRest:false) }
        XCTAssertEqual(engine.activeTotal,400); XCTAssertEqual(engine.eyes,400)
    }
}
