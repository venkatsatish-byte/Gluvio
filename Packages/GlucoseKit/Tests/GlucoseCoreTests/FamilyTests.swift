import XCTest
@testable import GlucoseCore

final class SafetyRuleTests: XCTestCase {
    func testDisclaimerTextIsExact() {
        XCTAssertEqual(SafetyCopy.shortDisclaimer, "Gluvio is not a medical device. Follow your care team's plan.")
        XCTAssertTrue(SafetyCopy.disclaimerPoints.contains(SafetyCopy.shortDisclaimer))
    }

    /// Insulin is log-only: no copy may offer to calculate or suggest amounts.
    func testInsulinCopyNeverOffersCalculation() {
        let text = InsulinCopy.logOnlyNotice.lowercased()
        for phrase in ["calculat", "recommend", "you should take", "correction", "ratio", "bolus wizard"] {
            XCTAssertFalse(text.contains(phrase), "“\(phrase)” in insulin copy")
        }
        XCTAssertTrue(text.contains("log only"))
    }

    /// Everything a child sees must be supportive, never shaming.
    func testKidCopyNeverShames() {
        var copy: [String] = []
        for band in GlucoseBand.allCases {
            let status = FriendlyStatus(band: band, isStale: false)
            copy += [status.title, status.message]
        }
        copy += [FriendlyStatus.timeToCheck.title, FriendlyStatus.timeToCheck.message]
        copy += MascotMood.allCases.map(\.line)
        copy += QuestKind.allCases.flatMap { [$0.title, $0.detail] }
        copy += RewardCatalog.items.flatMap { [$0.name, $0.requirementText] }
        copy += CarbDetective.foods.flatMap { [$0.name, $0.funFact] }
        for text in copy {
            for word in KidCopy.bannedWords {
                XCTAssertNil(text.lowercased().range(of: "\\b\(word)\\b", options: .regularExpression),
                             "“\(word)” in kid copy: \(text)")
            }
        }
    }

    func testChildAlertsNeverAdvise() {
        let child = ChildProfile(name: "Asha", age: 9)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        for mgdL in [45.0, 62, 300, 120] {
            var settings = child
            settings.alerts.onlyOutOfRange = false
            guard let alert = AlertPolicy.alert(for: GlucoseSample(date: now, mgdL: mgdL, source: .cgm), child: settings, now: now) else {
                return XCTFail("expected alert for \(mgdL)")
            }
            let text = (alert.title + " " + alert.body).lowercased()
            for phrase in ["give ", "take ", "eat ", "units", "inject", "dose"] {
                XCTAssertFalse(text.contains(phrase), "“\(phrase)” in alert: \(text)")
            }
        }
    }
}

final class FamilyModelTests: XCTestCase {
    func testCarePlanStepsStripBulletsAndNumbers() {
        let text = """
            1. Check again
            2) Use the low kit
              - Sit down
            • Call Mom

            """
        XCTAssertEqual(CarePlan.steps(from: text), ["Check again", "Use the low kit", "Sit down", "Call Mom"])
        XCTAssertEqual(CarePlan.steps(from: "   "), [])
    }

    func testOnlyOneChildLinkedToAppleHealth() {
        var household = Household()
        let a = ChildProfile(name: "A", age: 7, usesAppleHealth: true)
        let b = ChildProfile(name: "B", age: 9, usesAppleHealth: true)
        household.upsert(a)
        household.upsert(b)
        XCTAssertEqual(household.healthLinkedChildID, b.id)
        XCTAssertEqual(household.children.filter(\.usesAppleHealth).count, 1)
        XCTAssertEqual(household.selectedChildID, a.id)
        household.kidModeChildID = b.id
        household.remove(b.id)
        XCTAssertNil(household.kidModeChildID)
        XCTAssertNil(household.healthLinkedChildID)
    }

    func testPIN() {
        XCTAssertTrue(PINHasher.isValid("0429"))
        XCTAssertFalse(PINHasher.isValid("12a4"))
        XCTAssertFalse(PINHasher.isValid("12345"))
        let record = PINHasher.makeRecord(pin: "0429")
        XCTAssertTrue(PINHasher.verify("0429", against: record))
        XCTAssertFalse(PINHasher.verify("0428", against: record))
        XCTAssertNotEqual(record, PINHasher.makeRecord(pin: "0429"), "salt makes each record different")
    }

    func testHouseholdRoundTrips() throws {
        var household = Household()
        household.upsert(ChildProfile(name: "Aarav", age: 8, carePlanLow: "Tell a grown-up"))
        let data = try JSONEncoder().encode(household)
        XCTAssertEqual(try JSONDecoder().decode(Household.self, from: data), household)
    }

