import GlucoseCore
import SwiftUI

/// The Family tab: every child profile at a glance.
struct FamilyHomeView: View {
    @Environment(AppModel.self) private var model
    @State private var path: [UUID] = []
    @State private var addingChild = false
    @State private var openedLaunchScreen = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if model.isDemo {
                    Section { DemoBanner() }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                }
                ForEach(model.household.children) { child in
                    NavigationLink(value: child.id) { ChildRow(child: child) }
                }
                Section {
                    Button { addingChild = true } label: { Label("Add a child", systemImage: "person.badge.plus") }
                } footer: {
                    Text("Child profiles stay on this iPhone. Gluvio has no accounts, ads or third-party analytics. \(SafetyCopy.shortDisclaimer)")
                }
            }
            .overlay {
                if model.household.children.isEmpty {
                    ContentUnavailableView {
                        Label("Add your child", systemImage: "figure.2.and.child.holdinghands")
                    } description: {
                        Text("Set up their target range, care plan, emergency contacts and Kid Mode.")
                    } actions: {
                        Button("Add a child") { addingChild = true }.buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Family")
            .navigationDestination(for: UUID.self) { ChildDashboardView(childID: $0) }
            .sheet(isPresented: $addingChild) {
                ChildEditorView(child: ChildProfile(name: "", age: 8, avatar: AvatarStyle(colorIndex: model.household.children.count)))
            }
            // DEBUG launch argument: open the first child's dashboard once the
            // sample family has loaded.
            .task(id: model.household.children.count) {
                guard !openedLaunchScreen, model.options.parentScreen != nil,
                      let first = model.household.children.first else { return }
                openedLaunchScreen = true
                path = [first.id]
            }
        }
    }
}

struct ChildRow: View {
    @Environment(AppModel.self) private var model
    var child: ChildProfile

