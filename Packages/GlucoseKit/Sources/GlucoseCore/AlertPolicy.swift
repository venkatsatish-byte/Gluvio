import Foundation

public struct ChildAlert: Equatable, Sendable {
    public enum Kind: String, Sendable { case urgentLow, low, high, update }

    public var kind: Kind
    public var title: String
    public var body: String
}

/// Decides whether a new reading for a child should alert the parent on this
/// device. Alerts state the reading and point to the parent's own care plan;
/// they never suggest what to do.
public enum AlertPolicy {
    /// Readings older than this don't alert; they're history, not news.
    public static let freshness: TimeInterval = 30 * 60

    public static func alert(for reading: GlucoseSample, child: ChildProfile, now: Date = .now,
                             calendar: Calendar = .current) -> ChildAlert? {
        let settings = child.alerts
        guard settings.isEnabled, now.timeIntervalSince(reading.date) < freshness else { return nil }
        let value = child.unit.formatWithUnit(reading.mgdL)

        // Very low readings alert even during quiet hours.
        if reading.mgdL < child.targets.urgentLow {
            return ChildAlert(kind: .urgentLow, title: "\(child.firstName) is very low",
                              body: "\(value). Open Gluvio for \(child.firstName)'s care plan.")
        }
        if isInQuietHours(now, settings: settings, calendar: calendar) { return nil }
        if reading.mgdL < settings.lowThreshold {
            return ChildAlert(kind: .low, title: "\(child.firstName) is low",
                              body: "\(value), below \(child.unit.format(settings.lowThreshold)). Open Gluvio for the care plan.")
        }
        if reading.mgdL > settings.highThreshold {
            return ChildAlert(kind: .high, title: "\(child.firstName) is high",
                              body: "\(value), above \(child.unit.format(settings.highThreshold)). Open Gluvio for the care plan.")
        }
        guard !settings.onlyOutOfRange else { return nil }
        return ChildAlert(kind: .update, title: "\(child.firstName): \(value)", body: "New reading, in range.")
    }

    public static func isInQuietHours(_ date: Date, settings: ChildAlertSettings, calendar: Calendar = .current) -> Bool {
        guard settings.quietHoursEnabled, settings.quietStart != settings.quietEnd else { return false }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if settings.quietStart < settings.quietEnd {
            return minute >= settings.quietStart && minute < settings.quietEnd
        }
        // Wraps past midnight, e.g. 21:30–06:30.
        return minute >= settings.quietStart || minute < settings.quietEnd
    }
}
