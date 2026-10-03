import Foundation
import GlucoseCore
import UserNotifications

/// Posts a child's alerts as local notifications on this device, and shows them
/// even while Gluvio is open. There's no server, so alerts can't reach other
/// phones; the "I'm low" screen offers a pre-written text message instead.
final class ChildAlertNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ChildAlertNotifier()

    private let center = UNUserNotificationCenter.current()

    func post(_ alert: ChildAlert, readingID: UUID) {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = .default
        if alert.kind == .urgentLow || alert.kind == .low {
            content.interruptionLevel = .timeSensitive
        }
        center.add(UNNotificationRequest(identifier: "child.reading.\(readingID.uuidString)", content: content, trigger: nil))
    }

    /// The child pressed "I'm low": tell whoever has this device, and remind
    /// everyone to recheck when the care plan's timer ends.
    func postLowPressed(child: ChildProfile, at date: Date = .now) {
        let content = UNMutableNotificationContent()
        content.title = "\(child.firstName) pressed \"I'm low\""
        content.body = "At \(date.formatted(date: .omitted, time: .shortened)). Their care-plan steps are on screen."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        center.add(UNNotificationRequest(identifier: "child.lowpressed.\(child.id.uuidString)", content: content, trigger: nil))

        let recheck = UNMutableNotificationContent()
        recheck.title = "Time for \(child.firstName) to check again"
        recheck.body = "The \(child.recheckMinutes)-minute timer from the care plan has finished."
        recheck.sound = .default
        recheck.interruptionLevel = .timeSensitive
        let seconds = TimeInterval(max(1, child.recheckMinutes) * 60)
        center.add(UNNotificationRequest(
            identifier: "child.recheck.\(child.id.uuidString)",
            content: recheck,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        ))
    }

    func cancelRecheck(for child: ChildProfile) {
        center.removePendingNotificationRequests(withIdentifiers: ["child.recheck.\(child.id.uuidString)"])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
