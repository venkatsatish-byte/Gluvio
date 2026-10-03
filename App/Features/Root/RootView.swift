import GlucoseCore
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Group {
            if let child = model.kidModeChild, model.profile.hasCompletedOnboarding {
                // Kid Mode takes over the whole app until a parent enters the PIN.
                KidModeView(child: child)
            } else if model.profile.hasCompletedOnboarding && model.profile.hasAcceptedCurrentDisclaimer {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .fullScreenCover(item: Binding(
            get: { model.kidModeChild == nil ? model.urgentAlert : nil },
            set: { model.urgentAlert = $0 }
        )) { alert in
            UrgentGuidanceView(alert: alert)
        }
    }
}

struct MainTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            if model.isCaregiver {
                FamilyHomeView()
                    .tabItem { Label("Family", systemImage: "figure.2.and.child.holdinghands") }
                    .tag(AppTab.family)
            } else {
                TodayView()
                    .tabItem { Label("Today", systemImage: "drop.fill") }
                    .tag(AppTab.today)
                TrendsView()
                    .tabItem { Label("Trends", systemImage: "chart.xyaxis.line") }
                    .tag(AppTab.trends)
                MealsView()
                    .tabItem { Label("Meals", systemImage: "fork.knife") }
                    .tag(AppTab.meals)
            }
            GuideView()
                .tabItem { Label("Guide", systemImage: "leaf") }
                .tag(AppTab.guide)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
    }
}

/// Which logging sheet is open.
enum LogKind: String, Identifiable {
    case glucose, meal, water, insulin
    var id: String { rawValue }
}

struct LogSheet: View {
    var kind: LogKind

    var body: some View {
        switch kind {
        case .glucose: LogGlucoseView()
        case .meal: LogMealView()
        case .water: LogWaterView()
        case .insulin: LogInsulinView()
        }
    }
}

/// The "+" menu used on several screens.
struct LogMenu: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: LogKind?

    var body: some View {
        Menu {
            Button { selection = .glucose } label: { Label("Glucose reading", systemImage: "drop") }
            Button { selection = .meal } label: { Label("Meal", systemImage: "fork.knife") }
            if model.profile.accountType.logsInsulin {
                Button { selection = .insulin } label: { Label("Insulin (log only)", systemImage: "syringe") }
            }
            Button { selection = .water } label: { Label("Water", systemImage: "waterbottle") }
        } label: {
            Image(systemName: "plus.circle.fill").font(.title2)
        }
        .accessibilityLabel("Log")
    }
}
