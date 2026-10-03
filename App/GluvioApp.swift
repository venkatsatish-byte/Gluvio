import SwiftUI

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
        var options = LaunchOptions.current
        options.demoMode = on
        options.showOnboarding = false
        model = AppModel(options: options)
    }
}

/// Settings read from launch arguments, e.g. `-demoMode YES -initialTab trends`.
struct LaunchOptions {
    static let demoModeKey = "demoMode"

    var demoMode: Bool
    var initialTab: AppTab
    var showOnboarding: Bool
    var showUrgentDemo: Bool

    static var current: LaunchOptions {
        let defaults = UserDefaults.standard
        return LaunchOptions(
            demoMode: defaults.bool(forKey: demoModeKey),
            initialTab: defaults.string(forKey: "initialTab").flatMap(AppTab.init(rawValue:)) ?? .today,
            showOnboarding: defaults.bool(forKey: "showOnboarding"),
            showUrgentDemo: defaults.bool(forKey: "showUrgentDemo")
        )
    }
}

enum AppTab: String, Hashable {
    case today, trends, meals, guide, settings
}
