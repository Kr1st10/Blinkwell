import Foundation
import CSQLite
import RestCore

public struct DaySummary: Identifiable {
    public var id: String
    public var seconds: Double
    public var eyes: Int
    public var body: Int
}
public struct ActivityBin: Identifiable {
    public var id: Date { start }
    public let start: Date
    public let seconds: Double
}
public struct BreakEvent: Identifiable {
    public let id: Int64
    public let date: Date
    public let kind: BreakKind
}
public struct DayDetails {
    public let summary: DaySummary?
    public let bins: [ActivityBin]
    public let events: [BreakEvent]
    public var locatedSeconds: Double { bins.reduce(0) { $0 + $1.seconds } }
    public var legacySeconds: Double { max(0, (summary?.seconds ?? 0) - locatedSeconds) }
}

public final class StatisticsStore {
    private var db: OpaquePointer?
    public private(set) var error: String?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private enum Value { case text(String), number(Double) }

    public init(path: String? = nil) {
        do {
            let file: String
            if let path { file = path }
            else {
                let folder = try FileManager.default.url(for: .applicationSupportDirectory,
                    in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Pause")
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                file = folder.appendingPathComponent("statistics.sqlite").path
            }
            guard sqlite3_open(file, &db) == SQLITE_OK else { error = "Не удалось открыть статистику"; return }
            sqlite3_busy_timeout(db, 2000)
            let schema = """
                BEGIN IMMEDIATE;
                CREATE TABLE IF NOT EXISTS days (day TEXT PRIMARY KEY, seconds REAL NOT NULL DEFAULT 0, eyes INTEGER NOT NULL DEFAULT 0, body INTEGER NOT NULL DEFAULT 0);
                CREATE TABLE IF NOT EXISTS activity_bins (start REAL PRIMARY KEY, seconds REAL NOT NULL DEFAULT 0);
                CREATE TABLE IF NOT EXISTS break_events (id INTEGER PRIMARY KEY, occurred REAL NOT NULL, kind TEXT NOT NULL);
                CREATE INDEX IF NOT EXISTS break_events_date ON break_events(occurred);
                PRAGMA user_version=2;
                COMMIT;
                """
            if sqlite3_exec(db, schema, nil, nil, nil) != SQLITE_OK {
                sqlite3_exec(db, "ROLLBACK", nil, nil, nil); error = "Не удалось обновить статистику"
            }
        } catch { self.error = "Не удалось создать хранилище статистики" }
    }
    deinit { sqlite3_close(db) }
    private func prepare(_ sql: String, _ values: [Value]) -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            error = "Не удалось прочитать или сохранить статистику"; return nil
        }
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let status: Int32
            switch value {
            case .text(let string): status = sqlite3_bind_text(statement, index, string, -1, transient)
            case .number(let number): status = sqlite3_bind_double(statement, index, number)
            }
            guard status == SQLITE_OK else { sqlite3_finalize(statement); error = "Не удалось сохранить статистику"; return nil }
        }
        return statement
    }
    private func run(_ sql: String, _ values: [Value] = []) -> Bool {
        guard let statement = prepare(sql, values) else { return false }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_DONE else { error = "Не удалось сохранить статистику"; return false }
        return true
    }
    private func transaction(_ body: () -> Bool) -> Bool {
        guard run("BEGIN IMMEDIATE") else { return false }
        guard body(), run("COMMIT") else { _ = run("ROLLBACK"); return false }
        error = nil; return true
    }
    @discardableResult public func record(spans: [ActivitySpan], calendar: Calendar = .current) -> Bool {
        var byDay: [String: Double] = [:]
        var byBin: [Date: Double] = [:]
        for span in spans {
            for piece in ActivityBuckets.split(span, calendar: calendar) {
                byDay[piece.day, default: 0] += piece.seconds
                byBin[piece.bucketStart, default: 0] += piece.seconds
            }
        }
        guard !byDay.isEmpty else { return true }
        return transaction {
            for (day, seconds) in byDay {
                guard run("INSERT INTO days(day,seconds) VALUES(?,?) ON CONFLICT(day) DO UPDATE SET seconds=seconds+excluded.seconds", [.text(day), .number(seconds)]) else { return false }
            }
            for (date, seconds) in byBin {
                guard run("INSERT INTO activity_bins(start,seconds) VALUES(?,?) ON CONFLICT(start) DO UPDATE SET seconds=seconds+excluded.seconds", [.number(date.timeIntervalSince1970), .number(seconds)]) else { return false }
            }
            return true
        }
    }
    @discardableResult public func record(kind: BreakKind, date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let column = kind == .eyes ? "eyes" : "body"
        return transaction {
            run("INSERT INTO days(day,\(column)) VALUES(?,1) ON CONFLICT(day) DO UPDATE SET \(column)=\(column)+1", [.text(ActivityBuckets.dayKey(date, calendar: calendar))]) &&
            run("INSERT INTO break_events(occurred,kind) VALUES(?,?)", [.number(date.timeIntervalSince1970), .text(kind.rawValue)])
        }
    }
    public func days() -> [DaySummary] {
        guard let statement = prepare("SELECT day,seconds,eyes,body FROM days ORDER BY day DESC", []) else { return [] }
        defer { sqlite3_finalize(statement) }
        var result: [DaySummary] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let text = sqlite3_column_text(statement, 0) else { continue }
            result.append(DaySummary(id: String(cString: text), seconds: sqlite3_column_double(statement, 1),
                                     eyes: Int(sqlite3_column_int(statement, 2)), body: Int(sqlite3_column_int(statement, 3))))
        }
        return result
    }
    public func details(on date: Date, calendar: Calendar = .current) -> DayDetails {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        var values: [Double: Double] = [:]
        if let statement = prepare("SELECT start,seconds FROM activity_bins WHERE start>=? AND start<? ORDER BY start", [.number(start.timeIntervalSince1970), .number(end.timeIntervalSince1970)]) {
            while sqlite3_step(statement) == SQLITE_ROW { values[sqlite3_column_double(statement, 0)] = sqlite3_column_double(statement, 1) }
            sqlite3_finalize(statement)
        }
        var bins: [ActivityBin] = []
        var cursor = start
        while cursor < end {
            bins.append(ActivityBin(start: cursor, seconds: values[cursor.timeIntervalSince1970] ?? 0))
            cursor = cursor.addingTimeInterval(ActivityBuckets.width)
        }
        var events: [BreakEvent] = []
        if let statement = prepare("SELECT id,occurred,kind FROM break_events WHERE occurred>=? AND occurred<? ORDER BY occurred", [.number(start.timeIntervalSince1970), .number(end.timeIntervalSince1970)]) {
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let text = sqlite3_column_text(statement, 2), let kind = BreakKind(rawValue: String(cString: text)) else { continue }
                events.append(BreakEvent(id: sqlite3_column_int64(statement, 0), date: Date(timeIntervalSince1970: sqlite3_column_double(statement, 1)), kind: kind))
            }
            sqlite3_finalize(statement)
        }
        return DayDetails(summary: days().first { $0.id == ActivityBuckets.dayKey(date, calendar: calendar) }, bins: bins, events: events)
    }
    @discardableResult public func clear() -> Bool {
        transaction { run("DELETE FROM activity_bins") && run("DELETE FROM break_events") && run("DELETE FROM days") }
    }
}
