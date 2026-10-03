import Foundation

public enum DayPart: String, CaseIterable, Sendable {
    case overnight, morning, afternoon, evening

    public init(date: Date, calendar: Calendar = .current) {
        switch calendar.component(.hour, from: date) {
        case 0..<6: self = .overnight
        case 6..<12: self = .morning
        case 12..<18: self = .afternoon
        default: self = .evening
        }
    }

    public var title: String {
        switch self {
        case .overnight: return "overnight (midnight–6 am)"
        case .morning: return "in the morning"
        case .afternoon: return "in the afternoon"
        case .evening: return "in the evening"
        }
    }
}

/// A parent's weekly overview: patterns in the readings and quest progress.
/// It describes what happened; it never says what to change.
public struct WeeklySummary: Sendable {
    public var period: DateInterval
    public var stats: GlucoseStats
    public var lowsByPart: [DayPart: Int]
    public var highsByPart: [DayPart: Int]
    public var mealsLogged: Int
    public var insulinLogged: Int
    public var starsThisWeek: Int
    public var streak: Int
    public var highlights: [String]

    public init(child: ChildProfile, samples: [GlucoseSample], meals: [MealEvent], insulin: [InsulinDose],
                ledger: RewardsLedger, now: Date = .now, calendar: Calendar = .current) {
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        let period = DateInterval(start: start, end: now)
        let week = samples.filter { period.contains($0.date) }.sorted { $0.date < $1.date }
        let stats = GlucoseAnalytics.stats(for: week, in: period, targets: child.targets)

        // Count episodes (not readings) by part of day, using the episode's first reading.
        func episodeStarts(_ predicate: (Double) -> Bool) -> [DayPart: Int] {
            var counts: [DayPart: Int] = [:]
            var previousHit: Date?
            var inEpisode = false
            for sample in week {
                if predicate(sample.mgdL) {
                    let gapTooLong = previousHit.map { sample.date.timeIntervalSince($0) > 30 * 60 } ?? true
                    if !inEpisode || gapTooLong { counts[DayPart(date: sample.date, calendar: calendar), default: 0] += 1 }
                    previousHit = sample.date
                    inEpisode = true
                } else {
                    inEpisode = false
                }
            }
            return counts
        }
        let lows = episodeStarts { $0 < child.targets.low }
        let highs = episodeStarts { $0 > child.targets.high }

        self.period = period
        self.stats = stats
        lowsByPart = lows
        highsByPart = highs
        mealsLogged = meals.filter { period.contains($0.date) }.count
        insulinLogged = insulin.filter { period.contains($0.date) }.count
        starsThisWeek = ledger.stars(from: start, to: now, calendar: calendar)
        streak = ledger.currentStreak(today: now, calendar: calendar)

        var notes: [String] = []
        if let tir = stats.inRangeFraction {
            notes.append("\(stats.inRangeLabel): \(Int((tir * 100).rounded()))% this week.")
        } else {
            notes.append("No readings this week yet.")
        }
        let totalLows = lows.values.reduce(0, +)
        if totalLows > 0, let top = lows.max(by: { $0.value < $1.value }) {
            notes.append(totalLows == 1
                ? "1 low, \(top.key.title)."
                : "\(totalLows) lows. Most happened \(top.key.title) (\(top.value) of \(totalLows)).")
        } else if stats.readingCount > 0 {
            notes.append("No lows this week.")
        }
        let totalHighs = highs.values.reduce(0, +)
        if totalHighs > 0, let top = highs.max(by: { $0.value < $1.value }) {
            notes.append("\(totalHighs) high\(totalHighs == 1 ? "" : "s"). Most common \(top.key.title).")
        }
        notes.append("Quests: \(starsThisWeek) star\(starsThisWeek == 1 ? "" : "s") this week, \(streak)-day streak.")
        highlights = notes
    }
}
