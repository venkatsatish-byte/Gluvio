import Foundation
import GlucoseCore

/// Family features: child profiles, Kid Mode, quests and parent alerts.
extension AppModel {
    // MARK: Profiles

    var isCaregiver: Bool { profile.accountType == .caregiver }

    var kidModeChild: ChildProfile? { household.kidModeChild }

    func child(_ id: UUID?) -> ChildProfile? { household.child(id) }

    /// The Health-linked child shares the main ("") storage with Apple Health;
    /// every other child has their own.
    func storageKey(for child: ChildProfile) -> String {
        child.usesAppleHealth ? "" : child.storageKey
    }

    func saveChild(_ child: ChildProfile) {
        household.upsert(child)
        if ledgers[child.id] == nil { ledgers[child.id] = sharedStore.loadLedger(for: child.id) }
    }

    func deleteChild(_ child: ChildProfile) {
        try? repository.deleteAll(profileKey: child.storageKey)
        sharedStore.removeLedger(for: child.id)
        ChildPhotoStore.delete(child.id)
        ledgers[child.id] = nil
        household.remove(child.id)
    }

    // MARK: Child data

    func readings(for child: ChildProfile) -> [GlucoseSample] {
        child.usesAppleHealth ? samples : childReadings[child.id] ?? []
    }

    func meals(for child: ChildProfile) -> [MealEvent] {
        child.usesAppleHealth ? meals : childMeals[child.id] ?? []
    }

    func insulin(for child: ChildProfile) -> [InsulinDose] {
        child.usesAppleHealth ? insulin : childInsulin[child.id] ?? []
    }

    func latest(for child: ChildProfile) -> GlucoseSample? {
        readings(for: child).max { $0.date < $1.date }
    }

    func reloadChildren() {
        let now = Date.now
        let start = now.addingTimeInterval(-31 * 86_400)
        let end = now.addingTimeInterval(3600)
        var readings: [UUID: [GlucoseSample]] = [:]
        var meals: [UUID: [MealEvent]] = [:]
        var insulin: [UUID: [InsulinDose]] = [:]
        for child in household.children where !child.usesAppleHealth {
            readings[child.id] = (try? repository.readings(from: start, to: end, profileKey: child.storageKey)) ?? []
            meals[child.id] = ((try? repository.meals(from: start, to: end, profileKey: child.storageKey)) ?? [])
            insulin[child.id] = (try? repository.insulin(from: start, to: end, profileKey: child.storageKey)) ?? []
        }
        childReadings = readings
        childMeals = meals
        childInsulin = insulin
    }

    // MARK: Logging for a child

    /// Logs a reading for a child. Readings typed in Kid Mode also count as a
    /// "check" for the daily quest.
    @discardableResult
    func logGlucose(for child: ChildProfile, mgdL: Double, date: Date = .now, context: ReadingContext,
                    note: String = "", fromKidMode: Bool = false) async -> Bool {
        let sample = GlucoseSample(date: date, mgdL: mgdL, context: context, source: .manual, sourceName: "Gluvio", note: note)
        do {
            if child.usesAppleHealth { try await health.save(sample) }
            try repository.upsert([sample], profileKey: storageKey(for: child))
        } catch {
            errorMessage = "The reading couldn't be saved. \(error.localizedDescription)"
            return false
        }
        reload()
        if fromKidMode { recordCheck(for: child) }
        notifyParentIfNeeded(about: sample, child: child)
        return true
    }

    @discardableResult
    func logMeal(_ meal: MealEvent, for child: ChildProfile) async -> Bool {
        do {
            try repository.save(meal: meal, photo: nil, profileKey: storageKey(for: child))
        } catch {
            errorMessage = "The meal couldn't be saved. \(error.localizedDescription)"
            return false
        }
        reload()
        if child.usesAppleHealth { try? await health.save(meal: meal) }
        updateQuests(for: child)
        return true
    }

    func addWater(for child: ChildProfile) async {
        var ledger = ledger(for: child)
        ledger.addWater(on: .now)
        save(ledger, for: child)
        updateQuests(for: child)
        if child.usesAppleHealth { try? await health.saveWater(milliliters: 250, at: .now) }
    }

