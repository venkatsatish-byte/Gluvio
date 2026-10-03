import GlucoseCore
import SwiftUI

/// "Check my number": shows a fresh CGM reading, or lets the child type a
/// fingerstick result on a big keypad. Either way it counts toward the quest.
struct KidCheckView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var child: ChildProfile

    @State private var entry = ""
    @State private var saved: GlucoseSample?
    @State private var problem: String?

    private var freshCGMReading: GlucoseSample? {
        guard child.usesCGM, let latest = model.latest(for: child),
              Date.now.timeIntervalSince(latest.date) <= 15 * 60 else { return nil }
        return latest
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let reading = saved ?? freshCGMReading {
                    result(reading)
                } else {
                    keypadEntry
                }
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.font(KidTheme.font(17, .semibold))
                }
            }
        }
    }

    private func result(_ reading: GlucoseSample) -> some View {
        let status = FriendlyStatus(band: child.targets.band(for: reading.mgdL), isStale: false)
        return VStack(spacing: 18) {
            Text("Your number is").font(KidTheme.font(24, .semibold))
            Text(child.unit.format(reading.mgdL)).font(KidTheme.font(80, .heavy)).monospacedDigit()
            Text(child.unit.symbol).font(KidTheme.font(20, .medium)).foregroundStyle(.secondary)
            Text(status.title).font(KidTheme.font(32, .heavy))
            Text(status.message).font(KidTheme.font(20, .medium)).multilineTextAlignment(.center)
            if status == .runningLow || status == .veryLow {
                Button {
                    dismiss()
                    model.pressedImLow(child)
                } label: {
                    Label("Show my low plan", systemImage: "hand.raised.fill")
                        .font(KidTheme.font(24, .bold)).frame(maxWidth: .infinity, minHeight: 72)
                }
                .buttonStyle(KidButtonStyle(color: .orange))
            }
            Button {
                if saved == nil { model.recordCheck(for: child) }
                dismiss()
            } label: {
                Text("Thanks for checking!").font(KidTheme.font(22, .bold)).frame(maxWidth: .infinity, minHeight: 64)
            }
            .buttonStyle(KidButtonStyle(color: .green))
        }
    }

    private var keypadEntry: some View {
        VStack(spacing: 18) {
            Text("What's your number?").font(KidTheme.font(28, .heavy))
            Text(entry.isEmpty ? " " : entry)
                .font(KidTheme.font(64, .heavy)).monospacedDigit()
                .frame(maxWidth: .infinity, minHeight: 80)
                .background(Color(uiColor: .secondarySystemFill), in: RoundedRectangle(cornerRadius: 22))
            Text(child.unit.symbol).foregroundStyle(.secondary)
            if let problem {
                Text(problem).font(KidTheme.font(18, .semibold)).foregroundStyle(.orange).multilineTextAlignment(.center)
            }
            let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", child.unit == .mmolL ? "." : "", "0", "⌫"]
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(keys.indices, id: \.self) { index in
                    let key = keys[index]
                    if key.isEmpty {
                        Color.clear.frame(height: 64)
                    } else {
                        Button { press(key) } label: {
                            Text(key).font(KidTheme.font(30, .bold)).frame(maxWidth: .infinity, minHeight: 64)
                        }
                        .buttonStyle(KidButtonStyle(color: .indigo))
                        .accessibilityLabel(key == "⌫" ? "Delete" : key)
                    }
                }
            }
            Button(action: save) {
                Text("Save").font(KidTheme.font(26, .heavy)).frame(maxWidth: .infinity, minHeight: 70)
            }
            .buttonStyle(KidButtonStyle(color: .green))
            .disabled(entry.isEmpty)
        }
    }

    private func press(_ key: String) {
        problem = nil
        if key == "⌫" {
            if !entry.isEmpty { entry.removeLast() }
        } else if entry.count < 5, !(key == "." && entry.contains(".")) {
            entry.append(key)
        }
    }

    private func save() {
        guard let value = Double(entry) else { return }
        let mgdL = child.unit.mgdL(from: value)
        guard SafetyGuidance.plausibleRange.contains(mgdL) else {
            problem = "Hmm, that number looks unusual. Ask a grown-up to help you check."
            return
        }
        let hour = Calendar.current.component(.hour, from: .now)
        let context: ReadingContext = [6, 7, 8, 11, 12, 13, 17, 18, 19].contains(hour) ? .beforeMeal : .other
        Task {
            if await model.logGlucose(for: child, mgdL: mgdL, context: context, fromKidMode: true) {
                saved = model.latest(for: child)
            }
        }
    }
}

/// "I ate": pick the meal and, optionally, the foods. Carbs are an approximate
/// total from the food list, clearly marked for a grown-up to check.
struct KidMealView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var child: ChildProfile

    @State private var kind = MealKind.suggested(for: .now)
    @State private var picked: Set<String> = []
    @State private var done = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if done {
                    VStack(spacing: 16) {
                        Text("🍽️").font(.system(size: 90))
                        Text("Yum! Meal logged.").font(KidTheme.font(30, .heavy))
                        Image(systemName: "star.fill").font(.system(size: 50)).foregroundStyle(.yellow)
                        Button { dismiss() } label: {
                            Text("Done").font(KidTheme.font(24, .bold)).frame(maxWidth: .infinity, minHeight: 64)
                        }
                        .buttonStyle(KidButtonStyle(color: .green))
                    }
                    .padding(24)
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Which meal?").font(KidTheme.font(26, .heavy))
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(MealKind.allCases) { meal in
                                Button { kind = meal } label: {
                                    Label(meal.title, systemImage: meal.systemImage)
                                        .font(KidTheme.font(20, .bold)).frame(maxWidth: .infinity, minHeight: 60)
                                }
                                .buttonStyle(KidButtonStyle(color: kind == meal ? .green : .gray.opacity(0.6)))
                            }
                        }
                        Text("What did you eat?").font(KidTheme.font(26, .heavy))
                        Text("Tap all that you had. You can skip this.").font(KidTheme.font(16, .medium)).foregroundStyle(.secondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                            ForEach(CarbDetective.foods) { food in
                                let selected = picked.contains(food.name)
                                Button {
                                    if selected { picked.remove(food.name) } else { picked.insert(food.name) }
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(food.emoji).font(.system(size: 34))
                                        Text(food.name).font(KidTheme.font(14, .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 84)
                                    .background(RoundedRectangle(cornerRadius: 18).fill(selected ? Color.green.opacity(0.25) : Color(uiColor: .secondarySystemFill)))
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? Color.green : .clear, lineWidth: 3))
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(selected ? .isSelected : [])
                            }
                        }
                        Button(action: save) {
                            Text("Save my meal").font(KidTheme.font(24, .heavy)).frame(maxWidth: .infinity, minHeight: 70)
                        }
                        .buttonStyle(KidButtonStyle(color: .green))
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }

    private func save() {
        let foods = CarbDetective.foods.filter { picked.contains($0.name) }
        let meal = MealEvent(
            date: .now, kind: kind,
            name: foods.map(\.name).joined(separator: ", "),
            carbsGrams: Double(foods.reduce(0) { $0 + $1.grams }),
            note: foods.isEmpty ? "Logged in Kid Mode." : "Logged in Kid Mode. Carbs are approximate; please check."
        )
        Task {
            if await model.logMeal(meal, for: child) {
                withAnimation(.spring) { done = true }
            }
        }
    }
}