    func testInsulinUnitsText() {
        XCTAssertEqual(InsulinDose(date: Date(), units: 4.5, kind: .rapid).unitsText, "4.5 u")
        XCTAssertEqual(InsulinDose(date: Date(), units: 12, kind: .long).unitsText, "12 u")
    }
}

final class KidModeTests: XCTestCase {
    func testFriendlyStatus() {
        XCTAssertEqual(FriendlyStatus(band: .inRange, isStale: false).title, "In the zone!")
        XCTAssertEqual(FriendlyStatus(band: .high, isStale: false).title, "Climbing a hill")
        XCTAssertEqual(FriendlyStatus(band: .low, isStale: false).title, "Running low")
        XCTAssertEqual(FriendlyStatus(band: .inRange, isStale: true), .timeToCheck)
        XCTAssertEqual(FriendlyStatus(band: nil, isStale: false), .timeToCheck)
        XCTAssertTrue(FriendlyStatus(band: .urgentLow, isStale: false).needsGrownUp)
    }

    func testMascotMood() {
        XCTAssertEqual(MascotMood.current(latestBand: .inRange, isStale: false, todayInRange: 0.2), .happy)
        XCTAssertEqual(MascotMood.current(latestBand: .low, isStale: false, todayInRange: 0.9), .sleepy)
        XCTAssertEqual(MascotMood.current(latestBand: .urgentHigh, isStale: false, todayInRange: 0.9), .wobbly)
        XCTAssertEqual(MascotMood.current(latestBand: .low, isStale: true, todayInRange: 0.8), .happy)
        XCTAssertEqual(MascotMood.current(latestBand: nil, isStale: true, todayInRange: nil), .curious)
    }
}

final class QuestTests: XCTestCase {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    let today = Date(timeIntervalSince1970: 1_800_000_000)

    func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today)! }

    func testStatusesFromLedgerAndMeals() {
        var ledger = RewardsLedger()
        ledger.addCheck(on: today, calendar: calendar)
        ledger.addCheck(on: today, calendar: calendar)
        for _ in 0..<3 { ledger.addWater(on: today, calendar: calendar) }
        let meals = [MealEvent(date: today, kind: .lunch, carbsGrams: 40)]
        let statuses = QuestEngine.statuses(on: today, meals: meals, ledger: ledger, calendar: calendar)
        XCTAssertEqual(statuses.map(\.isDone), [true, true, false])
        XCTAssertEqual(statuses[2].current, 3)
        ledger.update(with: statuses, on: today, calendar: calendar)
        XCTAssertEqual(ledger.record(on: today, calendar: calendar).stars, 2)
        ledger.addWater(on: today, calendar: calendar)
        ledger.update(with: QuestEngine.statuses(on: today, meals: meals, ledger: ledger, calendar: calendar), on: today, calendar: calendar)
        XCTAssertEqual(ledger.record(on: today, calendar: calendar).stars, 4, "3 quests + bonus star")
    }

    func testStreaksAndUnlocksNeverGoBackwards() {
        var ledger = RewardsLedger()
        for offset in [-4, -3, -2, -1] {
            ledger.days[RewardsLedger.key(for: day(offset), calendar: calendar)] = DayRecord(completed: [.logMeal, .checkBeforeMeals])
        }
        // Today has nothing yet: the streak still counts through yesterday.
        XCTAssertEqual(ledger.currentStreak(today: today, calendar: calendar), 4)
        XCTAssertEqual(ledger.bestStreak(calendar: calendar), 4)
        // A missed day resets the current streak but not the best one.
        XCTAssertEqual(ledger.currentStreak(today: day(2), calendar: calendar), 0)
        XCTAssertEqual(ledger.bestStreak(calendar: calendar), 4)

        let cap = RewardCatalog.item("cap")!
        let crown = RewardCatalog.item("crown")!
        XCTAssertTrue(RewardCatalog.isUnlocked(cap, stars: 0, bestStreak: ledger.bestStreak(calendar: calendar)))
        XCTAssertFalse(RewardCatalog.isUnlocked(crown, stars: 0, bestStreak: 4))
        XCTAssertNotNil(RewardCatalog.nextUnlock(stars: 0, bestStreak: 0))
        XCTAssertTrue(RewardCatalog.items.filter { $0.requirement == .free }.count >= 3)
    }
}