    var body: some View {
        let latest = model.latest(for: child)
        HStack(spacing: 14) {
            ChildAvatar(child: child, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(child.name).font(.headline)
                if let latest {
                    let band = child.targets.band(for: latest.mgdL)
                    Text("\(child.unit.formatWithUnit(latest.mgdL)) · \(band.title) · \(GlucoseAnalytics.ageDescription(of: latest.date))")
                        .font(.subheadline)
                        .foregroundStyle(band.isUrgent || band == .low ? Color.red : .secondary)
                } else {
                    Text("No readings yet").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if model.household.kidModeChildID == child.id {
                Image(systemName: "lock.fill").foregroundStyle(.orange).accessibilityLabel("Kid Mode on")
            }
        }
        .padding(.vertical, 4)
    }
}

/// One child's Parent Dashboard.
struct ChildDashboardView: View {
    @Environment(AppModel.self) private var model
    var childID: UUID

    enum Sheet: String, Identifiable {
        case edit, school, setPIN, logReading, logMeal, logInsulin
        var id: String { rawValue }
    }

    @State private var sheet: Sheet?
    @State private var openedLaunchScreen = false

    var body: some View {
        if let child = model.child(childID) {
            content(child)
        } else {
            ContentUnavailableView("Profile removed", systemImage: "person.crop.circle.badge.xmark")
        }
    }

    private func content(_ child: ChildProfile) -> some View {
        let readings = model.readings(for: child)
        let latest = readings.last
        let now = Date.now
        let day = DateInterval(start: now.addingTimeInterval(-86_400), end: now)
        let today = DateInterval(start: Calendar.current.startOfDay(for: now), end: now)
        let week = DateInterval(start: now.addingTimeInterval(-7 * 86_400), end: now)
        let todayStats = GlucoseAnalytics.stats(for: readings, in: today, targets: child.targets)
        let weekStats = GlucoseAnalytics.stats(for: readings, in: week, targets: child.targets)
        let summary = WeeklySummary(child: child, samples: readings, meals: model.meals(for: child),
                                    insulin: model.insulin(for: child), ledger: model.ledger(for: child), now: now)
        let night = Self.lastNight(now: now)
        let nightReadings = readings.filter { night.contains($0.date) }
        let stale = latest.map { GlucoseAnalytics.isStale($0, now: now) } ?? true

        return ScrollView {
            VStack(spacing: 16) {
                if model.isDemo { DemoBanner() }
                Card {
                    HStack(spacing: 14) {
                        ChildAvatar(child: child, size: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            if let latest {
                                let band = child.targets.band(for: latest.mgdL)
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text(child.unit.format(latest.mgdL))
                                        .font(.system(size: 44, weight: .bold, design: .rounded))
                                        .foregroundStyle(stale ? Color.secondary : band.color)
                                    Text(child.unit.symbol).foregroundStyle(.secondary)
                                    if !stale, let trend = GlucoseAnalytics.trend(from: Array(readings.suffix(12))) {
                                        Text(trend.symbol).font(.title).foregroundStyle(band.color)
                                            .accessibilityLabel(trend.accessibilityLabel)
                                    }
                                }
                                // Shrink rather than wrap or widen the page.
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                Text("\(band.title) · \(GlucoseAnalytics.ageDescription(of: latest.date))")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            } else {
                                Text("No readings yet").font(.title3.bold())
                            }
                        }
                        Spacer()
                        GluMascot(mood: MascotMood.current(latestBand: latest.map { child.targets.band(for: $0.mgdL) },
                                                            isStale: stale, todayInRange: todayStats.inRangeFraction),
                                  colorID: model.ledger(for: child).equippedColor, size: 44)
                    }
                }

                actions(child)

                Card(title: "Last 24 hours") {
                    GlucoseChart(samples: readings.filter { day.contains($0.date) },
                                 meals: model.meals(for: child).filter { day.contains($0.date) },
                                 insulin: model.insulin(for: child).filter { day.contains($0.date) },
                                 targets: child.targets, unit: child.unit, domain: day.start...day.end)
                        .frame(height: 220)
                    ChartLegend(showInsulin: true)
                }

                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        StatTile(title: "\(todayStats.inRangeLabel) today", value: Format.percent(todayStats.inRangeFraction))
                        StatTile(title: "Last 7 days", value: Format.percent(weekStats.inRangeFraction))
                    }
                    GridRow {
                        StatTile(title: "Lows today", value: "\(todayStats.lowEpisodes)")
                        StatTile(title: "Highs today", value: "\(todayStats.highEpisodes)")
                    }
                }

                Card(title: "Overnight") {
                    if nightReadings.isEmpty {
                        Text("No readings last night.").foregroundStyle(.secondary)
                    } else {
                        GlucoseChart(samples: nightReadings, targets: child.targets, unit: child.unit, domain: night.start...night.end)
                            .frame(height: 160)
                        let nightStats = GlucoseAnalytics.stats(for: nightReadings, in: night, targets: child.targets)
                        Text("\(night.start.formatted(date: .omitted, time: .shortened))–\(night.end.formatted(date: .omitted, time: .shortened)) · lowest \(nightStats.minimum.map(child.unit.formatWithUnit) ?? "—") · \(nightStats.lowEpisodes) low\(nightStats.lowEpisodes == 1 ? "" : "s")")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Card(title: "This week") {
                    ForEach(summary.highlights, id: \.self) { line in
                        Label(line, systemImage: "circle.fill").labelStyle(BulletLabelStyle())
                    }
                    Text("Patterns in \(child.firstName)'s readings, not medical advice. Share them with the care team.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                DisclaimerFooter()
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(child.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { sheet = .edit }
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .edit: ChildEditorView(child: child)
            case .school: SchoolModeView(child: child)
            case .setPIN: SetPINView { if model.hasParentPIN { model.enterKidMode(child) } }
            case .logReading: ParentLogReadingView(child: child)
            case .logMeal: ParentLogMealView(child: child)
            case .logInsulin: LogInsulinView(child: child)
            }
        }
        .onAppear {
            guard !openedLaunchScreen else { return }
            openedLaunchScreen = true
            switch model.options.parentScreen {
            case "school": sheet = .school
            case "editor": sheet = .edit
            default: break
            }
        }
    }

    private func actions(_ child: ChildProfile) -> some View {
        VStack(spacing: 10) {
            if child.kidModeEnabled {
                Button {
                    if model.hasParentPIN { model.enterKidMode(child) } else { sheet = .setPIN }
                } label: {
                    Label("Start Kid Mode for \(child.firstName)", systemImage: "face.smiling")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            HStack {
                Menu {
                    Button { sheet = .logReading } label: { Label("Glucose reading", systemImage: "drop") }
                    Button { sheet = .logMeal } label: { Label("Meal", systemImage: "fork.knife") }
                    if child.diabetesType == .type1 {
                        Button { sheet = .logInsulin } label: { Label("Insulin (log only)", systemImage: "syringe") }
                    }
                } label: {
                    Label("Log", systemImage: "plus.circle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button { sheet = .school } label: {
                    Label("School Mode", systemImage: "graduationcap").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
        }
    }

    /// 10 pm yesterday to 7 am today (or the night before, if it's still evening).
    static func lastNight(now: Date, calendar: Calendar = .current) -> DateInterval {
        var day = calendar.startOfDay(for: now)
        if calendar.component(.hour, from: now) < 7 {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        let end = calendar.date(byAdding: .hour, value: 7, to: day) ?? now
        let start = calendar.date(byAdding: .hour, value: -2, to: day) ?? now
        return DateInterval(start: start, end: min(end, now))
    }
}

struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon.font(.system(size: 6)).foregroundStyle(.secondary)
            configuration.title.font(.subheadline)
        }
    }
}

struct ChartLegend: View {
    var showInsulin: Bool

    var body: some View {
        HStack(spacing: 14) {
            Label("Meal", systemImage: "fork.knife").foregroundStyle(.orange)
            if showInsulin { Label("Insulin", systemImage: "syringe").foregroundStyle(.purple) }
            Label("Target", systemImage: "square.fill").foregroundStyle(GlucoseBand.inRange.color.opacity(0.5))
        }
        .font(.caption)
    }
}

/// A parent logs a reading for a child.
struct ParentLogReadingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var child: ChildProfile

    @State private var valueText = ""
    @State private var date = Date.now
    @State private var context: ReadingContext = .other

    private var mgdL: Double? {
        Double(valueText.replacingOccurrences(of: ",", with: ".")).map(child.unit.mgdL(from:))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Reading", text: $valueText).keyboardType(.decimalPad)
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                        Text(child.unit.symbol).foregroundStyle(.secondary)
                    }
                    if let mgdL, !SafetyGuidance.plausibleRange.contains(mgdL) {
                        Text("That doesn't look like a valid reading.").foregroundStyle(.red).font(.footnote)
                    }
                    DatePicker("Time", selection: $date, in: ...Date.now)
                    Picker("When", selection: $context) {
                        ForEach(ReadingContext.allCases) { Text($0.title).tag($0) }
                    }
                }
            }
            .navigationTitle("Reading for \(child.firstName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let mgdL else { return }
                        Task {
                            if await model.logGlucose(for: child, mgdL: mgdL, date: date, context: context) { dismiss() }
                        }
                    }
                    .disabled(mgdL.map { !SafetyGuidance.plausibleRange.contains($0) } ?? true)
                }
            }
        }
    }
}

