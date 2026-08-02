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
                emptyState
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
            filenameDraft = newDocument?
                .sourceURL
                .deletingPathExtension()
                .lastPathComponent ?? ""

            viewModel.clearExtractedText()
        }
    }

    private func inboxContent(folderURL: URL) -> some View {
        VStack(spacing: 0) {
            header(folderURL: folderURL)

            Divider()

            if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(
                    "Aktion fehlgeschlagen",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if viewModel.documents.isEmpty {
                ContentUnavailableView(
                    "Keine PDF-Dateien gefunden",
                    systemImage: "doc",
                    description: Text(
                        "Lege PDF-Dateien in den ausgewählten Eingangsordner oder lade die Ansicht neu."
                    )
                )
            } else {
                documentBrowser
            }
        }
    }

    private func header(folderURL: URL) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Eingangsordner")
                    .font(.headline)

                Text(folderURL.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer()

            Text("\(viewModel.documents.count) PDF")
                .foregroundStyle(.secondary)

            Button {
                reloadDocuments()
            } label: {
                Label("Neu laden", systemImage: "arrow.clockwise")
            }

            Button("Anderen Ordner auswählen") {
                isChoosingFolder = true
            }
        }
        .padding()
    }

    private var documentBrowser: some View {
        HSplitView {
            documentList
            documentPreview
            atlasPanel
        }
    }

    private var documentList: some View {
        List(
            viewModel.documents,
            selection: $selectedDocument
        ) { document in
            Label(
                document.originalFilename,
                systemImage: "doc.richtext"
            )
            .tag(document)
        }
        .frame(minWidth: 240, idealWidth: 300)
    }

    @ViewBuilder
    private var documentPreview: some View {
        if let selectedDocument {
            PDFPreviewView(url: selectedDocument.sourceURL)
                .frame(minWidth: 420)
        } else {
            ContentUnavailableView(
                "Kein Dokument ausgewählt",
                systemImage: "doc.text.magnifyingglass",
                description: Text(
                    "Wähle links eine PDF-Datei aus, um sie anzuzeigen."
                )
            )
            .frame(minWidth: 420)
        }
    }

    @ViewBuilder
    private var atlasPanel: some View {
        if let selectedDocument {
            AtlasPanelView(
                document: selectedDocument,
                filenameDraft: $filenameDraft,
                extractedText: viewModel.extractedText,
                textExtractionMessage: viewModel.textExtractionMessage,
                onAnalyzeDocument: {
                    viewModel.extractText(from: selectedDocument)
                },
                onGenerateSuggestion: {
                    filenameDraft = viewModel.suggestFilename(
                        for: selectedDocument
                    )
                },
                onRename: {
                    renameSelectedDocument()
                }
            )
            .frame(minWidth: 320, idealWidth: 370)
        } else {
            ContentUnavailableView(
                "Atlas wartet",
                systemImage: "brain.head.profile",
                description: Text(
                    "Wähle ein Dokument aus, damit Atlas es analysieren kann."
                )
            )
            .frame(minWidth: 320, idealWidth: 370)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ContentUnavailableView(
                "Noch kein Eingangsordner",
                systemImage: "tray",
                description: Text(
                    "Wähle den Ordner aus, in dem Scanner, Mail und andere Quellen neue Dokumente ablegen."
                )
            )

            Button("Eingangsordner auswählen") {
                isChoosingFolder = true
            }
            .buttonStyle(.borderedProminent)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
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
            viewModel.clearExtractedText()
            viewModel.selectFolder(selectedFolder)

        case .failure(let error):
            viewModel.errorMessage =
                "Ordner konnte nicht ausgewählt werden: \(error.localizedDescription)"
        }
    }

    private func reloadDocuments() {
        let previousURL = selectedDocument?.sourceURL

        viewModel.loadDocuments()
        viewModel.clearExtractedText()

        if let previousURL,
           let refreshedDocument = viewModel.documents.first(
               where: { $0.sourceURL == previousURL }
           ) {
            selectedDocument = refreshedDocument
        } else {
            selectedDocument = nil
            filenameDraft = ""
        }
    }

    private func renameSelectedDocument() {
        guard let selectedDocument else {
            return
        }

        guard let renamedDocument = viewModel.rename(
            document: selectedDocument,
            to: filenameDraft
        ) else {
            return
        }

        self.selectedDocument = renamedDocument
        filenameDraft = renamedDocument.sourceURL
            .deletingPathExtension()
            .lastPathComponent

        viewModel.clearExtractedText()
    }
}

#Preview {
    InboxView()
        .frame(width: 1300, height: 760)
}
