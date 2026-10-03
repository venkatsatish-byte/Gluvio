import GlucoseCore
import SwiftUI

/// The "I'm low" screen. Shows ONLY the steps the parent typed from the care
/// team's plan, a recheck countdown, and ways to reach grown-ups. Gluvio adds
/// no treatment advice of its own.
struct LowHelpView: View {
    @Environment(AppModel.self) private var model
    var child: ChildProfile

    @State private var endsAt = Date.now
    @State private var composing = false

    private var contactsWithPhones: [EmergencyContact] {
        child.emergencyContacts.filter { !$0.phone.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var messageText: String {
        "\(child.firstName) pressed \"I'm low\" in Gluvio at \(Date.now.formatted(date: .omitted, time: .shortened))."
            + (model.latest(for: child).map { " Last reading: \(child.unit.formatWithUnit($0.mgdL)) (\(GlucoseAnalytics.ageDescription(of: $0.date)))." } ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Let's get help, \(child.firstName)")
                    .font(KidTheme.font(36, .heavy))

                let steps = child.carePlanLowSteps
                if steps.isEmpty {
                    Text("Get a grown-up right now.")
                        .font(KidTheme.font(30, .bold))
                    Text("Your grown-up hasn't added your care plan to Gluvio yet.")
                        .font(KidTheme.font(20, .medium))
                } else {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 14) {
                            Text("\(index + 1)")
                                .font(KidTheme.font(26, .heavy))
                                .frame(width: 46, height: 46)
                                .background(Circle().fill(.white))
                                .foregroundStyle(.orange)
                            Text(step)
                                .font(KidTheme.font(26, .semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Text("From your care plan")
                        .font(KidTheme.font(14, .medium))
                        .opacity(0.85)
                }

                countdown

                VStack(spacing: 12) {
                    if !contactsWithPhones.isEmpty {
                        Button {
                            composing = true
                        } label: {
                            Label("Text my grown-ups", systemImage: "message.fill")
                                .font(KidTheme.font(24, .bold))
                                .frame(maxWidth: .infinity, minHeight: 70)
                        }
                        .buttonStyle(KidButtonStyle(color: .blue))
                    }
                    ForEach(contactsWithPhones) { contact in
                        if let url = URL(string: "tel:" + contact.phone.filter { $0.isNumber || $0 == "+" }) {
                            Link(destination: url) {
                                Label("Call \(contact.name)", systemImage: "phone.fill")
                                    .font(KidTheme.font(22, .bold))
                                    .frame(maxWidth: .infinity, minHeight: 64)
                            }
                            .buttonStyle(KidButtonStyle(color: .green))
                        }
                    }
                    Button {
                        model.closeLowHelp()
                    } label: {
                        Text("A grown-up is helping me")
                            .font(KidTheme.font(20, .semibold))
                            .frame(maxWidth: .infinity, minHeight: 58)
                    }
                    .buttonStyle(KidButtonStyle(color: .gray))
                }

                Text(SafetyCopy.shortDisclaimer)
                    .font(KidTheme.font(13, .regular))
                    .opacity(0.85)
            }
            .padding(24)
            .foregroundStyle(.white)
        }
        .background(LinearGradient(colors: [Color.orange, Color(red: 0.95, green: 0.35, blue: 0.25)],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .onAppear { endsAt = Date.now.addingTimeInterval(TimeInterval(child.recheckMinutes * 60)) }
        .sheet(isPresented: $composing) {
            if MessageComposer.canSend {
                MessageComposer(recipients: contactsWithPhones.map(\.phone), body: messageText) { composing = false }
            } else {
                // Simulators and iPads without Messages: share the text instead.
                VStack(spacing: 16) {
                    Text("Messages isn't available on this device.").font(KidTheme.font(20, .semibold))
                    ShareLink(item: messageText) { Label("Share the message", systemImage: "square.and.arrow.up") }
                    Button("Close") { composing = false }
                }
                .padding()
                .presentationDetents([.medium])
            }
        }
        .interactiveDismissDisabled()
    }

    private var countdown: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, endsAt.timeIntervalSince(context.date))
            let total = Double(max(1, child.recheckMinutes) * 60)
            VStack(spacing: 8) {
                ZStack {
                    Circle().stroke(.white.opacity(0.3), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: remaining / total)
                        .stroke(.white, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(remaining > 0 ? Self.clock(remaining) : "Check now!")
                        .font(KidTheme.font(remaining > 0 ? 40 : 30, .heavy))
                        .monospacedDigit()
                }
                .frame(width: 180, height: 180)
                Text(remaining > 0 ? "Check again when the timer ends" : "Time to check again")
                    .font(KidTheme.font(20, .semibold))
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
