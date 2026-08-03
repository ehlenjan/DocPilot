import SwiftUI
import UniformTypeIdentifiers

struct InboxView: View {

    @State private var viewModel = InboxViewModel()
    @State private var isChoosingFolder = false
    @State private var selectedDocument: DocumentRecord?
    @State private var filenameDraft = ""

    var body: some View {
        Group {
            if let folderURL = viewModel.folderURL {
                inboxContent(folderURL: folderURL)
            } else {
                EmptyInboxView(
                    errorMessage: viewModel.errorMessage,
                    onChooseFolder: {
                        isChoosingFolder = true
                    }
                )
            }
        }
        .fileImporter(
            isPresented: $isChoosingFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
        }
        .onAppear {
            viewModel.loadDocuments()
        }
        .onChange(of: selectedDocument) { _, newDocument in
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

    private func inboxContent(
        folderURL: URL
    ) -> some View {
        VStack(spacing: 0) {
            InboxHeaderView(
                folderURL: folderURL,
                documentCount: viewModel.documents.count,
                onReload: {
                    reloadDocuments()
                },
                onChooseFolder: {
                    isChoosingFolder = true
                }
            )

            Divider()

            if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(
                    "Aktion fehlgeschlagen",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if viewModel.documents.isEmpty {
                EmptyDocumentListView()
            } else {
                documentBrowser
            }
        }
    }

    private var documentBrowser: some View {
        HSplitView {
            DocumentListView(
                documents: viewModel.documents,
                analysisForDocument: { document in
                    viewModel.analysis(for: document)
                },
                selection: $selectedDocument
            )

            documentPreview

            atlasPanel
        }
    }

    @ViewBuilder
    private var documentPreview: some View {
        if let document = selectedDocument {
            PDFPreviewView(
                url: document.sourceURL
            )
            .frame(minWidth: 420)
        } else {
            EmptySelectionView(
                title: "Kein Dokument ausgewählt",
                systemImage: "doc.text.magnifyingglass",
                description:
                    "Wähle links eine PDF-Datei aus, um sie anzuzeigen."
            )
            .frame(minWidth: 420)
        }
    }

    @ViewBuilder
    private var atlasPanel: some View {
        if let document = selectedDocument {
            AtlasPanelView(
                document: document,
                filenameDraft: $filenameDraft,
                extractedText: viewModel.extractedText,
                textExtractionMessage:
                    viewModel.textExtractionMessage,
                analysis: viewModel.analysis,
                folderSuggestion:
                    viewModel.folderSuggestion,
                isAnalyzing: viewModel.isAnalyzing,
                onAnalyzeDocument: {
                    viewModel.analyze(
                        document: document
                    )
                },
                onGenerateSuggestion: {
                    filenameDraft =
                        viewModel.suggestFilename(
                            for: document
                        )
                },
                onRememberSuggestion: {
                    viewModel.rememberCurrentSuggestion()
                },
                onRename: {
                    renameSelectedDocument()
                }
            )
            .frame(
                minWidth: 360,
                idealWidth: 430
            )
        } else {
            EmptySelectionView(
                title: "Atlas wartet",
                systemImage: "brain.head.profile",
                description:
                    "Wähle ein Dokument aus, damit Atlas es analysieren kann."
            )
            .frame(
                minWidth: 360,
                idealWidth: 430
            )
        }
    }

    private func handleFolderSelection(
        _ result: Result<[URL], Error>
    ) {
        switch result {
        case .success(let urls):
            guard let selectedFolder = urls.first else {
                return
            }

            selectedDocument = nil
            filenameDraft = ""

            viewModel.clearAnalysis()
            viewModel.selectFolder(selectedFolder)

        case .failure(let error):
            viewModel.errorMessage =
                "Ordner konnte nicht ausgewählt werden: \(error.localizedDescription)"
        }
    }

    private func reloadDocuments() {
        let previousURL =
            selectedDocument?.sourceURL

        viewModel.loadDocuments()

        if let previousURL,
           let refreshedDocument =
            viewModel.documents.first(
                where: {
                    $0.sourceURL == previousURL
                }
            ) {

            selectedDocument = refreshedDocument

            viewModel.selectAnalysis(
                for: refreshedDocument
            )
        } else {
            selectedDocument = nil
            filenameDraft = ""

            viewModel.clearAnalysis()
        }
    }

    private func renameSelectedDocument() {
        guard let document = selectedDocument else {
            return
        }

        guard let renamedDocument =
            viewModel.rename(
                document: document,
                to: filenameDraft
            )
        else {
            return
        }

        selectedDocument = renamedDocument

        filenameDraft =
            renamedDocument.sourceURL
                .deletingPathExtension()
                .lastPathComponent

        viewModel.selectAnalysis(
            for: renamedDocument
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
