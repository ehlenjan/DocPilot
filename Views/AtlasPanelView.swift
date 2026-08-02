import SwiftUI

struct AtlasPanelView: View {

    let document: DocumentRecord

    @Binding var filenameDraft: String

    let extractedText: String
    let textExtractionMessage: String?

    let analysis: AtlasAnalysis?
    let folderSuggestion: FolderSuggestion?

    let onAnalyzeDocument: () -> Void
    let onGenerateSuggestion: () -> Void
    let onRename: () -> Void

    var body: some View {
        Form {
            atlasHeader
            analysisSection
            filenameSection
            folderSection
            reasonsSection
            currentFileSection
            actionSection
        }
        .formStyle(.grouped)
        .frame(
            minWidth: 320,
            idealWidth: 370
        )
    }

    private var atlasHeader: some View {
        Section {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Atlas")
                        .font(.headline)

                    Text("Dokumentenassistent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var analysisSection: some View {
        Section("Analyse") {
            Button(action: onAnalyzeDocument) {
                Label(
                    "Dokument analysieren",
                    systemImage: "text.viewfinder"
                )
            }

            if let textExtractionMessage {
                Text(textExtractionMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let analysis {
                LabeledContent(
                    "Dokumentart",
                    value: analysis.documentType.rawValue
                )

                LabeledContent(
                    "Absender",
                    value: analysis.sender ?? "Nicht erkannt"
                )

                LabeledContent(
                    "Datum",
                    value: formattedDate(analysis.detectedDate)
                )

                LabeledContent(
                    "Sicherheit",
                    value: confidenceText(analysis.confidence)
                )

                if !analysis.keywords.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Schlüsselwörter")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(
                            analysis.keywords.joined(
                                separator: ", "
                            )
                        )
                        .textSelection(.enabled)
                    }
                }
            } else {
                Text("Das Dokument wurde noch nicht analysiert.")
                    .foregroundStyle(.secondary)
            }

            if !extractedText.isEmpty {
                DisclosureGroup("Erkannten Text anzeigen") {
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
                }
            }
        }
    }

    private var filenameSection: some View {
        Section("Dateiname") {
            TextField(
                "Neuer Dateiname",
                text: $filenameDraft
            )

            Text(".pdf")
                .foregroundStyle(.secondary)

            Button(action: onGenerateSuggestion) {
                Label(
                    "Vorschlag erzeugen",
                    systemImage: "sparkles"
                )
            }
        }
    }

    private var folderSection: some View {
        Section("Zielordner") {
            if let folderSuggestion {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "folder.fill")

                        Text(folderSuggestion.displayPath)
                            .font(.headline)

                        Spacer()

                        Text(
                            "\(Int(folderSuggestion.confidence * 100)) %"
                        )
                        .foregroundStyle(.secondary)
                    }

                    ForEach(
                        folderSuggestion.reasons,
                        id: \.self
                    ) { reason in
                        Label(
                            reason,
                            systemImage: "checkmark.circle.fill"
                        )
                        .font(.caption)
                    }
                }
            } else {
                Label(
                    "Noch kein Vorschlag",
                    systemImage: "folder.badge.questionmark"
                )
                .foregroundStyle(.secondary)
            }
        }
    }

    private var reasonsSection: some View {
        Section("Warum?") {
            if let analysis,
               !analysis.reasons.isEmpty {

                ForEach(
                    analysis.reasons,
                    id: \.self
                ) { reason in
                    Label(
                        reason,
                        systemImage: "checkmark.circle"
                    )
                }
            } else {
                Text("Noch keine Begründungen vorhanden.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var currentFileSection: some View {
        Section("Aktuelle Datei") {
            Text(document.originalFilename)
                .textSelection(.enabled)
        }
    }

    private var actionSection: some View {
        Section {
            Button(action: onRename) {
                Label(
                    "Datei umbenennen",
                    systemImage: "checkmark.circle.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(
                .return,
                modifiers: [.command]
            )
            .disabled(cleanFilename.isEmpty)
        }
    }

    private var cleanFilename: String {
        filenameDraft.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
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

    private func confidenceText(
        _ confidence: Double
    ) -> String {
        "\(Int(confidence * 100)) %"
    }
}

#Preview {
    @Previewable @State var filename =
        "2026-08-02 Rechnung RAISA"

    let previewAnalysis = AtlasAnalysis(
        documentType: .invoice,
        detectedDate: Date(),
        sender: "RAISA",
        keywords: [
            "Rechnung",
            "Futtermittel"
        ],
        confidence: 0.85,
        reasons: [
            "Dokumentart Rechnung erkannt",
            "Absender RAISA erkannt",
            "Datum erkannt"
        ]
    )

    let previewFolderSuggestion = FolderSuggestion(
        ruleName: "EHA Lieferscheine",
        area: .ehaKG,
        folder: "Lieferscheine",
        confidence: 0.87,
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
        textExtractionMessage:
            "28 Zeichen aus dem PDF gelesen.",
        analysis: previewAnalysis,
        folderSuggestion: previewFolderSuggestion,
        onAnalyzeDocument: {},
        onGenerateSuggestion: {},
        onRename: {}
    )
    .frame(
        width: 390,
        height: 800
    )
}
