import GlucoseCore
import SwiftUI

/// A read-only sheet for school staff: who the child is, their care-plan steps
/// and who to call. Shareable as a PDF.
struct SchoolModeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var child: ChildProfile

    @State private var pdfURL: URL?

    var body: some View {
        let latest = model.latest(for: child)
        NavigationStack {
            ScrollView {
                SchoolSheet(child: child, latest: latest, photo: child.hasPhoto ? ChildPhotoStore.load(child.id) : nil)
                    .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("School Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    if let pdfURL {
                        ShareLink(item: pdfURL) { Image(systemName: "square.and.arrow.up") }
                    } else {
                        Button("PDF") { pdfURL = Self.makePDF(child: child, latest: latest) }
                    }
                }
            }
        }
    }

    @MainActor
    static func makePDF(child: ChildProfile, latest: GlucoseSample?) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(child.firstName) - school sheet.pdf")
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }
        let page = SchoolSheet(child: child, latest: latest, photo: child.hasPhoto ? ChildPhotoStore.load(child.id) : nil)
            .padding(36)
            .frame(width: 612, height: 792, alignment: .top)
            .background(.white)
            .environment(\.colorScheme, .light)
        ImageRenderer(content: page).render { _, draw in
            pdf.beginPDFPage(nil)
            draw(pdf)
            pdf.endPDFPage()
        }
        pdf.closePDF()
        return url
    }
}

struct SchoolSheet: View {
    var child: ChildProfile
    var latest: GlucoseSample?
    var photo: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Group {
                    if let photo {
                        Image(uiImage: photo).resizable().scaledToFill()
                    } else {
                        ChildAvatar(child: child, size: 84)
                    }
                }
                .frame(width: 84, height: 84)
                .clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(child.name).font(.largeTitle.bold())
                    Text("Age \(child.age) · \(child.diabetesType.title) diabetes").font(.title3)
                    Text("Target range \(child.unit.format(child.targets.low))–\(child.unit.formatWithUnit(child.targets.high))")
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox("Current reading") {
                if let latest, Date.now.timeIntervalSince(latest.date) < 60 * 60 {
                    let band = child.targets.band(for: latest.mgdL)
                    Text("\(child.unit.formatWithUnit(latest.mgdL)) · \(band.title) · at \(latest.date.formatted(date: .omitted, time: .shortened))")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("No reading in the last hour. Check the child's meter or CGM.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            steps("If \(child.firstName) is low (below \(child.unit.formatWithUnit(child.targets.low)))", child.carePlanLowSteps)
            steps("If \(child.firstName) is high (above \(child.unit.formatWithUnit(child.targets.high)))", child.carePlanHighSteps)

            GroupBox("Emergency contacts") {
                VStack(alignment: .leading, spacing: 8) {
                    if child.emergencyContacts.isEmpty {
                        Text("None added.").foregroundStyle(.secondary)
                    }
                    ForEach(child.emergencyContacts) { contact in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(contact.name).bold()
                                if !contact.relation.isEmpty { Text(contact.relation).font(.caption).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            Text(contact.phone).monospacedDigit()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("In an emergency, call your local emergency number. \(SafetyCopy.shortDisclaimer) Steps above are from \(child.firstName)'s care team, entered by a parent.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func steps(_ title: String, _ steps: [String]) -> some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 6) {
                if steps.isEmpty {
                    Text("No steps added. Ask the parent for the care plan.").foregroundStyle(.secondary)
                }
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    Text("\(index + 1). \(step)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
