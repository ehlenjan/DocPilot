import SwiftUI

struct AtlasLearningCard: View {

    let analysis: AtlasAnalysis?
    let folderSuggestion: FolderSuggestion?

    let onRemember: () -> Void
    let onHelpAtlas: () -> Void

    @State private var didRemember = false

    var body: some View {
        AtlasCard {
            VStack(alignment: .leading, spacing: 14) {

                Label(
                    "Atlas lernen lassen",
                    systemImage: "brain.fill"
                )
                .font(.headline)

                Text(explanationText)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if didRemember {
                    Label(
                        "Zuordnung wurde gespeichert",
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)
                    .transition(
                        .opacity.combined(
                            with: .move(edge: .bottom)
                        )
                    )
                }

                HStack(spacing: 12) {

                    Button {
                        onRemember()

                        withAnimation(.easeInOut(duration: 0.25)) {
                            didRemember = true
                        }

                    } label: {

                        Label(
                            didRemember
                            ? "Zuordnung gemerkt"
                            : "Zuordnung merken",
                            systemImage: didRemember
                            ? "checkmark.circle.fill"
                            : "brain"
                        )
                        .frame(maxWidth: .infinity)

                    }
                    .buttonStyle(.bordered)
                    .disabled(
                        analysis == nil ||
                        folderSuggestion == nil ||
                        didRemember
                    )

                    Button {
                        onHelpAtlas()

                    } label: {

                        Label(
                            "Atlas helfen",
                            systemImage: "pencil.and.list.clipboard"
                        )
                        .frame(maxWidth: .infinity)

                    }
                    .buttonStyle(.borderedProminent)

                }
            }
        }
    }

    private var explanationText: String {

        guard
            let analysis,
            let folderSuggestion
        else {

            return """
            Sobald eine Analyse und ein Zielordner vorliegen, kannst du Atlas diese Zuordnung dauerhaft merken oder fehlende Informationen ergänzen.
            """
        }

        let sender = analysis.sender ?? "dieser Dokumentart"

        return """
        Atlas merkt sich, dass Dokumente von \(sender) typischerweise nach \(folderSuggestion.displayPath) gehören.
        """
    }
}

#Preview {

    AtlasLearningCard(
        analysis: AtlasAnalysis(
            documentType: .invoice,
            detectedDate: Date(),
            sender: "RAISA",
            keywords: [
                "Rechnung",
                "Futtermittel"
            ],
            confidence: 0.91,
            reasons: []
        ),
        folderSuggestion: FolderSuggestion(
            ruleName: "EHA Lieferscheine",
            area: .ehaKG,
            folder: "Lieferscheine",
            confidence: 0.85,
            reasons: [
                "Absender RAISA passt"
            ]
        ),
        onRemember: {},
        onHelpAtlas: {}
    )
    .padding()
    .frame(width: 430)
}
