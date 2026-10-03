import Foundation

/// Kid-friendly words for a reading. Supportive and never shaming: a number is
/// information, not a grade.
public enum FriendlyStatus: String, Equatable, Sendable {
    case inTheZone, climbing, bigClimb, runningLow, veryLow, timeToCheck

    public init(band: GlucoseBand?, isStale: Bool) {
        guard let band, !isStale else {
            self = .timeToCheck
            return
        }
        switch band {
        case .urgentLow: self = .veryLow
        case .low: self = .runningLow
        case .inRange: self = .inTheZone
        case .high: self = .climbing
        case .urgentHigh: self = .bigClimb
        }
    }

    public var title: String {
        switch self {
        case .inTheZone: return "In the zone!"
        case .climbing: return "Climbing a hill"
        case .bigClimb: return "Up a big mountain"
        case .runningLow: return "Running low"
        case .veryLow: return "Running very low"
        case .timeToCheck: return "Time to check!"
        }
    }

    public var message: String {
        switch self {
        case .inTheZone: return "Glu is glowing. Keep doing your thing!"
        case .climbing: return "Let's tell a grown-up and follow your plan."
        case .bigClimb: return "Tell a grown-up now so they can help."
        case .runningLow: return "Tell a grown-up now. Tap \"I'm low\" for your plan."
        case .veryLow: return "Get a grown-up right now. Tap \"I'm low\"."
        case .timeToCheck: return "Let's check your number."
        }
    }

    public var needsGrownUp: Bool {
        switch self {
        case .runningLow, .veryLow, .climbing, .bigClimb: return true
        case .inTheZone, .timeToCheck: return false
        }
    }
}

/// Glu the mascot's mood. Follows the latest reading when it's fresh, and
/// today's time in range otherwise.
public enum MascotMood: String, Codable, CaseIterable, Sendable {
    case happy, sleepy, wobbly, curious

    public static func current(latestBand: GlucoseBand?, isStale: Bool, todayInRange: Double?) -> MascotMood {
        if let band = latestBand, !isStale {
            switch band {
            case .urgentLow, .low: return .sleepy
            case .high, .urgentHigh: return .wobbly
            case .inRange: return .happy
            }
        }
        if let todayInRange, todayInRange >= 0.7 { return .happy }
        return .curious
    }

    public var line: String {
        switch self {
        case .happy: return "Glu is glowing!"
        case .sleepy: return "Glu feels sleepy."
        case .wobbly: return "Glu feels wobbly."
        case .curious: return "Glu is curious. Let's check!"
        }
    }
}

/// Words that must never appear in anything shown to a child.
public enum KidCopy {
    public static let bannedWords = [
        "bad", "naughty", "fail", "wrong", "lazy", "shame", "cheat", "should have", "disappoint", "careless",
    ]
}
