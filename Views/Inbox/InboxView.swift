import SwiftUI
import UniformTypeIdentifiers

struct InboxView: View {

    @State private var viewModel =
        InboxViewModel()

    @State private var archiveViewModel =
        ArchiveViewModel()

    @State private var isChoosingFolder =
        false

    @State private var selectedDocument:
        DocumentRecord?

    @State private var filenameDraft =
        ""

    // Merkt sich den letzten Namen,
    // den Atlas automatisch eingetragen hat.
    //
    // So kann Atlas seinen eigenen Vorschlag
    // später aktualisieren, ohne eine manuelle
    // Änderung des Benutzers zu überschreiben.
    @State private var lastAutomaticFilenameSuggestion =
        ""

    @State private var isShowingAtlasHelp =
        false

    @State private var isShowingArchiveDestinationPicker =
        false

    // MARK: - Body

    var body: some View {

        Group {

            if let folderURL =
                viewModel.folderURL {

                inboxContent(
                    folderURL:
                        folderURL
                )

            } else {

                EmptyInboxView(
                    errorMessage:
                        viewModel.errorMessage,
                    onChooseFolder: {

                        isChoosingFolder =
                            true
                    }
                )
            }
        }
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity,
            alignment:
                .topLeading
        )

        // MARK: - Inbox Folder Picker

        .fileImporter(
            isPresented:
                $isChoosingFolder,
            allowedContentTypes: [
                .folder
            ],
            allowsMultipleSelection:
                false
        ) { result in

            handleFolderSelection(
                result
            )
        }

        // MARK: - Atlas Learning Sheet

        .sheet(
            isPresented:
                $isShowingAtlasHelp
        ) {

            AtlasLearningSheet(
                currentAnalysis:
                    viewModel.analysis,
                currentFolderSuggestion:
                    viewModel.folderSuggestion,
                onCancel: {

                    isShowingAtlasHelp =
                        false
                },
                onSave: {
                    company,
                    documentType,
                    detectedDate,
                    keywords,
                    archiveArea,
                    folder in

                    let correctedAnalysis =
                        AtlasAnalysis(
                            documentType:
                                documentType,
                            detectedDate:
                                detectedDate,
                            sender:
                                company,
                            recipientArea:
                                archiveArea,
                            keywords:
                                keywords,
                            confidence:
                                1.0,
                            reasons: [
                                "Informationen wurden vom Benutzer ergänzt",
                                "Empfängerbereich wurde vom Benutzer bestätigt"
                            ]
                        )

                    let correctedDestination =
                        FolderSuggestion(
                            ruleName:
                                "Manuell gelernte Zuordnung",
                            area:
                                archiveArea,
                            folder:
                                folder,
                            confidence:
                                1.0,
                            reasons: [
                                "Zielordner wurde vom Benutzer bestätigt"
                            ]
                        )

                    LearningEngine()
                        .remember(
                            analysis:
                                correctedAnalysis,
                            destination:
                                correctedDestination
                        )

                    isShowingAtlasHelp =
                        false
                }
            )
        }

        // MARK: - Archive Destination Picker

        .sheet(
            isPresented:
                $isShowingArchiveDestinationPicker
        ) {

            ArchiveFolderPickerSheet(
                title:
                    "Archivziel auswählen",
                subtitle:
                    selectedDocument?
                        .originalFilename,
                actionTitle:
                    "Übernehmen",
                viewModel:
                    archiveViewModel,
                isWorking:
                    false,
                errorMessage:
                    archiveViewModel
                        .errorMessage,
                onCancel: {

                    isShowingArchiveDestinationPicker =
                        false
                },
                onSelect: {
                    destinationURL in

                    viewModel
                        .setManualArchiveDestination(
                            destinationURL
                        )

                    isShowingArchiveDestinationPicker =
                        false
                }
            )
        }

        // MARK: - Initial Load

        .onAppear {

            viewModel.loadDocuments()
        }

        // MARK: - Document Selection

