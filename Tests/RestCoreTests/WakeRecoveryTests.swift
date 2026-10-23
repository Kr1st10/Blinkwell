import XCTest
@testable import RestCore

final class WakeRecoveryTests: XCTestCase {
    func testInitialAndDuplicateWakeEventsDoNotTriggerRecovery() {
        var recovery = WakeRecovery()
        XCTAssertFalse(recovery.update(available:true))
        XCTAssertFalse(recovery.update(available:false))
        XCTAssertFalse(recovery.update(available:false))
        XCTAssertTrue(recovery.update(available:true))
        XCTAssertFalse(recovery.update(available:true))
    }
    func testRecoveryWaitsUntilScreenAndSessionAreBothAvailable() {
        var recovery = WakeRecovery()
        var sleeping = true, locked = true
        XCTAssertFalse(recovery.update(available: !sleeping && !locked))
        sleeping = false
        XCTAssertFalse(recovery.update(available: !sleeping && !locked))
        locked = false
        XCTAssertTrue(recovery.update(available: !sleeping && !locked))
    }
    func testFreshIdleBaselineResumesWithoutInputAndDoesNotCountSleep() {
        var engine = TimerEngine(); engine.configuration.naturalRest = false
        var recovery = WakeRecovery()
        for second in 0...10 { engine.tick(now:Double(second),idle:0,available:true,paused:false,reading:false,takingBreak:false) }
        _ = recovery.update(available:false)
        engine.tick(now:11,idle:0,available:false,paused:false,reading:false,takingBreak:false)
        if recovery.update(available:true) { engine.rebase() }
        // Model rebases idle to zero on recovery, without waiting for input.
        engine.tick(now:3611,idle:0,available:true,paused:false,reading:false,takingBreak:false)
        XCTAssertEqual(engine.activeTotal,10); XCTAssertTrue(engine.isCounting)
        engine.tick(now:3612,idle:1,available:true,paused:false,reading:false,takingBreak:false)
        XCTAssertEqual(engine.activeTotal,11)
    }
}
