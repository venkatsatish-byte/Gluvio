import SwiftUI
import WatchKit

@main
struct GluvioWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate
    @State private var model = WatchModel.shared

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(model)
                .task { await model.start() }
        }
    }
}

/// Keeps the Watch's reading and complications current without opening the app:
/// Apple Health wakes it when new readings arrive, and a background refresh is
/// scheduled roughly every 15 minutes as a fallback. watchOS decides the exact
/// timing and grants more refreshes when a Gluvio complication is on the face.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    static let refreshInterval: TimeInterval = 15 * 60

    func applicationDidFinishLaunching() {
        Task { @MainActor in
            await WatchModel.shared.startHealthSync()
            Self.scheduleBackgroundRefresh()
        }
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let refresh as WKApplicationRefreshBackgroundTask:
                Task { @MainActor in
                    await WatchModel.shared.startHealthSync()
                    await WatchModel.shared.refresh()
                    Self.scheduleBackgroundRefresh()
                    refresh.setTaskCompletedWithSnapshot(false)
                }
            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    @MainActor
    static func scheduleBackgroundRefresh() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date.now.addingTimeInterval(refreshInterval),
            userInfo: nil
        ) { _ in }
    }
}
