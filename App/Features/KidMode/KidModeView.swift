import GlucoseCore
import SwiftUI

/// Kid Mode: what a child sees while a parent has locked the app to their
/// profile. Big buttons, rounded type, simple words. Leaving needs the parent PIN.
struct KidModeView: View {
    @Environment(AppModel.self) private var model
    var child: ChildProfile

    enum Sheet: String, Identifiable {
        case check, meal, quests, carbs, customize, exit
        var id: String { rawValue }
    }

    @State private var sheet: Sheet?
    @State private var waterCelebration = false

    var body: some View {
        let ledger = model.ledger(for: child)
        let latest = model.latest(for: child)
        let band = latest.map { child.targets.band(for: $0.mgdL) }
        let stale = latest.map { Date.now.timeIntervalSince($0.date) > (child.usesCGM ? 20 * 60 : 6 * 3600) } ?? true
        let status = FriendlyStatus(band: band, isStale: stale)
        let today = DateInterval(start: Calendar.current.startOfDay(for: .now), end: .now)
        let todayStats = GlucoseAnalytics.stats(for: model.readings(for: child), in: today, targets: child.targets)
        let mood = MascotMood.current(latestBand: band, isStale: stale, todayInRange: todayStats.inRangeFraction)
        let dark = KidTheme.isDark(ledger.equippedBackground)

        ScrollView {
            VStack(spacing: 18) {
                header(ledger: ledger, dark: dark)

                GluMascot(mood: mood, colorID: ledger.equippedColor, hatID: ledger.equippedHat, size: 170)
                Text(mood.line)
                    .font(KidTheme.font(20, .semibold))
                    .foregroundStyle(dark ? .white : .primary)

                statusCard(status: status, latest: latest)

                Button {
                    model.pressedImLow(child)
                } label: {
                    Label("I'm low", systemImage: "hand.raised.fill")
                        .font(KidTheme.font(34, .heavy))
                        .frame(maxWidth: .infinity, minHeight: 92)
                }
                .buttonStyle(KidButtonStyle(color: .orange))
                .accessibilityHint("Shows your care plan and tells your grown-ups")

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    bigButton("Check my number", "drop.fill", .pink) { sheet = .check }
                    bigButton("I ate", "fork.knife", .green) { sheet = .meal }
                    bigButton(waterCelebration ? "Splash! +1" : "Water", "waterbottle.fill", .blue) {
                        Task {
                            await model.addWater(for: child)
                            withAnimation(.spring) { waterCelebration = true }
                            try? await Task.sleep(for: .seconds(1.5))
                            withAnimation { waterCelebration = false }
                        }
                    }
                    bigButton("Quests", "star.fill", .yellow) { sheet = .quests }
                    bigButton("Carb Detective", "magnifyingglass", .purple) { sheet = .carbs }
                    bigButton("My Glu", "paintbrush.pointed.fill", .teal) { sheet = .customize }
                }

                Text(SafetyCopy.shortDisclaimer)
                    .font(KidTheme.font(12, .regular))
                    .foregroundStyle(dark ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
            .padding(20)
        }
        .background(KidTheme.background(ledger.equippedBackground).ignoresSafeArea())
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .check: KidCheckView(child: child)
            case .meal: KidMealView(child: child)
            case .quests: QuestsView(child: child)
            case .carbs: CarbDetectiveView()
            case .customize: CustomizeGluView(child: child)
            case .exit: ExitKidModeView()
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { model.lowHelpChildID == child.id },
            set: { if !$0 { model.closeLowHelp() } }
        )) {
            LowHelpView(child: child)
        }
        .onAppear {
            model.updateQuests(for: child)
            openLaunchScreen()
        }
    }

    private func header(ledger: RewardsLedger, dark: Bool) -> some View {
        HStack {
            ChildAvatar(child: child, size: 48)
            VStack(alignment: .leading) {
                Text("Hi, \(child.firstName)!").font(KidTheme.font(28, .heavy))
                Label("\(ledger.totalStars) stars · \(ledger.currentStreak(today: .now))-day streak", systemImage: "star.fill")
                    .font(KidTheme.font(15, .semibold))
            }
            .foregroundStyle(dark ? .white : .primary)
            Spacer()
            Button { sheet = .exit } label: {
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Grown-ups: leave Kid Mode")
        }
    }

    private func statusCard(status: FriendlyStatus, latest: GlucoseSample?) -> some View {
        VStack(spacing: 6) {
            Text(status.title)
                .font(KidTheme.font(32, .heavy))
                .foregroundStyle(color(for: status))
            if let latest {
                Text("\(child.unit.formatWithUnit(latest.mgdL)) · \(GlucoseAnalytics.ageDescription(of: latest.date))")
                    .font(KidTheme.font(16, .medium))
                    .foregroundStyle(.secondary)
            }
            Text(status.message)
                .font(KidTheme.font(18, .medium))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func color(for status: FriendlyStatus) -> Color {
        switch status {
        case .inTheZone: return .green
        case .climbing, .bigClimb: return .orange
        case .runningLow, .veryLow: return .red
        case .timeToCheck: return .blue
        }
    }

    private func bigButton(_ title: String, _ systemImage: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage).font(.system(size: 34, weight: .bold))
                Text(title).font(KidTheme.font(19, .bold)).multilineTextAlignment(.center).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 112)
        }
        .buttonStyle(KidButtonStyle(color: color))
    }

    /// Lets the screenshot script open a specific screen (DEBUG launch argument).
    private func openLaunchScreen() {
        switch model.options.kidScreen {
        case "check": sheet = .check
        case "meal": sheet = .meal
        case "quests": sheet = .quests
        case "carbs": sheet = .carbs
        case "customize": sheet = .customize
        case "low": model.pressedImLow(child)
        default: break
        }
    }
}