/// A parent logs a meal for a child.
struct ParentLogMealView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var child: ChildProfile

    @State private var kind = MealKind.suggested(for: .now)
    @State private var name = ""
    @State private var carbs: Double = 40
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Picker("Meal", selection: $kind) {
                    ForEach(MealKind.allCases) { Text($0.title).tag($0) }
                }
                TextField("What was it? (optional)", text: $name)
                Stepper(value: $carbs, in: 0...300, step: 5) {
                    LabeledContent("Carbohydrates", value: "\(Int(carbs)) g")
                }
                DatePicker("Time", selection: $date, in: ...Date.now)
            }
            .navigationTitle("Meal for \(child.firstName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let meal = MealEvent(date: date, kind: kind, name: name, carbsGrams: carbs)
                        Task { if await model.logMeal(meal, for: child) { dismiss() } }
                    }
                }
            }
        }
    }
}

/// Set the 4-digit parent PIN that's needed to leave Kid Mode.
struct SetPINView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var onDone: () -> Void = {}

    @State private var first: String?
    @State private var prompt = "Choose a 4-digit parent PIN. You'll need it to leave Kid Mode."

    var body: some View {
        VStack(spacing: 24) {
            Text("Parent PIN").font(.title.bold())
            PINPad(prompt: prompt) { pin in
                if let first {
                    guard pin == first else {
                        self.first = nil
                        prompt = "Those didn't match. Choose a PIN again."
                        return false
                    }
                    model.setParentPIN(pin)
                    dismiss()
                    onDone()
                    return true
                }
                first = pin
                prompt = "Enter the same PIN again to confirm."
                return true
            }
            .id(first == nil ? "first" : "confirm")
            Text("Kids can't leave Kid Mode without it. It's stored only on this iPhone.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Cancel") { dismiss() }
        }
        .padding()
    }
}
