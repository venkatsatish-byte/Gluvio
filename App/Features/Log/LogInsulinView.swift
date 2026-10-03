import GlucoseCore
import SwiftUI

/// Records insulin that was taken. LOG ONLY: there is no calculator, no
/// suggested amount and no carb ratio anywhere in Gluvio.
struct LogInsulinView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var child: ChildProfile?

    @State private var kind: InsulinKind = .rapid
    @State private var unitsText = ""
    @State private var date = Date.now
    @State private var note = ""
    @State private var isSaving = false

    private var units: Double? { Double(unitsText.replacingOccurrences(of: ",", with: ".")) }

    private var problem: String? {
        guard !unitsText.isEmpty else { return nil }
        guard let units else { return "Enter a number." }
        guard InsulinDose.plausibleUnits.contains(units) else { return "Check the amount you entered." }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(InsulinCopy.logOnlyNotice, systemImage: "info.circle")
                        .font(.footnote)
                }
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(InsulinKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        TextField("Units taken", text: $unitsText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                        Text("units").foregroundStyle(.secondary)
                    }
                    if let problem { Text(problem).foregroundStyle(.red).font(.footnote) }
                    DatePicker("Time", selection: $date, in: ...Date.now)
                    TextField("Note (optional)", text: $note)
                }
                Section {
                    Text(child == nil || child?.usesAppleHealth == true
                         ? "Saved in Gluvio and to Apple Health as insulin delivery."
                         : "Saved in Gluvio on this iPhone.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(child.map { "Insulin for \($0.firstName)" } ?? "Log insulin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let units else { return }
                        isSaving = true
                        let dose = InsulinDose(date: date, units: units, kind: kind, note: note)
                        Task {
                            let saved = await model.logInsulin(dose, for: child)
                            isSaving = false
                            if saved { dismiss() }
                        }
                    }
                    .disabled(units == nil || problem != nil || isSaving)
                }
            }
        }
    }
}
