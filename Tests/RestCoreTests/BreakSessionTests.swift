import XCTest
@testable import RestCore

final class BreakSessionTests: XCTestCase {
    func testEyeRestGetsFullTwentySecondsOnlyAfterExplicitStart() {
        var session = BreakSession(duration:20)
        XCTAssertEqual(session.remaining(at:1000),20)
        session.start(at:1000)
        XCTAssertEqual(session.remaining(at:1000),20)
        XCTAssertEqual(session.remaining(at:1019),1)
        XCTAssertEqual(session.remaining(at:1020),0)
    }
    func testRepeatedStartDoesNotRestartOrShortenRest() {
        var session = BreakSession(duration:120)
        session.start(at:10); session.start(at:50)
        XCTAssertEqual(session.remaining(at:50),80)
        XCTAssertEqual(session.remaining(at:130),0)
    }
    func testPreparationRestAndCompletionDoNotConsumeNextWorkInterval() {
        var engine = TimerEngine(); engine.configuration.naturalRest = false
        for second in 0...1200 { engine.tick(now:Double(second),idle:0,available:true,paused:false,reading:false,takingBreak:false) }
        XCTAssertEqual(engine.pending,.eyes)
        // Waiting at instructions, then a complete 20-second rest.
        for second in 1201...1240 { engine.tick(now:Double(second),idle:0,available:true,paused:false,reading:false,takingBreak:true) }
        engine.reset(.eyes); engine.rebase()
        // A completion card may stay open while another window is in use.
        for second in 1241...1280 { engine.tick(now:Double(second),idle:0,available:true,paused:false,reading:false,takingBreak:true) }
        XCTAssertEqual(engine.remaining(.eyes),1200)
        XCTAssertEqual(engine.body,1200); XCTAssertEqual(engine.activeTotal,1200)
        engine.rebase()
        engine.tick(now:1281,idle:0,available:true,paused:false,reading:false,takingBreak:false)
        XCTAssertEqual(engine.remaining(.eyes),1200)
        engine.tick(now:1282,idle:0,available:true,paused:false,reading:false,takingBreak:false)
        XCTAssertEqual(engine.remaining(.eyes),1199)
    }
}
