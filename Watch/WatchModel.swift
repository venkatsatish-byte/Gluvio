import Foundation
import GlucoseCore
import GlucoseHealth
import Observation
import WatchKit
import WidgetKit

/// The Watch reads its own copy of Apple Health (iOS syncs it over), keeps the
/// last 24 hours in memory, and writes quick logs straight to Apple Health so
/// nothing is lost when the iPhone is out of range.
@Observable
@MainActor
final class WatchModel {
    /// Shared by the SwiftUI app and the app delegate, which also runs on
    /// background launches.
    static let shared = WatchModel()

    var profile: UserProfile
    private(set) var samples: [GlucoseSample] = []
    private(set) var syncState: SyncState
    var message: String?
    let isDemo: Bool

    @ObservationIgnored private let health: any HealthDataProviding
    @ObservationIgnored private let store: SharedStore
    @ObservationIgnored private var connectivity: WatchConnectivityReceiver?
    @ObservationIgnored private var lastHapticReadingID: UUID?
    @ObservationIgnored private var started = false
    @ObservationIgnored private var isObservingHealth = false
    @ObservationIgnored private var isRefreshing = false

    private init() {
        isDemo = UserDefaults.standard.bool(forKey: "demoMode")
        store = SharedStore()
        profile = store.loadProfile()
        syncState = store.loadSyncState()
        if isDemo {
            health = DemoHealthService(dataset: SampleData.make(days: 2))
        } else {
            health = HealthKitService()
        }
    }

    func start() async {
        guard !started else { return }
        started = true
        connectivity = WatchConnectivityReceiver { [weak self] profile in
            Task { @MainActor in self?.apply(profile) }
        }
        // Asking is only possible while the app is open, so it happens here
        // rather than in the background launch path.
        try? await health.requestAuthorization()
        await startHealthSync()
        await refresh()
    }

    /// Registers for new-glucose updates from Apple Health (foreground and
    /// background). Needs Health access to have been requested; safe to repeat.
    func startHealthSync() async {
        guard !isObservingHealth, await health.accessStatus() == .requested else { return }
        isObservingHealth = true
        health.startObservingGlucose { [weak self] done in
            Task { @MainActor in
                await self?.refresh()
                done()
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let now = Date.now
        do {
            let latest = try await health.glucoseSamples(from: now.addingTimeInterval(-24 * 3600), to: now)
            syncState.recordSuccess(at: now, imported: max(0, latest.count - samples.count))
            samples = latest
            message = nil
        } catch {
            syncState.recordFailure(at: now, message: "couldn't read Apple Health")
            message = "Couldn't read Apple Health."
        }
        store.save(syncState)
        store.save(WidgetSnapshot.make(from: samples, profile: profile, now: now))
        WidgetCenter.shared.reloadAllTimelines()
        playHapticIfOutOfRange(now: now)
    }

    // MARK: Derived

    var latest: GlucoseSample? { samples.last }
    var trend: TrendArrow? { GlucoseAnalytics.trend(from: Array(samples.suffix(12))) }

    var todayStats: GlucoseStats {
        let now = Date.now
        return GlucoseAnalytics.stats(for: samples, in: DateInterval(start: Calendar.current.startOfDay(for: now), end: now),
                                      targets: profile.targets)
    }

    // MARK: Quick log

    func logGlucose(mgdL: Double, context: ReadingContext) async -> Bool {
        let sample = GlucoseSample(date: .now, mgdL: mgdL, context: context, source: .manual, sourceName: "Gluvio")
        do {
            try await health.save(sample)
        } catch {
            message = "Couldn't save to Apple Health."
            return false
        }
        await refresh()
        if let alert = SafetyGuidance.alert(for: sample, targets: profile.targets) {
            WKInterfaceDevice.current().play(.failure)
            message = alert.kind == .low
                ? "Very low. Follow your care plan now. Call emergency services if you feel unwell."
                : "Very high. Follow your care plan and recheck. Get help if you feel very unwell."
        }
        return true
    }

    func logMeal(kind: MealKind, carbs: Double) async -> Bool {
        let meal = MealEvent(date: .now, kind: kind, carbsGrams: carbs)
        do {
            try await health.save(meal: meal)
        } catch {
            message = "Couldn't save to Apple Health."
            return false
        }
        connectivity?.send(meal)
        return true
    }

    func logWater(milliliters: Double) async -> Bool {
        do {
            try await health.saveWater(milliliters: milliliters, at: .now)
            WKInterfaceDevice.current().play(.success)
            return true
        } catch {
            message = "Couldn't save to Apple Health."
            return false
        }
    }

    // MARK: Private

    private func apply(_ newProfile: UserProfile) {
        profile = newProfile
        store.save(newProfile)
        Task { await refresh() }
    }

    /// A gentle, informational tap when a fresh reading is outside the range.
    /// It only runs while the app is updating, so it's never presented as an alarm.
    private func playHapticIfOutOfRange(now: Date) {
        guard profile.hapticAlertsEnabled, let latest, latest.id != lastHapticReadingID,
              now.timeIntervalSince(latest.date) < 15 * 60 else { return }
        let band = profile.targets.band(for: latest.mgdL)
        guard band != .inRange else { return }
        lastHapticReadingID = latest.id
        WKInterfaceDevice.current().play(band.isUrgent ? .failure : .notification)
    }
}
