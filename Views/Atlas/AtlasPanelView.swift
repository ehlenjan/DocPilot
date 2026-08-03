import SwiftUI

struct AtlasPanelView: View {

    let document: DocumentRecord

    @Binding var filenameDraft: String

    let extractedText: String
    let textExtractionMessage: String?

    let analysis: AtlasAnalysis?
    let folderSuggestion: FolderSuggestion?
    let isAnalyzing: Bool

    let onAnalyzeDocument: () -> Void
    let onGenerateSuggestion: () -> Void
    let onRememberSuggestion: () -> Void
    let onRename: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AtlasStatusCard(
                    analysis: analysis,
                    isAnalyzing: isAnalyzing
                )

                AtlasSummaryCard(
                    analysis: analysis,
                    folderSuggestion: folderSuggestion
                )

                AtlasDashboardGrid(
                    analysis: analysis,
                    folderSuggestion: folderSuggestion
                )

                analysisCard

                AtlasLearningCard(
                    analysis: analysis,
                    folderSuggestion: folderSuggestion,
                    onRemember: onRememberSuggestion
                )

                AtlasRenameCard(
                    filenameDraft: $filenameDraft,
                    onGenerateSuggestion: onGenerateSuggestion,
                    onRename: onRename
                )

                currentFileCard
            }
            .padding(16)
        }
        .frame(
            minWidth: 360,
            idealWidth: 430
        )
        .background(
            Color(nsColor: .controlBackgroundColor)
        )
    }

    private var analysisCard: some View {
        AtlasCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(
                    "Analyse",
                    systemImage: "text.viewfinder"
                )
                .font(.headline)

                Button(
                    action: onAnalyzeDocument
                ) {
                    Label(
                        isAnalyzing
                            ? "Analyse läuft …"
                            : "Dokument analysieren",
                        systemImage: "text.viewfinder"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isAnalyzing)

                if let textExtractionMessage {
                    Text(textExtractionMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !extractedText.isEmpty {
                    DisclosureGroup(
                        "Erkannten Text anzeigen"
                    ) {
                        ScrollView {
                            Text(extractedText)
                                .font(.caption)
                                .textSelection(.enabled)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                        }
                        .frame(
                            minHeight: 120,
                            maxHeight: 220
                        )
                        .padding(.top, 8)
                    }
                }

                if let analysis,
                   !analysis.reasons.isEmpty {

                    Divider()

                    DisclosureGroup("Warum?") {
                        VStack(
                            alignment: .leading,
                            spacing: 8
                        ) {
                            ForEach(
                                analysis.reasons,
                                id: \.self
                            ) { reason in
                                Label(
                                    reason,
                                    systemImage: "checkmark.circle"
                                )
                                .font(.caption)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
    }

    private var currentFileCard: some View {
        AtlasCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(
                    "Aktuelle Datei",
                    systemImage: "doc"
                )
                .font(.headline)

                Text(document.originalFilename)
                    .font(.callout)
                    .textSelection(.enabled)
                    .lineLimit(3)
            }
        }
    }
}

#Preview {
    @Previewable @State var filename =
        "2026-08-03 Rechnung RAISA"

    let previewAnalysis = AtlasAnalysis(
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
            "Dokumentart Rechnung erkannt",
            "Absender RAISA erkannt",
            "Datum erkannt",
            "3 relevante Schlüsselwörter gefunden"
        ]
    )

    let previewFolderSuggestion = FolderSuggestion(
        ruleName: "EHA Lieferscheine",
        area: .ehaKG,
        folder: "Lieferscheine",
        confidence: 0.85,
        reasons: [
            "Dokumentart Lieferschein passt",
            "Absender RAISA passt",
            "Schlüsselwörter: Futtermittel, VzF"
        ]
    )

    AtlasPanelView(
        document: DocumentRecord(
            sourceURL: URL(
                fileURLWithPath: "/tmp/scan001.pdf"
            )
        ),
        filenameDraft: $filename,
        extractedText: "Beispieltext aus dem PDF",
        textExtractionMessage: "28 Zeichen aus dem PDF gelesen.",
        analysis: previewAnalysis,
        folderSuggestion: previewFolderSuggestion,
        isAnalyzing: false,
        onAnalyzeDocument: {},
        onGenerateSuggestion: {},
        onRememberSuggestion: {},
        onRename: {}
    )
    .frame(
        width: 460,
        height: 950
    )
}
