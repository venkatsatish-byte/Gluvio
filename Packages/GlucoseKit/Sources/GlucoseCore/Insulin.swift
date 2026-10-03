import Foundation

/// Insulin is LOG ONLY. Gluvio records what was taken. It never calculates,
/// suggests or adjusts an amount, and has no insulin-to-carb or correction
/// settings by design.
public enum InsulinKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case rapid, long

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .rapid: return "Rapid-acting"
        case .long: return "Long-acting"
        }
    }

    public var shortTitle: String {
        switch self {
        case .rapid: return "Rapid"
        case .long: return "Long"
        }
    }
}

public struct InsulinDose: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var date: Date
    public var units: Double
    public var kind: InsulinKind
    public var note: String

    public init(id: UUID = UUID(), date: Date, units: Double, kind: InsulinKind, note: String = "") {
        self.id = id
        self.date = date
        self.units = units
        self.kind = kind
        self.note = note
    }

    /// "4.5 u" or "12 u".
    public var unitsText: String {
        units == units.rounded() ? "\(Int(units)) u" : String(format: "%.1f u", units)
    }

    /// Typed amounts outside this are almost certainly typos.
    public static let plausibleUnits: ClosedRange<Double> = 0.5...100
}

public enum InsulinCopy {
    public static let logOnlyNotice =
        "Log only. Gluvio records the insulin you took and never works out amounts. Follow your care team's plan."
}
