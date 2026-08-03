import SwiftUI

struct AtlasQuickFactsCard: View {

    let analysis: AtlasAnalysis?

    var body: some View {
        AtlasCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(
                    "Schnellübersicht",
                    systemImage: "list.bullet.rectangle"
                )
                .font(.headline)

                if let analysis {
                    factRow(
                        icon: "building.2",
                        title: "Firma",
                        value: analysis.sender ?? "Nicht erkannt"
                    )

                    Divider()

                    factRow(
                        icon: "doc.text",
                        title: "Dokumentart",
                        value: analysis.documentType.rawValue
                    )

                    Divider()

                    factRow(
                        icon: "tag",
                        title: "Schlüsselwörter",
                        value: "\(analysis.keywords.count) erkannt"
                    )

                    Divider()

                    factRow(
                        icon: "calendar",
                        title: "Datum",
                        value: formattedDate(
                            analysis.detectedDate
                        )
                    )
                } else {
                    Text("Noch keine Analyse vorhanden.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func factRow(
        icon: String,
        title: String,
        value: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.headline)
            }

            Spacer()
        }
    }

    private func formattedDate(
        _ date: Date?
    ) -> String {
        guard let date else {
            return "Nicht erkannt"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(
            identifier: "de_DE"
        )
        formatter.dateStyle = .medium

        return formatter.string(
            from: date
        )
    }
}

#Preview {
    AtlasQuickFactsCard(
        analysis: AtlasAnalysis(
            documentType: .invoice,
            detectedDate: Date(),
            sender: "RAISA",
            keywords: [
                "Rechnung",
                "Futtermittel",
                "VzF"
            ],
            confidence: 0.91,
            reasons: []
        )
    )
    .padding()
    .frame(width: 380)
}
