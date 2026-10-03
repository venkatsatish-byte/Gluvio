import GlucoseCore
import PhotosUI
import SwiftUI

/// Create or edit a child profile. Only the parent can reach this screen.
struct ChildEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var child: ChildProfile
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var confirmingDelete = false
    private let isNew: Bool

    init(child: ChildProfile) {
        _child = State(initialValue: child)
        isNew = child.name.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                aboutSection
                readingsSection
                Section {
                    TargetStepper(title: "Low end of range", value: $child.targets.low, unit: child.unit, range: 60...110)
                    TargetStepper(title: "High end of range", value: $child.targets.high, unit: child.unit, range: 120...250)
                    TargetStepper(title: "Very low below", value: $child.targets.urgentLow, unit: child.unit, range: 40...65)
                    TargetStepper(title: "Very high above", value: $child.targets.urgentHigh, unit: child.unit, range: 200...400)
                    if !child.targets.isValid {
                        Text("Thresholds must be in order: very low < low < high < very high.").foregroundStyle(.red)
                    }
                } header: {
                    Text("Target range")
                } footer: {
                    Text("Use the numbers from \(child.firstName.isEmpty ? "your child" : child.firstName)'s care team.")
                }
                carePlanSection
                contactsSection
                alertsSection
                Section {
                    Toggle("Allow Kid Mode", isOn: $child.kidModeEnabled)
                } footer: {
                    Text("Kid Mode shows a simple, colorful screen with Glu, quests and the \"I'm low\" button. Leaving it needs your parent PIN.")
                }
                if !isNew {
                    Section {
                        Button("Delete \(child.firstName)'s profile", role: .destructive) { confirmingDelete = true }
                    } footer: {
                        Text("Removes the profile and everything Gluvio stored for it on this iPhone.")
                    }
                }
            }
            .navigationTitle(isNew ? "Add a child" : "Edit \(child.firstName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(child.name.trimmingCharacters(in: .whitespaces).isEmpty || !child.targets.isValid)
                }
            }
            .confirmationDialog("Delete \(child.firstName)'s profile?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    model.deleteChild(child)
                    dismiss()
                }
            }
            .onChange(of: photoItem) { _, item in
                Task { photoData = try? await item?.loadTransferable(type: Data.self) }
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            TextField("First name", text: $child.name)
                .textContentType(.givenName)
            Stepper(value: $child.age, in: 1...18) {
                LabeledContent("Age", value: "\(child.age)")
            }
            Picker("Diabetes", selection: $child.diabetesType) {
                ForEach(DiabetesType.allCases) { Text($0.title).tag($0) }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Avatar")
                HStack {
                    ForEach(0..<AvatarStyle.colorCount, id: \.self) { index in
                        Circle().fill(KidTheme.avatarColors[index])
                            .frame(width: 28, height: 28)
                            .overlay(Circle().stroke(Color.primary, lineWidth: child.avatar.colorIndex == index ? 2 : 0))
                            .onTapGesture { child.avatar.colorIndex = index }
                            .accessibilityAddTraits(.isButton)
                    }
                }
                HStack {
                    ForEach(AvatarStyle.symbols, id: \.self) { symbol in
                        Image(systemName: symbol)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(child.avatar.symbol == symbol ? Color.accentColor.opacity(0.25) : .clear))
                            .onTapGesture { child.avatar.symbol = symbol }
                            .accessibilityAddTraits(.isButton)
                    }
                }
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(child.hasPhoto || photoData != nil ? "Change photo (optional)" : "Add photo (optional)", systemImage: "camera")
            }
            if child.hasPhoto || photoData != nil {
                Button("Remove photo", role: .destructive) {
                    photoData = nil
                    photoItem = nil
                    child.hasPhoto = false
                }
            }
        }
    }

    private var readingsSection: some View {
        Section {
            Picker("Units", selection: $child.unit) {
                ForEach(GlucoseUnit.allCases) { Text($0.symbol).tag($0) }
            }
            Toggle("Uses a CGM", isOn: $child.usesCGM)
            Toggle("Readings come from Apple Health on this iPhone", isOn: $child.usesAppleHealth)
        } header: {
            Text("Readings")
        } footer: {
            Text("Turn this on only if \(child.firstName.isEmpty ? "your child" : child.firstName)'s CGM or meter app writes to Apple Health on this iPhone. Otherwise, log readings in Gluvio. Only one child can be linked.")
        }
    }

    private var carePlanSection: some View {
        Group {
            Section {
                TextEditor(text: $child.carePlanLow)
                    .frame(minHeight: 110)
                Stepper(value: $child.recheckMinutes, in: 5...60, step: 5) {
                    LabeledContent("Recheck timer", value: "\(child.recheckMinutes) min")
                }
            } header: {
                Text("Care plan: lows")
            } footer: {
                Text("Copy the steps from the care team's plan, one per line. The \"I'm low\" screen shows them exactly as written, with the recheck timer. Gluvio never adds its own advice.")
            }
            Section {
                TextEditor(text: $child.carePlanHigh)
                    .frame(minHeight: 90)
            } header: {
                Text("Care plan: highs")
            } footer: {
                Text("Shown in School Mode, exactly as written.")
            }
        }
    }

    private var contactsSection: some View {
        Section {
            ForEach($child.emergencyContacts) { $contact in
                VStack(alignment: .leading) {
                    TextField("Name", text: $contact.name)
                    TextField("Relationship (e.g. Mom, school nurse)", text: $contact.relation)
                        .font(.subheadline)
                    TextField("Phone", text: $contact.phone)
                        .keyboardType(.phonePad)
                        .font(.subheadline)
                }
            }
            .onDelete { child.emergencyContacts.remove(atOffsets: $0) }
            Button {
                child.emergencyContacts.append(EmergencyContact())
            } label: {
                Label("Add contact", systemImage: "plus")
            }
        } header: {
            Text("Emergency contacts")
        } footer: {
            Text("Shown on the \"I'm low\" screen and in School Mode.")
        }
    }

    private var alertsSection: some View {
        Section {
            Toggle("Alerts on this iPhone", isOn: $child.alerts.isEnabled)
            if child.alerts.isEnabled {
                TargetStepper(title: "Alert below", value: $child.alerts.lowThreshold, unit: child.unit, range: 55...120)
                TargetStepper(title: "Alert above", value: $child.alerts.highThreshold, unit: child.unit, range: 150...400)
                Toggle("Only alert when out of range", isOn: $child.alerts.onlyOutOfRange)
                Toggle("Quiet hours", isOn: $child.alerts.quietHoursEnabled)
                if child.alerts.quietHoursEnabled {
                    DatePicker("From", selection: minutesBinding(\.quietStart), displayedComponents: .hourAndMinute)
                    DatePicker("Until", selection: minutesBinding(\.quietEnd), displayedComponents: .hourAndMinute)
                }
            }
        } header: {
            Text("Alerts")
        } footer: {
            Text("Very low readings (below \(child.unit.formatWithUnit(child.targets.urgentLow))) always alert, even during quiet hours. Alerts appear on this iPhone only and can be late or missed, so they don't replace the CGM's own alarms.")
        }
    }

    private func minutesBinding(_ keyPath: WritableKeyPath<ChildAlertSettings, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = child.alerts[keyPath: keyPath]
                return Calendar.current.date(from: DateComponents(hour: minutes / 60, minute: minutes % 60)) ?? .now
            },
            set: {
                let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
                child.alerts[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }

    private func save() {
        child.name = child.name.trimmingCharacters(in: .whitespaces)
        child.emergencyContacts.removeAll { $0.name.isEmpty && $0.phone.isEmpty }
        if let photoData, ChildPhotoStore.save(photoData, for: child.id) {
            child.hasPhoto = true
        } else if !child.hasPhoto {
            ChildPhotoStore.delete(child.id)
        }
        model.saveChild(child)
        Task { _ = await model.scheduler.requestPermission() }
        dismiss()
    }
}
