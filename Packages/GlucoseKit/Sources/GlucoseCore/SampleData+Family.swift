import Foundation

/// Synthetic data for testing the family features in the simulator: two
/// children with lows, highs, logged insulin and quest history. Fictional,
/// and never written to Apple Health.
public enum SampleFamily {
    public struct ChildData: Sendable {
        public var child: ChildProfile
        public var samples: [GlucoseSample]
        public var meals: [MealEvent]
        public var insulin: [InsulinDose]
        public var ledger: RewardsLedger
    }

    /// For forcing the latest reading, to test each mascot mood and alert.
    public enum LatestOverride: String, Sendable {
        case low, veryLow, high, inRange
    }

    public static let parentPIN = "1234"

    public static func make(now: Date = .now, latest: LatestOverride? = nil, calendar: Calendar = .current) -> [ChildData] {
        // Stands in for what a parent types from the care team's plan. It is
        // deliberately general: Gluvio never ships its own treatment steps.
        let carePlanLow = """
            (Sample plan: a parent replaces this with the care team's steps.)
            Tell a grown-up you feel low.
            Use your low kit the way your care plan says.
            Sit down and rest.
            Check again when the timer ends.
            Still low? Call Mom or Dad.
            """
        let carePlanHigh = """
            (Sample plan: a parent replaces this with the care team's steps.)
            Tell a grown-up your number.
            Drink some water.
            Grown-up: follow the high plan from the clinic letter.
            """
        let contacts = [
            EmergencyContact(name: "Priya (Mom)", relation: "Parent", phone: "+1 555 0100"),
            EmergencyContact(name: "Ravi (Dad)", relation: "Parent", phone: "+1 555 0101"),
            EmergencyContact(name: "Dr. Shah's clinic", relation: "Diabetes team", phone: "+1 555 0199"),
        ]
        let aarav = ChildProfile(
            name: "Aarav", age: 8, avatar: AvatarStyle(colorIndex: 2, symbol: "bolt.fill"),
            carePlanLow: carePlanLow, carePlanHigh: carePlanHigh, emergencyContacts: contacts, usesCGM: true
        )
        let meera = ChildProfile(
            name: "Meera", age: 12, avatar: AvatarStyle(colorIndex: 5, symbol: "moon.stars.fill"),
            carePlanLow: carePlanLow, carePlanHigh: carePlanHigh, recheckMinutes: 15,
            emergencyContacts: contacts, usesCGM: false
        )
        return [
            child(aarav, continuous: true, seed: 11, now: now, latest: latest, calendar: calendar),
            child(meera, continuous: false, seed: 23, now: now, latest: nil, calendar: calendar),
        ]
    }

    static func child(_ profile: ChildProfile, continuous: Bool, seed: UInt64, now: Date,
                      latest: LatestOverride?, calendar: Calendar) -> ChildData {
        var rng = SplitMix64(seed: seed)
        let days = 14
        let today = calendar.startOfDay(for: now)
        var meals: [MealEvent] = []
        var insulin: [InsulinDose] = []
        var bumps: [(Date, Double)] = []

        for offset in stride(from: -(days - 1), through: 0, by: 1) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let plan: [(MealKind, Double, String)] = [
                (.breakfast, 7.6, "Idli and sambar"), (.lunch, 12.4, "Chapati and dal"),
                (.snack, 16.0, "Banana"), (.dinner, 19.0, "Rice and curry"),
            ]
            for (kind, hour, name) in plan {
                let date = day.addingTimeInterval((hour + rng.uniform(-0.4, 0.4)) * 3600)
                guard date <= now else { continue }
                let carbs = (kind == .snack ? 25 : 45 + rng.uniform(-10, 15)).rounded()
                meals.append(MealEvent(date: date, kind: kind, name: name, carbsGrams: carbs))
                // Logged insulin for the sample history. These amounts are random
                // sample values, not calculated from carbs.
                if kind != .snack {
                    insulin.append(InsulinDose(date: date.addingTimeInterval(-10 * 60),
                                               units: (rng.uniform(2, 6) * 2).rounded() / 2, kind: .rapid))
                }
                bumps.append((date, carbs * 1.9))
            }
            let longDate = day.addingTimeInterval(20.5 * 3600)
            if longDate <= now { insulin.append(InsulinDose(date: longDate, units: 10, kind: .long)) }
            // Some nights dip low, some evenings run high.
            if rng.uniform(0, 1) < 0.35 { bumps.append((day.addingTimeInterval(2.5 * 3600), -85)) }
            if rng.uniform(0, 1) < 0.4 { bumps.append((day.addingTimeInterval(20 * 3600), 95)) }
        }
        if let lowDay = calendar.date(byAdding: .day, value: -2, to: today) {
            bumps.append((lowDay.addingTimeInterval(3 * 3600), -110))   // a very low night
        }
        if let highDay = calendar.date(byAdding: .day, value: -1, to: today) {
            bumps.append((highDay.addingTimeInterval(15 * 3600), 160))  // a very high afternoon
        }

