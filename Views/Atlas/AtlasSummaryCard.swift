import SwiftUI

struct AtlasSummaryCard: View {

    let analysis: AtlasAnalysis?
    let folderSuggestion: FolderSuggestion?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                "Atlas sagt",
                systemImage: "sparkles"
            )
            .font(.headline)

            Text(summaryText)
                .font(.callout)
                .lineSpacing(4)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 9, height: 9)

                Text(statusText)
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
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

    private var summaryText: String {
        guard let analysis else {
            return """
            Ich habe dieses Dokument noch nicht analysiert. \
            Starte die Analyse, damit ich Dokumentart, Absender, Datum und einen möglichen Zielordner erkennen kann.
            """
        }

        var sentences: [String] = []

        if analysis.documentType != .unknown {
            sentences.append(
                "Ich habe dieses Dokument als \(analysis.documentType.rawValue) erkannt."
            )
        } else {
            sentences.append(
                "Ich konnte die Dokumentart noch nicht sicher bestimmen."
            )
        }

        if let sender = analysis.sender {
            sentences.append(
                "Als Absender habe ich \(sender) erkannt."
            )
        }

        if let folderSuggestion {
            sentences.append(
                "Ich empfehle den Zielordner \(folderSuggestion.displayPath)."
            )
        } else {
            sentences.append(
                "Für den Zielordner habe ich noch keinen ausreichend guten Vorschlag."
            )
        }

        sentences.append(confidenceSentence)

        return sentences.joined(separator: " ")
    }

    private var confidenceSentence: String {
        let confidence = analysis?.confidence ?? 0

        switch confidence {
        case 0.90...:
            return "Die Erkennung ist sehr zuverlässig."

        case 0.75..<0.90:
            return "Die Erkennung ist wahrscheinlich richtig, sollte aber kurz geprüft werden."

        case 0.50..<0.75:
            return "Mehrere Merkmale passen, aber eine Prüfung ist empfehlenswert."

        default:
            return "Ich bin noch unsicher und benötige deine Unterstützung."
        }
    }

    private var statusText: String {
        let confidence = analysis?.confidence ?? 0

        switch confidence {
        case 0.90...:
            return "Sehr sicher"

        case 0.75..<0.90:
            return "Wahrscheinlich richtig"

        case 0.50..<0.75:
            return "Prüfen empfohlen"

        default:
            return "Unsicher"
        }
    }

    private var statusColor: Color {
        let confidence = analysis?.confidence ?? 0

        switch confidence {
        case 0.75...:
            return .green

        case 0.50..<0.75:
            return .orange

        default:
            return .red
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AtlasSummaryCard(
            analysis: AtlasAnalysis(
                documentType: .invoice,
                detectedDate: Date(),
                sender: "RAISA",
                keywords: [
                    "Rechnung",
                    "Futtermittel"
                ],
                confidence: 0.91,
                reasons: [
                    "Dokumentart Rechnung erkannt",
                    "Absender RAISA erkannt"
                ]
            ),
            folderSuggestion: FolderSuggestion(
                ruleName: "EHA Lieferscheine",
                area: .ehaKG,
                folder: "Lieferscheine",
                confidence: 0.85,
                reasons: [
                    "Absender RAISA passt"
                ]
            )
        )

        AtlasSummaryCard(
            analysis: nil,
            folderSuggestion: nil
        )
    }
    .padding()
    .frame(width: 430)
}
