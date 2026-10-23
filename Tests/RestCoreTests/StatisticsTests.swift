import XCTest
import Foundation
import CSQLite
@testable import RestCore
@testable import RestStorage

final class StatisticsTests: XCTestCase {
    private var utc: Calendar {
        var result = Calendar(identifier: .gregorian); result.timeZone = TimeZone(secondsFromGMT: 0)!; return result
    }
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    func testActivityIsSplitAtQuarterHourAndMidnight() {
        let split = ActivityBuckets.split(ActivitySpan(start: date("2026-10-20T23:59:50Z"), end: date("2026-10-21T00:00:10Z")), calendar: utc)
        XCTAssertEqual(split.map(\.day), ["2026-10-20", "2026-10-21"])
        XCTAssertEqual(split.map(\.seconds), [10, 10])
        let quarters = ActivityBuckets.split(ActivitySpan(start: date("2026-10-20T08:14:50Z"), end: date("2026-10-20T08:15:10Z")), calendar: utc)
        XCTAssertEqual(quarters.count, 2)
        XCTAssertEqual(quarters.reduce(0) { $0 + $1.seconds }, 20)
    }
    func testActivityAndBreaksAreRecordedTogetherWithDailyTotals() {
        let store = StatisticsStore(path: ":memory:")
        let day = date("2026-10-20T08:14:50Z")
        XCTAssertTrue(store.record(spans: [ActivitySpan(start: day, end: day.addingTimeInterval(40))], calendar: utc))
        XCTAssertTrue(store.record(kind: .eyes, date: day, calendar: utc))
        let details = store.details(on: day, calendar: utc)
        XCTAssertEqual(details.bins.count, 96)
        XCTAssertEqual(details.locatedSeconds, 40)
        XCTAssertEqual(details.summary?.seconds, 40)
        XCTAssertEqual(details.summary?.eyes, 1)
        XCTAssertEqual(details.legacySeconds, 0)
        XCTAssertEqual(details.events.first?.kind, .eyes)
    }
    func testLegacyDatabaseKeepsTotalsWithoutInventingTimeline() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: path) }
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path.path, &db), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, "CREATE TABLE days(day TEXT PRIMARY KEY,seconds REAL NOT NULL DEFAULT 0,eyes INTEGER NOT NULL DEFAULT 0,body INTEGER NOT NULL DEFAULT 0); INSERT INTO days VALUES('2026-10-20',7200,3,1);", nil, nil, nil), SQLITE_OK)
        sqlite3_close(db)
        let store = StatisticsStore(path: path.path)
        let details = store.details(on: date("2026-10-20T12:00:00Z"), calendar: utc)
        XCTAssertNil(store.error)
        XCTAssertEqual(details.summary?.seconds, 7200)
        XCTAssertEqual(details.summary?.eyes, 3)
        XCTAssertEqual(details.legacySeconds, 7200)
        XCTAssertEqual(details.locatedSeconds, 0)
        XCTAssertTrue(details.events.isEmpty)
    }
    func testFailedBinWriteRollsBackDailyTotal() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: path) }
        let store = StatisticsStore(path: path.path)
        var db: OpaquePointer?; sqlite3_open(path.path, &db)
        XCTAssertEqual(sqlite3_exec(db, "CREATE TRIGGER reject_bins BEFORE INSERT ON activity_bins BEGIN SELECT RAISE(ABORT,'test'); END;", nil, nil, nil), SQLITE_OK)
        sqlite3_close(db)
        let start = date("2026-10-20T08:00:00Z")
        XCTAssertFalse(store.record(spans: [ActivitySpan(start: start, end: start.addingTimeInterval(10))], calendar: utc))
        XCTAssertTrue(store.days().isEmpty)
    }
    func testDSTDaysHaveCorrectLengthAndKeepSeparateRepeatedHours() {
        var ny = utc; ny.timeZone = TimeZone(identifier: "America/New_York")!
        let store = StatisticsStore(path: ":memory:")
        XCTAssertEqual(store.details(on: date("2026-03-08T12:00:00Z"), calendar: ny).bins.count, 92)
        XCTAssertEqual(store.details(on: date("2026-11-01T12:00:00Z"), calendar: ny).bins.count, 100)
        let first = date("2026-11-01T05:00:00Z"), second = date("2026-11-01T06:00:00Z")
        store.record(spans: [ActivitySpan(start: first, end: first.addingTimeInterval(60)), ActivitySpan(start: second, end: second.addingTimeInterval(60))], calendar: ny)
        let details = store.details(on: first, calendar: ny)
        XCTAssertEqual(details.bins.filter { $0.seconds > 0 }.count, 2)
        XCTAssertEqual(details.locatedSeconds, 120)
    }
    func testHistoryIsNotLimitedToFourteenDaysAndClearRemovesDetails() {
        let store = StatisticsStore(path: ":memory:")
        let start = date("2026-01-01T12:00:00Z")
        for day in 0..<40 { store.record(kind: .body, date: start.addingTimeInterval(Double(day * 86400)), calendar: utc) }
        XCTAssertEqual(store.days().count, 40)
        XCTAssertTrue(store.clear())
        XCTAssertTrue(store.days().isEmpty)
        XCTAssertTrue(store.details(on: start, calendar: utc).events.isEmpty)
    }
    func testSamaraMidnightIsAssignedToTheCorrectDay() {
        var calendar = utc; calendar.timeZone = TimeZone(identifier: "Europe/Samara")!
        let store = StatisticsStore(path: ":memory:")
        let start = date("2026-10-20T19:59:50Z")
        store.record(spans: [ActivitySpan(start: start, end: start.addingTimeInterval(20))], calendar: calendar)
        XCTAssertEqual(store.days().map(\.id), ["2026-10-21", "2026-10-20"])
        XCTAssertEqual(store.days().map(\.seconds), [10, 10])
    }
}
