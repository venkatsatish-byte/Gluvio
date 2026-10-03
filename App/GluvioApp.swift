import GlucoseCore
import SwiftUI
import UserNotifications

@main
struct GluvioApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var host = AppHost.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(host)
                .environment(host.model)
                .task(id: ObjectIdentifier(host.model)) { await host.model.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            // Catch up whenever the app comes to the front.
            if phase == .active { Task { await host.model.refresh() } }
        }
    }
}

/// iOS can launch Gluvio in the background, without any window, to deliver new
/// Apple Health readings. SwiftUI views don't load then, so the Health observer
/// is registered here, at launch, where it runs in both cases.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = ChildAlertNotifier.shared
        Task { await AppHost.shared.model.startHealthSync() }
        return true
    }
}

/// Owns the current `AppModel`, so the app can switch between real data and
/// sample data (for exploring the app, screenshots and App Review) without a
/// relaunch.
@Observable
@MainActor
final class AppHost {
    /// One instance for the app's lifetime, shared by the SwiftUI app and the
    /// app delegate (which runs on background launches too).
    static let shared = AppHost()

    private(set) var model: AppModel

    private init() {
        model = AppModel(options: .current)
    }

    func setDemoMode(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: LaunchOptions.demoModeKey)
        if !on { UserDefaults.standard.set(false, forKey: LaunchOptions.demoFamilyKey) }
        var options = LaunchOptions.current
        options.demoMode = on
        options.showOnboarding = false
        if !on { options.demoFamily = false }
        model = AppModel(options: options)
    }

    #if DEBUG
    /// Loads a sample caregiver household with two children, for testing Kid
    /// Mode and the Parent Dashboard in the simulator. Parent PIN: 1234.
    func loadSampleFamily() {
        UserDefaults.standard.set(true, forKey: LaunchOptions.demoModeKey)
        UserDefaults.standard.set(true, forKey: LaunchOptions.demoFamilyKey)
        var options = LaunchOptions.current
        options.demoMode = true
        options.demoFamily = true
        options.showOnboarding = false
        options.initialTab = .family
        model = AppModel(options: options)
    }
    #endif
}

/// Settings read from launch arguments, e.g. `-demoMode YES -initialTab trends`.
struct LaunchOptions {
    static let demoModeKey = "demoMode"
    static let demoFamilyKey = "demoFamily"

    var demoMode: Bool
    var initialTab: AppTab
    var showOnboarding: Bool
    var showUrgentDemo: Bool
    /// Sample caregiver household with two children (DEBUG builds only).
    var demoFamily = false
    var demoAccountType: AccountType?
    /// Start in Kid Mode for the sample child with this name.
    var kidModeName: String?
    /// Force the sample child's latest reading: low, veryLow, high or inRange.
    var demoKidReading: SampleFamily.LatestOverride?
    /// Open a Kid Mode screen at launch: quests, carbs, customize, low, check.
    var kidScreen: String?
    /// Open a parent screen at launch: dashboard, school, editor.
    var parentScreen: String?

    static var current: LaunchOptions {
        let defaults = UserDefaults.standard
        var options = LaunchOptions(
            demoMode: defaults.bool(forKey: demoModeKey),
            initialTab: defaults.string(forKey: "initialTab").flatMap(AppTab.init(rawValue:)) ?? .today,
            showOnboarding: defaults.bool(forKey: "showOnboarding"),
            showUrgentDemo: defaults.bool(forKey: "showUrgentDemo")
        )
        options.demoAccountType = defaults.string(forKey: "accountType").flatMap(AccountType.init(rawValue:))
        #if DEBUG
        options.demoFamily = options.demoMode && defaults.bool(forKey: demoFamilyKey)
        options.kidModeName = defaults.string(forKey: "kidMode")
        options.demoKidReading = defaults.string(forKey: "demoKidReading").flatMap(SampleFamily.LatestOverride.init(rawValue:))
        options.kidScreen = defaults.string(forKey: "kidScreen")
        options.parentScreen = defaults.string(forKey: "parentScreen")
        if options.demoFamily && defaults.string(forKey: "initialTab") == nil { options.initialTab = .family }
        #endif
        return options
    }
}

enum AppTab: String, Hashable {
    case today, trends, meals, family, guide, settings
}