        .onChange(
            of:
                selectedDocument
        ) { _, newDocument in

            // Bei einem neuen Dokument beginnen wir
            // wieder beim tatsächlichen Dateinamen.
            filenameDraft =
                newDocument?
                    .sourceURL
                    .deletingPathExtension()
                    .lastPathComponent
                ?? ""

            lastAutomaticFilenameSuggestion =
                ""

            viewModel.selectAnalysis(
                for:
                    newDocument
            )

            // Falls für dieses Dokument bereits
            // eine Analyse im Cache liegt, kann
            // Atlas den Namen sofort einsetzen.
            if let newDocument {

                applyAutomaticFilenameSuggestion(
                    for:
                        newDocument
                )
            }
        }

        // MARK: - Automatic Filename Suggestion

        .onChange(
            of:
                selectedAnalysisSignature
        ) { _, newSignature in

            guard
                !newSignature.isEmpty,
                let document =
                    selectedDocument
            else {
                return
            }

            applyAutomaticFilenameSuggestion(
                for:
                    document
            )
        }
    }

    // MARK: - Analysis Signature

    private var selectedAnalysisSignature:
        String {

        guard
            let document =
                selectedDocument,
            let analysis =
                viewModel.analysis(
                    for:
                        document
                )
        else {

            return ""
        }

        let dateValue =
            analysis.detectedDate?
                .timeIntervalSince1970
            ?? 0

        let senderValue =
            analysis.sender
            ?? ""

        let recipientValue =
            analysis.recipientArea?
                .rawValue
            ?? ""

        let keywordValue =
            analysis.keywords
                .joined(
                    separator:
                        "|"
                )

        return [
            document.sourceURL.path,
            analysis.documentType.rawValue,
            String(
                dateValue
            ),
            senderValue,
            recipientValue,
            keywordValue,
            String(
                analysis.confidence
            )
        ]
        .joined(
            separator:
                "§"
        )
    }

    // MARK: - Automatic Filename

    private func applyAutomaticFilenameSuggestion(
        for document:
            DocumentRecord
    ) {

        // Nur arbeiten, wenn für genau dieses
        // Dokument tatsächlich eine Analyse vorliegt.
        guard
            viewModel.analysis(
                for:
                    document
            ) != nil
        else {

            return
        }

        let currentFilename =
            document
                .sourceURL
                .deletingPathExtension()
                .lastPathComponent

        let cleanedDraft =
            filenameDraft
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let cleanedLastAutomaticSuggestion =
            lastAutomaticFilenameSuggestion
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        // Atlas darf den Namen automatisch setzen,
        // wenn:
        //
        // 1. das Feld leer ist,
        // 2. noch der echte Originalname drinsteht,
        // 3. oder der aktuelle Inhalt von Atlas
        //    selbst stammt.
        //
        // Sobald der Benutzer selbst etwas anderes
        // eingibt, wird nichts mehr überschrieben.
        let mayReplaceAutomatically =
            cleanedDraft.isEmpty
            ||
            cleanedDraft ==
                currentFilename
            ||
            (
                !cleanedLastAutomaticSuggestion
                    .isEmpty
                &&
                cleanedDraft ==
                    cleanedLastAutomaticSuggestion
            )

        guard mayReplaceAutomatically
        else {

            return
        }

        let suggestion =
            viewModel
                .suggestFilename(
                    for:
                        document
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            !suggestion.isEmpty
        else {

            return
        }

        filenameDraft =
            suggestion

        lastAutomaticFilenameSuggestion =
            suggestion
    }

    // MARK: - Content

    private func inboxContent(
        folderURL:
            URL
    ) -> some View {

        VStack(spacing: 0) {

            InboxHeaderView(
                folderURL:
                    folderURL,
                documentCount:
                    viewModel.documents.count,
                onReload: {

                    reloadDocuments()
                },
                onChooseFolder: {

                    isChoosingFolder =
                        true
                }
            )

            Divider()

            if let errorMessage =
                viewModel.errorMessage {

                ContentUnavailableView(
                    "Aktion fehlgeschlagen",
                    systemImage:
                        "exclamationmark.triangle",
                    description:
                        Text(
                            errorMessage
                        )
                )
                .frame(
                    maxWidth:
                        .infinity,
                    maxHeight:
                        .infinity
                )

            } else if
                viewModel.documents.isEmpty {

                EmptyDocumentListView()
                    .frame(
                        maxWidth:
                            .infinity,
                        maxHeight:
                            .infinity
                    )

            } else {

                documentBrowser
            }
        }
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity,
            alignment:
                .topLeading
        )
    }

    // MARK: - Document Browser

    private var documentBrowser:
        some View {

        HSplitView {

            // Dokumentliste

            DocumentListView(
                documents:
                    viewModel.documents,
                analysisForDocument: {
                    document in

                    viewModel.analysis(
                        for:
                            document
                    )
                },
                selection:
                    $selectedDocument
            )
            .frame(
                minWidth:
                    260,
                idealWidth:
                    320
            )
            .frame(
                maxHeight:
                    .infinity,
                alignment:
                    .top
            )

            // PDF-Vorschau

            documentPreview
                .frame(
                    minWidth:
                        420,
                    maxHeight:
                        .infinity,
                    alignment:
                        .top
                )

            // Atlas

            atlasPanel
                .frame(
                    minWidth:
                        360,
                    idealWidth:
                        430,
                    maxWidth:
                        520
                )
                .frame(
                    maxHeight:
                        .infinity,
                    alignment:
                        .top
                )
        }
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity,
            alignment:
                .topLeading
        )
    }

    // MARK: - PDF Preview

    @ViewBuilder
    private var documentPreview:
        some View {

        if let document =
            selectedDocument {

            PDFPreviewView(
                url:
                    document.sourceURL
            )
            .frame(
                minWidth:
                    420,
                maxWidth:
                    .infinity,
                maxHeight:
                    .infinity
            )

        } else {

            EmptySelectionView(
                title:
                    "Kein Dokument ausgewählt",
                systemImage:
                    "doc.text.magnifyingglass",
                description:
                    "Wähle links eine PDF-Datei aus, um sie anzuzeigen."
            )
            .frame(
                minWidth:
                    420,
                maxWidth:
                    .infinity,
                maxHeight:
                    .infinity
            )
        }
    }

    // MARK: - Atlas Panel

    @ViewBuilder
    private var atlasPanel:
        some View {

        if let document =
            selectedDocument {

            AtlasPanelView(
                document:
                    document,
                filenameDraft:
                    $filenameDraft,
                extractedText:
                    viewModel
                        .extractedText,
                textExtractionMessage:
                    viewModel
                        .textExtractionMessage,
                analysis:
                    viewModel
                        .analysis,
                folderSuggestion:
                    viewModel
                        .folderSuggestion,
                manualArchiveDestinationURL:
                    viewModel
                        .manualArchiveDestinationURL,

                // MARK: Visueller Absender

                visualSenderSuggestion:
                    viewModel
                        .visualSenderSuggestion,

                visualSenderConfirmationCount:
                    viewModel
                        .visualSenderConfirmationCount,

                visualSenderNeedsConfirmation:
                    viewModel
                        .visualSenderNeedsConfirmation,

                visualSenderSimilarity:
                    viewModel
                        .visualSenderSimilarity,

                availableVisualSenderCompanies:
                    viewModel
                        .availableVisualSenderCompanies,

                onConfirmVisualSender: {
                    company in

                    let confirmed =
                        viewModel
                            .confirmVisualSender(
                                company:
                                    company,
                                for:
                                    document
                            )

                    if confirmed {

                        applyAutomaticFilenameSuggestion(
                            for:
                                document
                        )
                    }
                },

                // MARK: Status

                isAnalyzing:
                    viewModel
                        .isAnalyzing,

                isArchiving:
                    viewModel
                        .isArchiving,

                // MARK: Analyse

                onAnalyzeDocument: {

                    viewModel.analyze(
                        document:
                            document
                    )
                },

                // MARK: Lernen

                onRememberSuggestion: {

                    viewModel
                        .rememberCurrentSuggestion()
                },

                onHelpAtlas: {

                    isShowingAtlasHelp =
                        true
                },

                // MARK: Archivziel

                onChangeArchiveDestination: {

                    isShowingArchiveDestinationPicker =
                        true
                },

                onClearArchiveDestination: {

                    viewModel
                        .clearManualArchiveDestination()
                },

                // MARK: Nur Umbenennen

                onRename: {

                    renameSelectedDocument()
                },

                // MARK: Umbenennen + Archivieren

                onArchive: {

                    Task {

                        var documentToArchive =
                            document

                        let currentFilename =
                            document
                                .sourceURL
                                .deletingPathExtension()
                                .lastPathComponent

                        let cleanedDraft =
                            filenameDraft
                                .trimmingCharacters(
                                    in:
                                        .whitespacesAndNewlines
                                )

                        // Der sichtbare Dateiname wird
                        // zuerst wirklich auf die Datei
                        // angewendet.
                        if !cleanedDraft.isEmpty &&
                            cleanedDraft !=
                                currentFilename {

                            guard let renamedDocument =
                                viewModel.rename(
                                    document:
                                        document,
                                    to:
                                        cleanedDraft
                                )
                            else {

                                return
                            }

                            documentToArchive =
                                renamedDocument
                        }

                        // Anschließend wird die
                        // umbenannte Datei archiviert.
                        let success =
                            await viewModel
                                .archive(
                                    document:
                                        documentToArchive
                                )

                        if success {

                            selectedDocument =
                                nil

                            filenameDraft =
                                ""

                            lastAutomaticFilenameSuggestion =
                                ""
                        }
                    }
                }
            )
            .frame(
                minWidth:
                    360,
                idealWidth:
                    430,
                maxWidth:
                    520,
                maxHeight:
                    .infinity,
                alignment:
                    .top
            )

        } else {

            EmptySelectionView(
                title:
                    "Atlas wartet",
                systemImage:
                    "brain.head.profile",
                description:
                    "Wähle ein Dokument aus, damit Atlas es analysieren kann."
            )
            .frame(
                minWidth:
                    360,
                idealWidth:
                    430,
                maxWidth:
                    520,
                maxHeight:
                    .infinity
            )
        }
    }

    // MARK: - Folder Selection

    private func handleFolderSelection(
        _ result:
            Result<[URL], Error>
    ) {

        switch result {

        case .success(let urls):

            guard let selectedFolder =
                urls.first
            else {

                return
            }

            selectedDocument =
                nil

            filenameDraft =
                ""

            lastAutomaticFilenameSuggestion =
                ""

            viewModel
                .clearAnalysis()

            viewModel
                .selectFolder(
                    selectedFolder
                )

        case .failure(let error):

            viewModel.errorMessage =
                "Ordner konnte nicht ausgewählt werden: \(error.localizedDescription)"
        }
    }

    // MARK: - Reload

    private func reloadDocuments() {

        let previousURL =
            selectedDocument?
                .sourceURL

        viewModel.loadDocuments()

        if let previousURL,
           let refreshedDocument =
            viewModel.documents.first(
                where: {

                    $0.sourceURL ==
                        previousURL
                }
            ) {

            selectedDocument =
                refreshedDocument

            viewModel
                .selectAnalysis(
                    for:
                        refreshedDocument
                )

            applyAutomaticFilenameSuggestion(
                for:
                    refreshedDocument
            )

        } else {

            selectedDocument =
                nil

            filenameDraft =
                ""

            lastAutomaticFilenameSuggestion =
                ""

            viewModel
                .clearAnalysis()
        }
    }

    // MARK: - Rename

    private func renameSelectedDocument() {

        guard let document =
            selectedDocument
        else {

            return
        }

        guard let renamedDocument =
            viewModel.rename(
                document:
                    document,
                to:
                    filenameDraft
            )
        else {

            return
        }

        selectedDocument =
            renamedDocument

        filenameDraft =
            renamedDocument
                .sourceURL
                .deletingPathExtension()
                .lastPathComponent

        lastAutomaticFilenameSuggestion =
            filenameDraft

        viewModel
            .selectAnalysis(
                for:
                    renamedDocument
            )
    }
}

#Preview {

    InboxView()
        .frame(
            width:
                1400,
            height:
                800
        )
}