final class CarbDetectiveTests: XCTestCase {
    func testRangesAndFoods() {
        XCTAssertEqual(CarbRange(grams: 9), .under10)
        XCTAssertEqual(CarbRange(grams: 10), .from10to25)
        XCTAssertEqual(CarbRange(grams: 25), .from10to25)
        XCTAssertEqual(CarbRange(grams: 26), .from26to40)
        XCTAssertEqual(CarbRange(grams: 41), .over40)
        let names = Set(CarbDetective.foods.map(\.name))
        XCTAssertEqual(names.count, CarbDetective.foods.count, "names are unique")
        for indian in ["Idli", "Plain dosa", "Chapati", "Rice", "Banana"] {
            XCTAssertTrue(names.contains(indian), indian)
        }
        XCTAssertEqual(Set(CarbDetective.foods.map(\.range)).count, CarbRange.allCases.count, "every range is used")
        let next = CarbDetective.nextFood(excluding: ["Idli"], seed: 0)
        XCTAssertNotEqual(next.name, "Idli")
    }
}

final class AlertPolicyTests: XCTestCase {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: hour, minute: minute))!
    }

    func testThresholdsQuietHoursAndOnlyOutOfRange() {
        var child = ChildProfile(name: "Aarav Kumar", age: 8)
        child.alerts.quietHoursEnabled = true
        child.alerts.quietStart = 21 * 60 + 30
        child.alerts.quietEnd = 6 * 60 + 30
        func alert(_ mgdL: Double, at date: Date) -> ChildAlert? {
            AlertPolicy.alert(for: GlucoseSample(date: date, mgdL: mgdL, source: .cgm), child: child, now: date, calendar: calendar)
        }
        XCTAssertEqual(alert(65, at: at(14))?.kind, .low)
        XCTAssertEqual(alert(65, at: at(14))?.title, "Aarav is low")
        XCTAssertEqual(alert(280, at: at(14))?.kind, .high)
        XCTAssertNil(alert(140, at: at(14)), "in range, only out-of-range alerts")
        XCTAssertNil(alert(65, at: at(23)), "quiet hours silence ordinary lows")
        XCTAssertNil(alert(280, at: at(3)), "quiet hours wrap past midnight")
        XCTAssertEqual(alert(48, at: at(3))?.kind, .urgentLow, "very lows always alert")
        XCTAssertEqual(alert(65, at: at(6, 30))?.kind, .low, "quiet hours end on time")

        child.alerts.onlyOutOfRange = false
        XCTAssertEqual(alert(140, at: at(14))?.kind, .update)
        child.alerts.isEnabled = false
        XCTAssertNil(alert(48, at: at(14)))
    }

    func testStaleReadingsDontAlert() {
        let child = ChildProfile(name: "A", age: 8)
        let now = at(12)
        let old = GlucoseSample(date: now.addingTimeInterval(-2 * 3600), mgdL: 50, source: .cgm)
        XCTAssertNil(AlertPolicy.alert(for: old, child: child, now: now, calendar: calendar))
    }
}

final class SampleFamilyTests: XCTestCase {
    func testSampleFamilyCoversLowsHighsAndQuests() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let family = SampleFamily.make(now: now, latest: .low, calendar: calendar)
        XCTAssertEqual(family.count, 2)
        let aarav = family[0]
        let week = DateInterval(start: now.addingTimeInterval(-7 * 86_400), end: now)
        let stats = GlucoseAnalytics.stats(for: aarav.samples, in: week, targets: aarav.child.targets)
        XCTAssertGreaterThan(stats.lowEpisodes, 0)
        XCTAssertGreaterThan(stats.highEpisodes, 0)
        XCTAssertLessThan(stats.bandFractions[.urgentLow, default: 0] + stats.bandFractions[.urgentHigh, default: 0], 0.5)
        XCTAssertEqual(aarav.samples.last?.mgdL, 64)
        XCTAssertFalse(aarav.insulin.isEmpty)
        XCTAssertTrue(aarav.insulin.allSatisfy { InsulinDose.plausibleUnits.contains($0.units) })
        XCTAssertGreaterThan(aarav.ledger.totalStars, 0)
        XCTAssertFalse(aarav.child.carePlanLowSteps.isEmpty)
        XCTAssertTrue(family[1].samples.allSatisfy { $0.source == .manual })

        let summary = WeeklySummary(child: aarav.child, samples: aarav.samples, meals: aarav.meals,
                                    insulin: aarav.insulin, ledger: aarav.ledger, now: now, calendar: calendar)
        XCTAssertGreaterThanOrEqual(summary.highlights.count, 3)
        XCTAssertGreaterThan(summary.starsThisWeek, 0)
        XCTAssertGreaterThan(summary.lowsByPart.values.reduce(0, +), 0)
    }
}
