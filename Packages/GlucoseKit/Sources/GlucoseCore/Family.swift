import CryptoKit
import Foundation

/// Who Gluvio is for. Chosen in onboarding.
public enum AccountType: String, Codable, CaseIterable, Identifiable, Sendable {
    case type1, type2, prediabetes, caregiver

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .type1: return "Type 1 diabetes"
        case .type2: return "Type 2 diabetes"
        case .prediabetes: return "Prediabetes"
        case .caregiver: return "Parent or caregiver"
        }
    }

    public var subtitle: String {
        switch self {
        case .type1: return "Track glucose, meals and the insulin you take"
        case .type2: return "Track glucose, meals and activity"
        case .prediabetes: return "Learn how meals and activity affect you"
        case .caregiver: return "Set up profiles for children you care for"
        }
    }

    public var systemImage: String {
        switch self {
        case .type1: return "syringe"
        case .type2: return "drop"
        case .prediabetes: return "leaf"
        case .caregiver: return "figure.2.and.child.holdinghands"
        }
    }

    /// Insulin logging (log only) is offered to people with Type 1.
    public var logsInsulin: Bool { self == .type1 }
}

public enum DiabetesType: String, Codable, CaseIterable, Identifiable, Sendable {
    case type1, type2, other

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .type1: return "Type 1"
        case .type2: return "Type 2"
        case .other: return "Other"
        }
    }
}

public struct EmergencyContact: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var relation: String
    public var phone: String

    public init(id: UUID = UUID(), name: String = "", relation: String = "", phone: String = "") {
        self.id = id
        self.name = name
        self.relation = relation
        self.phone = phone
    }
}

/// A child's avatar: one of a few colors and symbols, so no photo is needed.
public struct AvatarStyle: Codable, Hashable, Sendable {
    public var colorIndex: Int
    public var symbol: String

    public init(colorIndex: Int = 0, symbol: String = "star.fill") {
        self.colorIndex = colorIndex
        self.symbol = symbol
    }

    public static let symbols = [
        "star.fill", "heart.fill", "bolt.fill", "leaf.fill",
        "pawprint.fill", "moon.stars.fill", "sun.max.fill", "sparkles",
    ]
    public static let colorCount = 8
}

/// When and how a parent is alerted about a child's readings on this device.
public struct ChildAlertSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var lowThreshold: Double
    public var highThreshold: Double
    public var quietHoursEnabled: Bool
    /// Minutes after midnight.
    public var quietStart: Int
    public var quietEnd: Int
    /// When on, only readings outside the thresholds alert. When off, every new reading does.
    public var onlyOutOfRange: Bool

    public init(
        isEnabled: Bool = true, lowThreshold: Double = 70, highThreshold: Double = 250,
        quietHoursEnabled: Bool = false, quietStart: Int = 21 * 60 + 30, quietEnd: Int = 6 * 60 + 30,
        onlyOutOfRange: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.lowThreshold = lowThreshold
        self.highThreshold = highThreshold
        self.quietHoursEnabled = quietHoursEnabled
        self.quietStart = quietStart
        self.quietEnd = quietEnd
        self.onlyOutOfRange = onlyOutOfRange
    }
}

/// A child profile, created and controlled by the parent on this device.
/// Holds only what the features need: no birth date, address or school.
public struct ChildProfile: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var age: Int
    public var diabetesType: DiabetesType
    public var avatar: AvatarStyle
    public var unit: GlucoseUnit
    public var targets: TargetRange
    /// Written by the parent from the child's care plan. Gluvio shows this
    /// text as-is on the low and high screens and never adds its own advice.
    public var carePlanLow: String
    public var carePlanHigh: String
    /// Recheck timer on the "I'm low" screen, set by the parent from the care plan.
    public var recheckMinutes: Int
    public var emergencyContacts: [EmergencyContact]
    public var alerts: ChildAlertSettings
    public var kidModeEnabled: Bool
    /// The child's CGM or meter writes to Apple Health on this iPhone, so their
    /// readings come from Health. Only one child can be linked.
    public var usesAppleHealth: Bool
    public var usesCGM: Bool
    public var hasPhoto: Bool

    public init(
        id: UUID = UUID(), name: String, age: Int, diabetesType: DiabetesType = .type1,
        avatar: AvatarStyle = AvatarStyle(), unit: GlucoseUnit = .mgdL, targets: TargetRange = .standard,
        carePlanLow: String = "", carePlanHigh: String = "", recheckMinutes: Int = 15,
        emergencyContacts: [EmergencyContact] = [], alerts: ChildAlertSettings = ChildAlertSettings(),
        kidModeEnabled: Bool = true, usesAppleHealth: Bool = false, usesCGM: Bool = true, hasPhoto: Bool = false
    ) {
        self.id = id
        self.name = name
        self.age = age
        self.diabetesType = diabetesType
        self.avatar = avatar
        self.unit = unit
        self.targets = targets
        self.carePlanLow = carePlanLow
        self.carePlanHigh = carePlanHigh
        self.recheckMinutes = recheckMinutes
        self.emergencyContacts = emergencyContacts
        self.alerts = alerts
        self.kidModeEnabled = kidModeEnabled
        self.usesAppleHealth = usesAppleHealth
        self.usesCGM = usesCGM
        self.hasPhoto = hasPhoto
    }

    public var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    public var carePlanLowSteps: [String] { CarePlan.steps(from: carePlanLow) }
    public var carePlanHighSteps: [String] { CarePlan.steps(from: carePlanHigh) }

    /// Repository key for this child's locally stored readings, meals and insulin.
    public var storageKey: String { id.uuidString }
}

