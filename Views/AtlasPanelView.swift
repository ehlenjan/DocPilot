import SwiftUI

struct AtlasPanelView: View {

    let document: DocumentRecord
    @Binding var filenameDraft: String

    let extractedText: String
    let textExtractionMessage: String?

    let onAnalyzeDocument: () -> Void
    let onGenerateSuggestion: () -> Void
    let onRename: () -> Void

    var body: some View {
        Form {
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

                if !extractedText.isEmpty {
                    ScrollView {
                        Text(extractedText)
                            .font(.caption)
                            .textSelection(.enabled)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                    }
                    .frame(minHeight: 120, maxHeight: 220)
                }
            }

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

            Section("Zielordner") {
                Label(
                    "Noch kein Vorschlag",
                    systemImage: "folder.badge.questionmark"
                )
                .foregroundStyle(.secondary)

                Button {
                    // Wird später ergänzt.
                } label: {
                    Label(
                        "Ordner auswählen",
                        systemImage: "folder"
                    )
                }
                .disabled(true)
            }

            Section("Dokumentart") {
                LabeledContent(
                    "Erkannt",
                    value: document.documentType.rawValue
                )

                LabeledContent(
                    "Sicherheit",
                    value: confidenceText
                )
            }

            Section("Warum?") {
                if document.reasons.isEmpty {
                    Text(
                        "Atlas hat dieses Dokument noch nicht klassifiziert."
                    )
                    .foregroundStyle(.secondary)
                } else {
                    ForEach(document.reasons, id: \.self) { reason in
                        Label(
                            reason,
                            systemImage: "checkmark.circle"
                        )
                    }
                }
            }

            Section("Aktuelle Datei") {
                Text(document.originalFilename)
                    .textSelection(.enabled)
            }

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
        .formStyle(.grouped)
        .frame(
            minWidth: 320,
            idealWidth: 370
        )
    }

    private var cleanFilename: String {
        filenameDraft.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var confidenceText: String {
        let percentage = Int(document.confidence * 100)
        return "\(percentage) %"
    }
}

#Preview {
    @Previewable @State var filename = "2026-08-02 Dokument"

    AtlasPanelView(
        document: DocumentRecord(
            sourceURL: URL(
                fileURLWithPath: "/tmp/scan001.pdf"
            )
        ),
        filenameDraft: $filename,
        extractedText: "Beispieltext aus dem PDF",
        textExtractionMessage: "26 Zeichen aus dem PDF gelesen.",
        onAnalyzeDocument: {},
        onGenerateSuggestion: {},
        onRename: {}
    )
    .frame(
        width: 390,
        height: 760
    )
}
