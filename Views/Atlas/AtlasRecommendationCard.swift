import SwiftUI

struct AtlasRecommendationCard: View {

    let analysis: AtlasAnalysis?
    let folderSuggestion: FolderSuggestion?

    var body: some View {
        AtlasCard {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let analysis {
                    recommendationContent(for: analysis)
                } else {
                    emptyState
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "brain.head.profile")
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Atlas")
                    .font(.headline)

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
        }
    }

    private func recommendationContent(
        for analysis: AtlasAnalysis
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let folderSuggestion {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Ich würde dieses Dokument nach")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Label(
                        folderSuggestion.displayPath,
                        systemImage: "folder.fill"
                    )
                    .font(.title3.bold())

                    Text("ablegen.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(
                    "Ich habe noch keinen eindeutigen Zielordner gefunden."
                )
                .font(.title3)
            }

            confidenceSection

            Divider()

            VStack(alignment: .leading, spacing: 9) {
                Text("Ich habe erkannt")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if analysis.documentType != .unknown {
                    factRow(
                        icon: "doc.text",
                        text: analysis.documentType.rawValue
                    )
                }

                if let sender = analysis.sender {
                    factRow(
                        icon: "building.2",
                        text: sender
                    )
                }

                if !analysis.keywords.isEmpty {
                    factRow(
                        icon: "tag",
                        text: "\(analysis.keywords.count) Schlüsselwörter"
                    )
                }

                ForEach(
                    learningFacts,
                    id: \.self
                ) { fact in
                    factRow(
                        icon: "brain",
                        text: fact
                    )
                }
            }
        }
    }

    private var confidenceSection: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 11, height: 11)

            VStack(alignment: .leading, spacing: 2) {
                Text(confidenceTitle)
                    .font(.headline)

                Text(confidenceSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(confidencePercentage) %")
                .font(.title3.bold())
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Noch keine Empfehlung")
                .font(.title3.bold())

            Text(
                "Atlas analysiert das Dokument und schlägt anschließend einen Dateinamen und Zielordner vor."
            )
            .foregroundStyle(.secondary)
        }
    }

    private func factRow(
        icon: String,
        text: String
    ) -> some View {
        Label(
            text,
            systemImage: icon
        )
        .font(.callout)
    }

    private var effectiveConfidence: Double {
        folderSuggestion?.confidence
            ?? analysis?.confidence
            ?? 0
    }

    private var confidencePercentage: Int {
        Int((effectiveConfidence * 100).rounded())
    }

    private var confidenceTitle: String {
        switch effectiveConfidence {
        case 0.90...:
            return "Sehr hohe Sicherheit"

        case 0.75..<0.90:
            return "Hohe Sicherheit"

        case 0.50..<0.75:
            return "Bitte kurz prüfen"

        default:
            return "Unsichere Zuordnung"
        }
    }

    private var confidenceSubtitle: String {
        switch effectiveConfidence {
        case 0.90...:
            return "Mehrere eindeutige Merkmale stimmen überein."

        case 0.75..<0.90:
            return "Der Vorschlag ist wahrscheinlich richtig."

        case 0.50..<0.75:
            return "Einige Merkmale passen, andere sind noch unklar."

        default:
            return "Atlas benötigt deine Unterstützung."
        }
    }

    private var statusText: String {
        analysis == nil
            ? "Bereit zur Analyse"
            : confidenceTitle
    }

    private var statusColor: Color {
        switch effectiveConfidence {
        case 0.90...:
            return .green

        case 0.75..<0.90:
            return .yellow

        case 0.50..<0.75:
            return .orange

        default:
            return .red
        }
    }

    private var learningFacts: [String] {
        guard let folderSuggestion else {
            return []
        }

        return folderSuggestion.reasons.compactMap { reason in
            let normalized = reason.lowercased()

            if normalized.contains("ähnliche dokumente") {
                return reason
            }

            if normalized.contains("bestätigt") {
                return reason
            }

            if normalized.contains("gelernte zuordnung") {
                return reason
            }

            return nil
        }
    }
}

#Preview {
    AtlasRecommendationCard(
        analysis: AtlasAnalysis(
            documentType: .invoice,
            detectedDate: Date(),
            sender: "RWG",
            keywords: [
                "Rechnung",
                "Saatgut",
                "Pflanzenschutz",
                "Acker"
            ],
            confidence: 0.95,
            reasons: []
        ),
        folderSuggestion: FolderSuggestion(
            ruleName: "Betrieb Belege",
            area: .business,
            folder: "Belege",
            confidence: 0.95,
            reasons: [
                "Atlas hat ähnliche Dokumente gefunden (105 Punkte)",
                "Gelernte Zuordnung bestätigt den Regelvorschlag"
            ]
        )
    )
    .padding()
    .frame(width: 390)
}