public enum CarePlan {
    /// Splits the parent's care-plan text into steps, one per line, removing
    /// bullets and numbering ("1.", "2)", "-", "•") the parent may have typed.
    public static func steps(from text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            var step = line.trimmingCharacters(in: .whitespaces)
            while let first = step.first, "-•*·".contains(first) {
                step = String(step.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
            if let match = step.range(of: #"^\d{1,2}[.)]\s*"#, options: .regularExpression) {
                step = String(step[match.upperBound...])
            }
            return step.isEmpty ? nil : step
        }
    }
}

/// All child profiles on this device and which one, if any, has Kid Mode on.
public struct Household: Codable, Equatable, Sendable {
    public var children: [ChildProfile]
    public var selectedChildID: UUID?
    /// While set, the app is locked in Kid Mode for this child until a parent
    /// enters the PIN.
    public var kidModeChildID: UUID?

    public init(children: [ChildProfile] = [], selectedChildID: UUID? = nil, kidModeChildID: UUID? = nil) {
        self.children = children
        self.selectedChildID = selectedChildID
        self.kidModeChildID = kidModeChildID
    }

    public var healthLinkedChildID: UUID? { children.first(where: \.usesAppleHealth)?.id }

    public func child(_ id: UUID?) -> ChildProfile? {
        id.flatMap { id in children.first { $0.id == id } }
    }

    public var kidModeChild: ChildProfile? { child(kidModeChildID) }

    public mutating func upsert(_ child: ChildProfile) {
        var child = child
        if child.usesAppleHealth {
            // Only one child's readings can come from this iPhone's Apple Health.
            for index in children.indices where children[index].id != child.id {
                children[index].usesAppleHealth = false
            }
        }
        if let index = children.firstIndex(where: { $0.id == child.id }) {
            children[index] = child
        } else {
            child.avatar.colorIndex = child.avatar.colorIndex % AvatarStyle.colorCount
            children.append(child)
        }
        if selectedChildID == nil { selectedChildID = child.id }
    }

    public mutating func remove(_ id: UUID) {
        children.removeAll { $0.id == id }
        if selectedChildID == id { selectedChildID = children.first?.id }
        if kidModeChildID == id { kidModeChildID = nil }
    }
}

/// A salted hash of the parent PIN. The PIN itself is never stored.
public struct PINRecord: Codable, Equatable, Sendable {
    public var salt: Data
    public var hash: Data
}

public enum PINHasher {
    public static func isValid(_ pin: String) -> Bool {
        pin.count == 4 && pin.allSatisfy(\.isASCII) && pin.allSatisfy(\.isNumber)
    }

    public static func makeRecord(pin: String) -> PINRecord {
        var salt = Data(count: 16)
        for index in salt.indices { salt[index] = UInt8.random(in: 0...255) }
        return PINRecord(salt: salt, hash: hash(pin: pin, salt: salt))
    }

    public static func verify(_ pin: String, against record: PINRecord) -> Bool {
        let candidate = hash(pin: pin, salt: record.salt)
        // Compare every byte so timing doesn't reveal how much matched.
        guard candidate.count == record.hash.count else { return false }
        return zip(candidate, record.hash).reduce(0) { $0 | ($1.0 ^ $1.1) } == 0
    }

    static func hash(pin: String, salt: Data) -> Data {
        Data(SHA256.hash(data: salt + Data(pin.utf8)))
    }
}
