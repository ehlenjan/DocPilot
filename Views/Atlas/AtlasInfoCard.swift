import SwiftUI

struct AtlasInfoCard: View {

    let analysis: AtlasAnalysis?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                "Erkannte Informationen",
                systemImage: "doc.text.magnifyingglass"
            )
            .font(.headline)

            if let analysis {
                infoRow(
                    icon: "doc.text",
                    title: "Dokumentart",
                    value: analysis.documentType.rawValue
                )

                Divider()

                infoRow(
                    icon: "building.2",
                    title: "Absender",
                    value: analysis.sender ?? "Nicht erkannt"
                )

                Divider()

                infoRow(
                    icon: "calendar",
                    title: "Datum",
                    value: formattedDate(analysis.detectedDate)
                )

                if !analysis.keywords.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Label(
                            "Schlüsselwörter",
                            systemImage: "tag"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Text(
                            analysis.keywords.joined(
                                separator: ", "
                            )
                        )
                        .font(.callout)
                        .textSelection(.enabled)
                    }
                }
            } else {
                Text("Noch keine Analyse vorhanden.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(.quaternary)
        }
    }

    private func infoRow(
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
    AtlasInfoCard(
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
            reasons: [
                "Dokumentart Rechnung erkannt"
            ]
        )
    )
    .padding()
    .frame(width: 420)
}
