import Foundation

/// The "Carb Detective" game: guess which range a food's carbs fall in, then
/// learn the answer and a fun fact. Values are approximate for a typical
/// serving; real amounts depend on size and recipe.
public enum CarbRange: Int, CaseIterable, Identifiable, Sendable {
    case under10, from10to25, from26to40, over40

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .under10: return "Under 10 g"
        case .from10to25: return "10–25 g"
        case .from26to40: return "26–40 g"
        case .over40: return "Over 40 g"
        }
    }

    public var nickname: String {
        switch self {
        case .under10: return "A tiny bit"
        case .from10to25: return "Some"
        case .from26to40: return "Quite a lot"
        case .over40: return "A big helping"
        }
    }

    public init(grams: Int) {
        switch grams {
        case ..<10: self = .under10
        case 10...25: self = .from10to25
        case 26...40: self = .from26to40
        default: self = .over40
        }
    }
}

public struct CarbFood: Identifiable, Equatable, Sendable {
    public var id: String { name }
    public var name: String
    public var emoji: String
    public var serving: String
    public var grams: Int
    public var funFact: String

    public var range: CarbRange { CarbRange(grams: grams) }
}

public enum CarbDetective {
    public static let foods: [CarbFood] = [
        CarbFood(name: "Idli", emoji: "🍘", serving: "2 pieces", grams: 16,
                 funFact: "Idli is steamed, not fried. The batter rests overnight, which makes it soft and fluffy."),
        CarbFood(name: "Plain dosa", emoji: "🥞", serving: "1 medium", grams: 29,
                 funFact: "Dosa and idli are cousins: both are made from rice and urad dal batter."),
        CarbFood(name: "Chapati", emoji: "🫓", serving: "1 medium", grams: 17,
                 funFact: "Chapati is made from whole-wheat flour, so it has fiber too."),
        CarbFood(name: "Rice", emoji: "🍚", serving: "1 cup, cooked", grams: 45,
                 funFact: "Half a cup of rice has about half the carbs. Portion size matters!"),
        CarbFood(name: "Banana", emoji: "🍌", serving: "1 medium", grams: 27,
                 funFact: "Bananas taste sweeter as they ripen, because their starch turns into sugar."),
        CarbFood(name: "Poha", emoji: "🍛", serving: "1 cup", grams: 35,
                 funFact: "Poha is flattened rice. It cooks in just a few minutes!"),
        CarbFood(name: "Upma", emoji: "🥣", serving: "1 cup", grams: 32,
                 funFact: "Upma is made from semolina, also called rava or sooji."),
        CarbFood(name: "Dal", emoji: "🍲", serving: "½ cup, cooked", grams: 20,
                 funFact: "Dal is made from lentils, which have lots of protein and fiber."),
        CarbFood(name: "Samosa", emoji: "🥟", serving: "1 medium", grams: 28,
                 funFact: "Most of a samosa's carbs are in the crispy flour shell and the potato filling."),
        CarbFood(name: "Laddoo", emoji: "🟠", serving: "1 small", grams: 18,
                 funFact: "Laddoos get their carbs from sugar and flour, like besan or semolina."),
        CarbFood(name: "Mango", emoji: "🥭", serving: "1 cup, sliced", grams: 24,
                 funFact: "India grows more mangoes than any other country!"),
        CarbFood(name: "Apple", emoji: "🍎", serving: "1 small", grams: 20,
                 funFact: "Lots of an apple's fiber is in its peel."),
        CarbFood(name: "Milk", emoji: "🥛", serving: "1 cup", grams: 12,
                 funFact: "Milk has a natural sugar called lactose."),
        CarbFood(name: "Egg", emoji: "🥚", serving: "1 egg", grams: 1,
                 funFact: "Eggs have almost no carbs. They're mostly protein."),
        CarbFood(name: "Cucumber", emoji: "🥒", serving: "1 cup, sliced", grams: 4,
                 funFact: "Cucumbers are about 95% water!"),
        CarbFood(name: "Popcorn", emoji: "🍿", serving: "3 cups", grams: 18,
                 funFact: "Popcorn is a whole grain. Each kernel pops because of the water inside it."),
        CarbFood(name: "Pizza", emoji: "🍕", serving: "1 slice", grams: 35,
                 funFact: "The crust holds most of a pizza slice's carbs."),
        CarbFood(name: "Orange juice", emoji: "🧃", serving: "1 cup", grams: 26,
                 funFact: "A whole orange has fiber that juice doesn't."),
    ]

    /// Next round's food, avoiding the ones just played.
    public static func nextFood(excluding recent: [String], seed: Int) -> CarbFood {
        let pool = foods.filter { !recent.contains($0.name) }
        let choices = pool.isEmpty ? foods : pool
        return choices[abs(seed) % choices.count]
    }

    public static let disclaimer = "Carb amounts are approximate. Real amounts depend on size and recipe."
}
