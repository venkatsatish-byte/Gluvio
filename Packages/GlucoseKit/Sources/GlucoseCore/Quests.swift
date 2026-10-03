import Foundation

public enum QuestKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case checkBeforeMeals, logMeal, drinkWater

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .checkBeforeMeals: return "Check before meals"
        case .logMeal: return "Log a meal"
        case .drinkWater: return "Drink water"
        }
    }

    public var detail: String {
        switch self {
        case .checkBeforeMeals: return "Check your number before 2 meals"
        case .logMeal: return "Tell Gluvio what you ate"
        case .drinkWater: return "Drink 4 glasses of water"
        }
    }

    public var target: Int {
        switch self {
        case .checkBeforeMeals: return 2
        case .logMeal: return 1
        case .drinkWater: return 4
        }
    }

    public var systemImage: String {
        switch self {
        case .checkBeforeMeals: return "drop.circle.fill"
        case .logMeal: return "fork.knife.circle.fill"
        case .drinkWater: return "waterbottle.fill"
        }
    }
}

public struct QuestStatus: Identifiable, Equatable, Sendable {
    public var kind: QuestKind
    public var current: Int
    public var id: QuestKind { kind }
    public var target: Int { kind.target }
    public var isDone: Bool { current >= target }
    public var progress: Double { min(1, Double(current) / Double(target)) }
}

public struct DayRecord: Codable, Equatable, Sendable {
    public var checks: Int
    public var waterGlasses: Int
    public var completed: Set<QuestKind>

    public init(checks: Int = 0, waterGlasses: Int = 0, completed: Set<QuestKind> = []) {
        self.checks = checks
        self.waterGlasses = waterGlasses
        self.completed = completed
    }

    /// One star per quest, plus a bonus star for finishing all of them.
    public var stars: Int {
        completed.count + (completed.count == QuestKind.allCases.count ? 1 : 0)
    }
}

/// A child's quest history and chosen mascot look. Stored on this device only.
public struct RewardsLedger: Codable, Equatable, Sendable {
    public var days: [String: DayRecord]
    public var equippedColor: String
    public var equippedHat: String
    public var equippedBackground: String

    public init(days: [String: DayRecord] = [:], equippedColor: String = "sunshine",
                equippedHat: String = "none", equippedBackground: String = "meadow") {
        self.days = days
        self.equippedColor = equippedColor
        self.equippedHat = equippedHat
        self.equippedBackground = equippedBackground
    }

