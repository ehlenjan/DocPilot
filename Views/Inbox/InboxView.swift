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

    @State private var isShowingAtlasHelp =
        false

    @State private var isShowingArchiveDestinationPicker =
        false

    var body: some View {

        Group {

            if let folderURL =
                viewModel.folderURL {

                inboxContent(
                    folderURL: folderURL
                )

            } else {

                EmptyInboxView(
                    errorMessage:
                        viewModel.errorMessage,
                    onChooseFolder: {
                        isChoosingFolder = true
                    }
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
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

        // MARK: Atlas Learning Sheet

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
                            keywords:
                                keywords,
                            confidence:
                                1.0,
                            reasons: [
                                "Informationen wurden vom Benutzer ergänzt"
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

        // MARK: Archive Destination Picker

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
                    archiveViewModel.errorMessage,
                onCancel: {
                    isShowingArchiveDestinationPicker =
                        false
                },
                onSelect: { destinationURL in

                    viewModel
                        .setManualArchiveDestination(
                            destinationURL
                        )

                    isShowingArchiveDestinationPicker =
                        false
                }
            )
        }

        .onAppear {

            viewModel.loadDocuments()
        }

        .onChange(
            of: selectedDocument
        ) { _, newDocument in

            filenameDraft =
                newDocument?
                    .sourceURL
                    .deletingPathExtension()
                    .lastPathComponent ?? ""

            viewModel.selectAnalysis(
                for: newDocument
            )
        }
    }

    // MARK: - Content

    private func inboxContent(
        folderURL: URL
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
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )

            } else if
                viewModel.documents.isEmpty {

                EmptyDocumentListView()
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )

            } else {

                documentBrowser
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
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
                        for: document
                    )
                },
                selection:
                    $selectedDocument
            )
            .frame(
                minWidth: 260,
                idealWidth: 320
            )
            .frame(
                maxHeight: .infinity,
                alignment: .top
            )

            // PDF-Vorschau

            documentPreview
                .frame(
                    minWidth: 420,
                    maxHeight: .infinity,
                    alignment: .top
                )

            // Atlas

            atlasPanel
                .frame(
                    minWidth: 360,
                    idealWidth: 430,
                    maxWidth: 520
                )
                .frame(
                    maxHeight: .infinity,
                    alignment: .top
                )
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
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
                minWidth: 420,
                maxWidth: .infinity,
                maxHeight: .infinity
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
                minWidth: 420,
                maxWidth: .infinity,
                maxHeight: .infinity
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
                    viewModel.extractedText,
                textExtractionMessage:
                    viewModel
                        .textExtractionMessage,
                analysis:
                    viewModel.analysis,
                folderSuggestion:
                    viewModel.folderSuggestion,

                manualArchiveDestinationURL:
                    viewModel
                        .manualArchiveDestinationURL,

                isAnalyzing:
                    viewModel.isAnalyzing,
                isArchiving:
                    viewModel.isArchiving,

                onAnalyzeDocument: {

                    viewModel.analyze(
                        document:
                            document
                    )
                },

                onGenerateSuggestion: {

                    filenameDraft =
                        viewModel
                            .suggestFilename(
                                for:
                                    document
                            )
                },

                onRememberSuggestion: {

                    viewModel
                        .rememberCurrentSuggestion()
                },

                onHelpAtlas: {

                    isShowingAtlasHelp =
                        true
                },

                onChangeArchiveDestination: {

                    isShowingArchiveDestinationPicker =
                        true
                },

                onClearArchiveDestination: {

                    viewModel
                        .clearManualArchiveDestination()
                },

                onRename: {

                    renameSelectedDocument()
                },

                onArchive: {

                    Task {

                        let success =
                            await viewModel
                                .archive(
                                    document:
                                        document
                                )

                        if success {

                            selectedDocument =
                                nil

                            filenameDraft =
                                ""
                        }
                    }
                }
            )
            .frame(
                minWidth: 360,
                idealWidth: 430,
                maxWidth: 520,
                maxHeight: .infinity,
                alignment: .top
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
                minWidth: 360,
                idealWidth: 430,
                maxWidth: 520,
                maxHeight: .infinity
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

        } else {

            selectedDocument =
                nil

            filenameDraft =
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
            width: 1400,
            height: 800
        )
}
