import SwiftUI

struct AtlasPanelView: View {

    @State private var analysisExpanded = false
    @State private var learningExpanded = false
    @State private var fileExpanded = false

    let document: DocumentRecord

    @Binding var filenameDraft: String

    let extractedText: String
    let textExtractionMessage: String?

    let analysis: AtlasAnalysis?
    let folderSuggestion: FolderSuggestion?

    let manualArchiveDestinationURL: URL?

    let isAnalyzing: Bool
    let isArchiving: Bool

    let onAnalyzeDocument: () -> Void
    let onGenerateSuggestion: () -> Void
    let onRememberSuggestion: () -> Void
    let onHelpAtlas: () -> Void
    let onChangeArchiveDestination: () -> Void
    let onClearArchiveDestination: () -> Void
    let onRename: () -> Void
    let onArchive: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {

                AtlasRecommendationCard(
                    analysis: analysis,
                    folderSuggestion: folderSuggestion
                )

                archiveDestinationCard

                AtlasQuickFactsCard(
                    analysis: analysis
                )

                AtlasRenameCard(
                    filenameDraft: $filenameDraft,
                    isArchiving: isArchiving,
                    canArchive:
                        folderSuggestion != nil ||
                        manualArchiveDestinationURL != nil,
                    onGenerateSuggestion:
                        onGenerateSuggestion,
                    onRename:
                        onRename,
                    onArchive:
                        onArchive
                )

                ExpandableAtlasSection(
                    title:
                        "Analyse und Begründungen",
                    systemImage:
                        "text.viewfinder",
                    isExpanded:
                        $analysisExpanded
                ) {
                    analysisCard
                }

                ExpandableAtlasSection(
                    title:
                        "Atlas lernen lassen",
                    systemImage:
                        "brain",
                    isExpanded:
                        $learningExpanded
                ) {
                    AtlasLearningCard(
                        analysis: analysis,
                        folderSuggestion:
                            folderSuggestion,
                        onRemember:
                            onRememberSuggestion,
                        onHelpAtlas:
                            onHelpAtlas
                    )
                }

                ExpandableAtlasSection(
                    title:
                        "Aktuelle Datei",
                    systemImage:
                        "doc",
                    isExpanded:
                        $fileExpanded
                ) {
                    currentFileCard
                }
            }
            .padding(12)
        }
        .frame(
            minWidth: 320,
            idealWidth: 370
        )
        .background(
            Color(
                nsColor:
                    .controlBackgroundColor
            )
        )
    }

    // MARK: - Archive Destination

    private var archiveDestinationCard:
        some View {

        AtlasCard {

            VStack(
                alignment: .leading,
                spacing: 10
            ) {

                Label(
                    "Archivziel",
                    systemImage:
                        "folder.badge.arrow.forward"
                )
                .font(.headline)

                if let manualArchiveDestinationURL {

                    Text(
                        "Manuell gewählt"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text(
                        manualArchiveDestinationURL
                            .lastPathComponent
                    )
                    .font(.callout.bold())

                    Text(
                        manualArchiveDestinationURL.path
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)

                } else if let folderSuggestion {

                    Text(
                        "Atlas-Vorschlag"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text(
                        folderSuggestion.displayPath
                    )
                    .font(.callout.bold())

                } else {

                    Text(
                        "Noch kein Ziel vorhanden."
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }

                HStack {

                    Button {
                        onChangeArchiveDestination()
                    } label: {
                        Label(
                            "Ziel ändern …",
                            systemImage:
                                "folder"
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(isArchiving)

                    if manualArchiveDestinationURL != nil {

                        Button {
                            onClearArchiveDestination()
                        } label: {
                            Text(
                                "Atlas-Ziel verwenden"
                            )
                        }
                        .buttonStyle(.borderless)
                        .disabled(isArchiving)
                    }
                }
            }
        }
    }

    // MARK: - Analysis

    private var analysisCard: some View {
        AtlasCard {
            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                Label(
                    "Dokumentanalyse",
                    systemImage:
                        "text.viewfinder"
                )
                .font(.headline)

                Button(
                    action:
                        onAnalyzeDocument
                ) {
                    Label(
                        isAnalyzing
                            ? "Analyse läuft …"
                            : "Dokument analysieren",
                        systemImage:
                            "text.viewfinder"
                    )
                    .frame(
                        maxWidth: .infinity
                    )
                }
                .buttonStyle(.bordered)
                .disabled(
                    isAnalyzing ||
                    isArchiving
                )

                if let textExtractionMessage {

                    Text(
                        textExtractionMessage
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }

                if !extractedText.isEmpty {

                    Text("Erkannter Text")
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )

                    ScrollView {
                        Text(
                            extractedText
                        )
                        .font(.caption)
                        .textSelection(
                            .enabled
                        )
                        .frame(
                            maxWidth:
                                .infinity,
                            alignment:
                                .leading
                        )
                    }
                    .frame(
                        minHeight: 100,
                        maxHeight: 200
                    )
                }

                if let analysis,
                   !analysis.reasons.isEmpty {

                    Divider()

                    Text("Warum?")
                        .font(.headline)

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
                                systemImage:
                                    "checkmark.circle"
                            )
                            .font(.caption)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Current File

    private var currentFileCard: some View {
        AtlasCard {
            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                Label(
                    "Aktuelle Datei",
                    systemImage: "doc"
                )
                .font(.headline)

                Text(
                    document.originalFilename
                )
                .font(.callout)
                .textSelection(.enabled)
                .lineLimit(3)

                Text(
                    document.sourceURL.path
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
            }
        }
    }
}

private struct ExpandableAtlasSection<
    Content: View
>: View {

    let title: String
    let systemImage: String

    @Binding var isExpanded: Bool

    @ViewBuilder
    let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {

            Button {
                withAnimation(
                    .easeInOut(
                        duration: 0.2
                    )
                ) {
                    isExpanded.toggle()
                }
            } label: {

                HStack(spacing: 10) {

                    Image(
                        systemName:
                            isExpanded
                            ? "chevron.down"
                            : "chevron.right"
                    )
                    .font(.caption)
                    .frame(width: 12)

                    Label(
                        title,
                        systemImage:
                            systemImage
                    )
                    .font(.headline)

                    Spacer()
                }
                .contentShape(
                    Rectangle()
                )
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .padding(.top, 8)
                    .transition(
                        .opacity.combined(
                            with:
                                .move(
                                    edge: .top
                                )
                        )
                    )
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }
}

#Preview {

    @Previewable @State
    var filename =
        "2026-08-06 Rechnung RAISA"

    let previewAnalysis =
        AtlasAnalysis(
            documentType:
                .invoice,
            detectedDate:
                Date(),
            sender:
                "RAISA",
            keywords: [
                "Rechnung",
                "Futtermittel",
                "VzF"
            ],
            confidence:
                0.95,
            reasons: [
                "Dokumentart Rechnung erkannt",
                "Absender RAISA erkannt",
                "Datum erkannt",
                "3 relevante Schlüsselwörter gefunden"
            ]
        )

    let previewFolderSuggestion =
        FolderSuggestion(
            ruleName:
                "Gelernte Zuordnung",
            area:
                .ehaKG,
            folder:
                "Lieferscheine",
            confidence:
                0.95,
            reasons: [
                "Atlas hat ähnliche Dokumente gefunden",
                "Firma stimmt überein"
            ]
        )

    AtlasPanelView(
        document:
            DocumentRecord(
                sourceURL:
                    URL(
                        fileURLWithPath:
                            "/tmp/scan001.pdf"
                    )
            ),
        filenameDraft:
            $filename,
        extractedText:
            "Beispieltext aus dem PDF",
        textExtractionMessage:
            "28 Zeichen aus dem PDF gelesen.",
        analysis:
            previewAnalysis,
        folderSuggestion:
            previewFolderSuggestion,
        manualArchiveDestinationURL:
            nil,
        isAnalyzing:
            false,
        isArchiving:
            false,
        onAnalyzeDocument: {},
        onGenerateSuggestion: {},
        onRememberSuggestion: {},
        onHelpAtlas: {},
        onChangeArchiveDestination: {},
        onClearArchiveDestination: {},
        onRename: {},
        onArchive: {}
    )
    .frame(
        width: 420,
        height: 900
    )
}
