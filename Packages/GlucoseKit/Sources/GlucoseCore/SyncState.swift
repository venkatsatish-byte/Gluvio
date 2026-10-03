import Foundation

/// How Gluvio's last sync with Apple Health went. Saved in the App Group so the
/// iPhone app, widgets and settings all describe it the same way.
public struct SyncState: Codable, Equatable, Sendable {
    public var lastSuccess: Date?
    public var lastAttempt: Date?
    public var lastError: String?
    /// Readings added or changed by the last successful sync.
    public var lastImportCount: Int

    public init(lastSuccess: Date? = nil, lastAttempt: Date? = nil, lastError: String? = nil, lastImportCount: Int = 0) {
        self.lastSuccess = lastSuccess
        self.lastAttempt = lastAttempt
        self.lastError = lastError
        self.lastImportCount = lastImportCount
    }

    public var hasFailed: Bool { lastError != nil }

    public mutating func recordSuccess(at date: Date, imported: Int) {
        lastSuccess = date
        lastAttempt = date
        lastError = nil
        lastImportCount = imported
    }

    public mutating func recordFailure(at date: Date, message: String) {
        lastAttempt = date
        lastError = message
    }

    /// e.g. "Synced with Apple Health 3 min ago".
    public func summary(now: Date = .now) -> String {
        if let lastError {
            return "Last sync failed: \(lastError)"
        }
        guard let lastSuccess else { return "Not synced with Apple Health yet" }
        let age = GlucoseAnalytics.ageDescription(of: lastSuccess, now: now)
        return age == "Just now" ? "Synced with Apple Health just now" : "Synced with Apple Health \(age)"
    }
}