struct KidButtonStyle: ButtonStyle {
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(color.gradient)
                    .shadow(color: color.opacity(0.4), radius: configuration.isPressed ? 2 : 8, y: configuration.isPressed ? 1 : 5)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// Grown-ups enter the PIN to leave Kid Mode.
struct ExitKidModeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var message = "Grown-ups: enter your PIN"

    var body: some View {
        VStack(spacing: 24) {
            Text("Leave Kid Mode").font(KidTheme.font(28, .heavy))
            PINPad(prompt: message) { pin in
                if model.exitKidMode(pin: pin) {
                    dismiss()
                    return true
                }
                message = "That PIN didn't match. Try again."
                return false
            }
            Button("Cancel") { dismiss() }.font(KidTheme.font(18, .semibold))
        }
        .padding()
        .presentationDetents([.large])
    }
}

/// A 4-digit PIN keypad. `onComplete` returns whether the PIN was accepted.
struct PINPad: View {
    var prompt: String
    var onComplete: (String) -> Bool

    @State private var digits = ""
    @State private var shake = false

    var body: some View {
        VStack(spacing: 20) {
            Text(prompt).font(KidTheme.font(18, .medium)).multilineTextAlignment(.center)
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.5), lineWidth: 2)
                        .background(Circle().fill(index < digits.count ? Color.primary : .clear))
                        .frame(width: 18, height: 18)
                }
            }
            .offset(x: shake ? 10 : 0)
            .accessibilityLabel("\(digits.count) of 4 digits entered")
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(84), spacing: 18), count: 3), spacing: 14) {
                ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"], id: \.self) { key in
                    if key.isEmpty {
                        Color.clear.frame(width: 84, height: 70)
                    } else {
                        Button {
                            press(key)
                        } label: {
                            Text(key)
                                .font(KidTheme.font(30, .semibold))
                                .frame(width: 84, height: 70)
                                .background(Color(uiColor: .secondarySystemFill), in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(key == "⌫" ? "Delete" : key)
                    }
                }
            }
        }
    }

    private func press(_ key: String) {
        if key == "⌫" {
            if !digits.isEmpty { digits.removeLast() }
            return
        }
        guard digits.count < 4 else { return }
        digits.append(key)
        if digits.count == 4 {
            let pin = digits
            if !onComplete(pin) {
                withAnimation(.default.repeatCount(3, autoreverses: true).speed(4)) { shake = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    shake = false
                    digits = ""
                }
            }
        }
    }
}