    public static func key(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public func record(on date: Date, calendar: Calendar = .current) -> DayRecord {
        days[Self.key(for: date, calendar: calendar)] ?? DayRecord()
    }

    public mutating func addCheck(on date: Date, calendar: Calendar = .current) {
        days[Self.key(for: date, calendar: calendar), default: DayRecord()].checks += 1
    }

    public mutating func addWater(on date: Date, calendar: Calendar = .current) {
        days[Self.key(for: date, calendar: calendar), default: DayRecord()].waterGlasses += 1
    }

    /// Saves which quests are done today. Finished quests stay finished.
    public mutating func update(with statuses: [QuestStatus], on date: Date, calendar: Calendar = .current) {
        let key = Self.key(for: date, calendar: calendar)
        var record = days[key] ?? DayRecord()
        for status in statuses where status.isDone { record.completed.insert(status.kind) }
        days[key] = record
    }

    public var totalStars: Int { days.values.reduce(0) { $0 + $1.stars } }

    public func stars(from start: Date, to end: Date, calendar: Calendar = .current) -> Int {
        var total = 0
        var day = calendar.startOfDay(for: start)
        while day <= end {
            total += record(on: day, calendar: calendar).stars
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return total
    }

    /// A streak day has at least 2 quests done. Today counts once it qualifies;
    /// until then the streak runs through yesterday, so it never drops mid-day.
    public func currentStreak(today: Date, calendar: Calendar = .current) -> Int {
        var day = calendar.startOfDay(for: today)
        if record(on: day, calendar: calendar).completed.count < 2 {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while record(on: day, calendar: calendar).completed.count >= 2 {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    public func bestStreak(calendar: Calendar = .current) -> Int {
        let qualifying = days.filter { $0.value.completed.count >= 2 }.keys.sorted()
        var best = 0
        var run = 0
        var previous: Date?
        let parser = DateFormatter()
        parser.calendar = calendar
        parser.timeZone = calendar.timeZone
        parser.dateFormat = "yyyy-MM-dd"
        for key in qualifying {
            guard let date = parser.date(from: key) else { continue }
            if let previous, calendar.dateComponents([.day], from: previous, to: date).day == 1 {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = date
        }
        return best
    }
}

public enum QuestEngine {
    /// Today's quests. "Checks" are taps on "Check my number" or readings logged
    /// in Kid Mode; meals come from the meal log; water from Kid Mode taps.
    public static func statuses(on day: Date, meals: [MealEvent], ledger: RewardsLedger,
                                calendar: Calendar = .current) -> [QuestStatus] {
        let record = ledger.record(on: day, calendar: calendar)
        let mealCount = meals.filter { calendar.isDate($0.date, inSameDayAs: day) }.count
        return [
            QuestStatus(kind: .checkBeforeMeals, current: record.checks),
            QuestStatus(kind: .logMeal, current: mealCount),
            QuestStatus(kind: .drinkWater, current: record.waterGlasses),
        ]
    }
}

public struct RewardItem: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable { case color, hat, background }
    public enum Requirement: Equatable, Sendable {
        case free
        case stars(Int)
        case streak(Int)
    }

    public var id: String
    public var kind: Kind
    public var name: String
    public var requirement: Requirement

    public var requirementText: String {
        switch requirement {
        case .free: return "Ready to use"
        case .stars(let n): return "Earn \(n) stars"
        case .streak(let n): return "Reach a \(n)-day streak"
        }
    }
}

public enum RewardCatalog {
    public static let items: [RewardItem] = [
        RewardItem(id: "sunshine", kind: .color, name: "Sunshine", requirement: .free),
        RewardItem(id: "mint", kind: .color, name: "Mint", requirement: .stars(5)),
        RewardItem(id: "ocean", kind: .color, name: "Ocean", requirement: .stars(12)),
        RewardItem(id: "berry", kind: .color, name: "Berry", requirement: .stars(20)),
        RewardItem(id: "galaxy", kind: .color, name: "Galaxy", requirement: .streak(7)),
        RewardItem(id: "none", kind: .hat, name: "No hat", requirement: .free),
        RewardItem(id: "cap", kind: .hat, name: "Cap", requirement: .streak(3)),
        RewardItem(id: "party", kind: .hat, name: "Party hat", requirement: .stars(15)),
        RewardItem(id: "crown", kind: .hat, name: "Crown", requirement: .streak(7)),
        RewardItem(id: "wizard", kind: .hat, name: "Wizard hat", requirement: .stars(30)),
        RewardItem(id: "meadow", kind: .background, name: "Meadow", requirement: .free),
        RewardItem(id: "beach", kind: .background, name: "Beach", requirement: .stars(10)),
        RewardItem(id: "space", kind: .background, name: "Space", requirement: .streak(5)),
        RewardItem(id: "snow", kind: .background, name: "Snow day", requirement: .stars(25)),
    ]

    /// Uses the best streak ever, so nothing unlocked is ever taken away.
    public static func isUnlocked(_ item: RewardItem, stars: Int, bestStreak: Int) -> Bool {
        switch item.requirement {
        case .free: return true
        case .stars(let n): return stars >= n
        case .streak(let n): return bestStreak >= n
        }
    }

    public static func nextUnlock(stars: Int, bestStreak: Int) -> RewardItem? {
        items.filter { !isUnlocked($0, stars: stars, bestStreak: bestStreak) }
            .min { remaining($0, stars: stars, bestStreak: bestStreak) < remaining($1, stars: stars, bestStreak: bestStreak) }
    }

    static func remaining(_ item: RewardItem, stars: Int, bestStreak: Int) -> Int {
        switch item.requirement {
        case .free: return 0
        case .stars(let n): return n - stars
        case .streak(let n): return (n - bestStreak) * 3
        }
    }

    public static func item(_ id: String) -> RewardItem? { items.first { $0.id == id } }
}