        func value(at date: Date, noise: Double) -> Double {
            var v = 145.0
            for (start, size) in bumps {
                let minutes = date.timeIntervalSince(start) / 60
                guard minutes > 0, minutes < 300 else { continue }
                v += size * (minutes / 60) * exp(1 - minutes / 60)
            }
            return min(400, max(40, v + noise)).rounded()
        }

        var samples: [GlucoseSample] = []
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        if continuous {
            var noise = 0.0
            var t = start
            while t <= now {
                noise = noise * 0.8 + rng.uniform(-5, 5)
                samples.append(GlucoseSample(date: t, mgdL: value(at: t, noise: noise), source: .cgm, sourceName: "Sample CGM"))
                t = t.addingTimeInterval(5 * 60)
            }
        } else {
            for offset in 0..<days {
                guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
                for (hour, context) in [(7.2, ReadingContext.fasting), (12.2, .beforeMeal), (18.8, .beforeMeal), (21.5, .bedtime)] {
                    let date = day.addingTimeInterval((hour + rng.uniform(-0.3, 0.3)) * 3600)
                    guard date <= now else { continue }
                    samples.append(GlucoseSample(date: date, mgdL: value(at: date, noise: rng.uniform(-8, 8)),
                                                 context: context, source: .manual, sourceName: "Gluvio"))
                }
            }
        }

        if let latest {
            let mgdL: Double
            switch latest {
            case .low: mgdL = 64
            case .veryLow: mgdL = 49
            case .high: mgdL = 236
            case .inRange: mgdL = 118
            }
            // Make it unambiguously the newest reading.
            samples.removeAll { $0.date > now.addingTimeInterval(-5 * 60) }
            samples.append(GlucoseSample(date: now.addingTimeInterval(-60), mgdL: mgdL, source: continuous ? .cgm : .manual,
                                         sourceName: continuous ? "Sample CGM" : "Gluvio"))
        }

        // Quest history: most days earn stars, a few don't, and today is in progress.
        var ledger = RewardsLedger()
        for offset in 1..<days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = RewardsLedger.key(for: day, calendar: calendar)
            let roll = rng.uniform(0, 1)
            let completed: Set<QuestKind> = offset <= 4 || roll > 0.35
                ? (roll > 0.5 ? Set(QuestKind.allCases) : [.checkBeforeMeals, .logMeal])
                : (roll > 0.15 ? [.logMeal] : [])
            ledger.days[key] = DayRecord(checks: completed.contains(.checkBeforeMeals) ? 2 : 0,
                                         waterGlasses: completed.contains(.drinkWater) ? 4 : 1,
                                         completed: completed)
        }
        ledger.days[RewardsLedger.key(for: now, calendar: calendar)] = DayRecord(checks: 1, waterGlasses: 2)
        ledger.equippedColor = profile.name == "Aarav" ? "mint" : "berry"
        ledger.equippedHat = profile.name == "Aarav" ? "cap" : "none"

        return ChildData(child: profile, samples: samples, meals: meals.sorted { $0.date < $1.date },
                         insulin: insulin.sorted { $0.date < $1.date }, ledger: ledger)
    }
}
