import GlucoseCore
import SwiftUI

struct QuestsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var child: ChildProfile

    var body: some View {
        let statuses = model.questStatuses(for: child)
        let ledger = model.ledger(for: child)
        let streak = ledger.currentStreak(today: .now)
        let next = RewardCatalog.nextUnlock(stars: ledger.totalStars, bestStreak: ledger.bestStreak())
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Today's quests").font(KidTheme.font(30, .heavy))
                    ForEach(statuses) { status in
                        HStack(spacing: 14) {
                            Image(systemName: status.isDone ? "star.fill" : status.kind.systemImage)
                                .font(.system(size: 32))
                                .foregroundStyle(status.isDone ? .yellow : .blue)
                                .frame(width: 44)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(status.kind.title).font(KidTheme.font(20, .bold))
                                Text(status.kind.detail).font(KidTheme.font(15, .medium)).foregroundStyle(.secondary)
                                ProgressView(value: status.progress).tint(status.isDone ? .yellow : .blue)
                                Text(status.isDone ? "Done! +1 star" : "\(status.current) of \(status.target)")
                                    .font(KidTheme.font(14, .semibold))
                            }
                        }
                        .padding(16)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22))
                    }
                    Text("Finish all three for a bonus star!").font(KidTheme.font(16, .semibold)).foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        statTile("\(ledger.record(on: .now).stars)", "stars today", "star.fill", .yellow)
                        statTile("\(streak)", "day streak", "flame.fill", .orange)
                        statTile("\(ledger.totalStars)", "total stars", "sparkles", .purple)
                    }
                    if streak == 0 {
                        Text("A new streak starts today. Do 2 quests to begin!").font(KidTheme.font(16, .medium))
                    }
                    if let next {
                        Label("Next to unlock: \(next.name). \(next.requirementText).", systemImage: "gift.fill")
                            .font(KidTheme.font(17, .semibold))
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                    }
                }
                .padding(20)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .onAppear { model.updateQuests(for: child) }
    }

    private func statTile(_ value: String, _ label: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(KidTheme.font(28, .heavy))
            Text(label).font(KidTheme.font(13, .medium)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

/// Carb Detective: guess the carb range, then learn the answer and a fun fact.
struct CarbDetectiveView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var food = CarbDetective.foods[0]
    @State private var guess: CarbRange?
    @State private var recent: [String] = []
    @State private var score = 0
    @State private var rounds = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Text("Carb Detective").font(KidTheme.font(30, .heavy))
                    Text("How many carbs?").font(KidTheme.font(20, .medium)).foregroundStyle(.secondary)
                    Text(food.emoji).font(.system(size: 110))
                    Text(food.name).font(KidTheme.font(32, .heavy))
                    Text(food.serving).font(KidTheme.font(18, .medium)).foregroundStyle(.secondary)

                    if let guess {
                        reveal(guess)
                    } else {
                        ForEach(CarbRange.allCases) { range in
                            Button {
                                withAnimation(.spring) {
                                    self.guess = range
                                    rounds += 1
                                    if range == food.range { score += 1 }
                                }
                            } label: {
                                VStack(spacing: 2) {
                                    Text(range.title).font(KidTheme.font(24, .heavy))
                                    Text(range.nickname).font(KidTheme.font(15, .medium))
                                }
                                .frame(maxWidth: .infinity, minHeight: 66)
                            }
                            .buttonStyle(KidButtonStyle(color: [Color.teal, .blue, .indigo, .purple][range.rawValue]))
                        }
                    }
                    Text("Detective score: \(score) of \(rounds)").font(KidTheme.font(16, .semibold))
                    Text(CarbDetective.disclaimer).font(KidTheme.font(12, .regular)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(20)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .onAppear { food = CarbDetective.nextFood(excluding: [], seed: Int.random(in: 0..<1000)) }
    }

    private func reveal(_ guess: CarbRange) -> some View {
        let right = guess == food.range
        return VStack(spacing: 14) {
            Text(right ? "You got it! 🎉" : "Good guess!").font(KidTheme.font(30, .heavy))
            Text("\(food.name) has about \(food.grams) g of carbs (\(food.range.title)).")
                .font(KidTheme.font(20, .semibold)).multilineTextAlignment(.center)
            Label(food.funFact, systemImage: "lightbulb.fill")
                .font(KidTheme.font(18, .medium))
                .padding(16)
                .background(Color.yellow.opacity(0.18), in: RoundedRectangle(cornerRadius: 18))
            Button {
                recent = Array((recent + [food.name]).suffix(6))
                withAnimation {
                    food = CarbDetective.nextFood(excluding: recent, seed: Int.random(in: 0..<1000))
                    self.guess = nil
                }
            } label: {
                Text("Next food").font(KidTheme.font(24, .bold)).frame(maxWidth: .infinity, minHeight: 64)
            }
            .buttonStyle(KidButtonStyle(color: .green))
        }
    }
}

/// Dress up Glu with unlocked colors, hats and backgrounds. Locked items show
/// how to earn them; nothing is ever taken away.
struct CustomizeGluView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var child: ChildProfile

    var body: some View {
        let ledger = model.ledger(for: child)
        let stars = ledger.totalStars
        let best = ledger.bestStreak()
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    GluMascot(mood: .happy, colorID: ledger.equippedColor, hatID: ledger.equippedHat, size: 130)
                        .frame(maxWidth: .infinity)
                        .background(KidTheme.background(ledger.equippedBackground), in: RoundedRectangle(cornerRadius: 26))
                    section("Colors", kind: .color, equipped: ledger.equippedColor, stars: stars, best: best)
                    section("Hats", kind: .hat, equipped: ledger.equippedHat, stars: stars, best: best)
                    section("Backgrounds", kind: .background, equipped: ledger.equippedBackground, stars: stars, best: best)
                }
                .padding(20)
            }
            .navigationTitle("My Glu")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func section(_ title: String, kind: RewardItem.Kind, equipped: String, stars: Int, best: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(KidTheme.font(22, .heavy))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(RewardCatalog.items.filter { $0.kind == kind }) { item in
                    let unlocked = RewardCatalog.isUnlocked(item, stars: stars, bestStreak: best)
                    Button {
                        model.equip(item, for: child)
                    } label: {
                        VStack(spacing: 4) {
                            preview(item)
                            Text(item.name).font(KidTheme.font(14, .bold))
                            if !unlocked {
                                Label(item.requirementText, systemImage: "lock.fill")
                                    .font(KidTheme.font(11, .medium)).foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 104)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color(uiColor: .secondarySystemBackground)))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(item.id == equipped ? Color.green : .clear, lineWidth: 3))
                        .opacity(unlocked ? 1 : 0.55)
                    }
                    .buttonStyle(.plain)
                    .disabled(!unlocked)
                    .accessibilityLabel("\(item.name)\(unlocked ? "" : ", locked. \(item.requirementText)")\(item.id == equipped ? ", selected" : "")")
                }
            }
        }
    }

    @ViewBuilder
    private func preview(_ item: RewardItem) -> some View {
        switch item.kind {
        case .color:
            Circle().fill(LinearGradient(colors: KidTheme.bodyColors(item.id), startPoint: .top, endPoint: .bottom))
                .frame(width: 44, height: 44)
        case .hat:
            GluMascot(mood: .happy, colorID: "sunshine", hatID: item.id, size: 36).frame(height: 50)
        case .background:
            RoundedRectangle(cornerRadius: 10).fill(KidTheme.background(item.id)).frame(width: 56, height: 40)
        }
    }
}
