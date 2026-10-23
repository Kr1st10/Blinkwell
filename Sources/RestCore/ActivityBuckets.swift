import Foundation

public struct ActivitySpan {
    public let start: Date
    public let end: Date
    public init(start: Date, end: Date) { self.start = start; self.end = end }
}

public struct ActivityAllocation {
    public let day: String
    public let bucketStart: Date
    public let seconds: TimeInterval
}

public enum ActivityBuckets {
    public static let width: TimeInterval = 900
    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
    public static func split(_ span: ActivitySpan, calendar: Calendar = .current) -> [ActivityAllocation] {
        guard span.start.timeIntervalSince1970.isFinite, span.end.timeIntervalSince1970.isFinite,
              span.end > span.start else { return [] }
        var cursor = span.start
        var result: [ActivityAllocation] = []
        while cursor < span.end {
            let bucket = Date(timeIntervalSince1970: floor(cursor.timeIntervalSince1970 / width) * width)
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: cursor)) else { break }
            let end = min(span.end, min(bucket.addingTimeInterval(width), tomorrow))
            guard end > cursor else { break }
            result.append(ActivityAllocation(day: dayKey(cursor, calendar: calendar), bucketStart: bucket,
                                             seconds: end.timeIntervalSince(cursor)))
            cursor = end
        }
        return result
    }
}
