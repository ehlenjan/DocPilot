import SwiftUI

struct LearningListView: View {

    let entries: [LearningEntry]

    var body: some View {

        AtlasCard {

            VStack(alignment: .leading, spacing: 14) {

                Label(
                    "Gelernte Zuordnungen",
                    systemImage: "brain"
                )
                .font(.headline)

                if entries.isEmpty {

                    Text("Atlas hat bisher noch nichts gelernt.")
                        .foregroundStyle(.secondary)

                } else {

                    ForEach(entries) { entry in

                        VStack(alignment: .leading, spacing: 4) {

                            Text(entry.company ?? "Unbekannt")
                                .font(.headline)

                            Text(
                                "\(entry.archiveArea.rawValue) → \(entry.folder)"
                            )
                            .foregroundStyle(.secondary)

                        }

                        if entry.id != entries.last?.id {
                            Divider()
                        }

                    }

                }

            }

        }

    }

}

#Preview {

    LearningListView(
        entries: [
            LearningEntry(
                company: "RAISA",
                documentType: .invoice,
                keywords: [],
                archiveArea: .ehaKG,
                folder: "Lieferscheine"
            ),
            LearningEntry(
                company: "BayWa",
                documentType: .invoice,
                keywords: [],
                archiveArea: .ehaKG,
                folder: "Rechnungen"
            )
        ]
    )
    .padding()
    .frame(width: 420)

}