    /// "Check my number" for a CGM user counts as a check, like a fingerstick.
    func recordCheck(for child: ChildProfile) {
        var ledger = ledger(for: child)
        ledger.addCheck(on: .now)
        save(ledger, for: child)
        updateQuests(for: child)
    }

    // MARK: Quests and rewards

    func ledger(for child: ChildProfile) -> RewardsLedger {
        ledgers[child.id] ?? RewardsLedger()
    }

    func questStatuses(for child: ChildProfile, on day: Date = .now) -> [QuestStatus] {
        QuestEngine.statuses(on: day, meals: meals(for: child), ledger: ledger(for: child))
    }

    func updateQuests(for child: ChildProfile) {
        var ledger = ledger(for: child)
        ledger.update(with: questStatuses(for: child), on: .now)
        save(ledger, for: child)
    }

    func equip(_ item: RewardItem, for child: ChildProfile) {
        var ledger = ledger(for: child)
        guard RewardCatalog.isUnlocked(item, stars: ledger.totalStars, bestStreak: ledger.bestStreak()) else { return }
        switch item.kind {
        case .color: ledger.equippedColor = item.id
        case .hat: ledger.equippedHat = item.id
        case .background: ledger.equippedBackground = item.id
        }
        save(ledger, for: child)
    }

    private func save(_ ledger: RewardsLedger, for child: ChildProfile) {
        ledgers[child.id] = ledger
        sharedStore.save(ledger, for: child.id)
    }

    // MARK: Alerts and "I'm low"

    func notifyParentIfNeeded(about reading: GlucoseSample, child: ChildProfile) {
        guard !alertedReadingIDs.contains(reading.id),
              let alert = AlertPolicy.alert(for: reading, child: child) else { return }
        alertedReadingIDs.insert(reading.id)
        childNotifier.post(alert, readingID: reading.id)
    }

    func pressedImLow(_ child: ChildProfile) {
        lowHelpChildID = child.id
        childNotifier.postLowPressed(child: child)
    }

    func closeLowHelp() {
        if let child = child(lowHelpChildID) { childNotifier.cancelRecheck(for: child) }
        lowHelpChildID = nil
    }

    // MARK: Kid Mode

    var hasParentPIN: Bool { pinStore.hasPIN }

    @discardableResult
    func setParentPIN(_ pin: String) -> Bool { pinStore.set(pin) }

    func verifyParentPIN(_ pin: String) -> Bool { pinStore.verify(pin) }

    func enterKidMode(_ child: ChildProfile) {
        guard child.kidModeEnabled, hasParentPIN else { return }
        household.kidModeChildID = child.id
    }

    /// Leaving Kid Mode always needs the parent PIN.
    @discardableResult
    func exitKidMode(pin: String) -> Bool {
        guard verifyParentPIN(pin) else { return false }
        household.kidModeChildID = nil
        lowHelpChildID = nil
        return true
    }

    // MARK: Sample family (testing)

    /// Fills the demo store with two sample children. Demo mode only: the
    /// store is in memory and nothing is written to Apple Health.
    func loadSampleFamily() {
        guard isDemo else { return }
        let family = SampleFamily.make(latest: options.demoKidReading)
        var household = Household()
        for data in family {
            household.upsert(data.child)
            try? repository.upsert(data.samples, profileKey: data.child.storageKey)
            for meal in data.meals { try? repository.save(meal: meal, photo: nil, profileKey: data.child.storageKey) }
            for dose in data.insulin { try? repository.save(insulin: dose, profileKey: data.child.storageKey) }
            ledgers[data.child.id] = data.ledger
            sharedStore.save(data.ledger, for: data.child.id)
        }
        if pinStore.verify(SampleFamily.parentPIN) == false { pinStore.set(SampleFamily.parentPIN) }
        if let name = options.kidModeName, let child = household.children.first(where: { $0.name == name }) {
            household.kidModeChildID = child.id
            household.selectedChildID = child.id
        }
        self.household = household
        reloadChildren()
    }
}
