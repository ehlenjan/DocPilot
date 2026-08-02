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
            switch result {
            case .success(let urls):
                guard let selectedFolder = urls.first else {
                    return
                }

                selectedDocument = nil
                filenameDraft = ""
                viewModel.selectFolder(selectedFolder)

            case .failure(let error):
                viewModel.errorMessage =
                    "Ordner konnte nicht ausgewählt werden: \(error.localizedDescription)"
            }
        }
        .onAppear {
            viewModel.loadDocuments()
        }
        .onChange(of: selectedDocument) { _, newDocument in
            filenameDraft =
                newDocument?.sourceURL
                    .deletingPathExtension()
                    .lastPathComponent ?? ""
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
                viewModel.loadDocuments()

                if let selectedDocument,
                   let refreshedDocument = viewModel.documents.first(
                    where: { $0.sourceURL == selectedDocument.sourceURL }
                   ) {
                    self.selectedDocument = refreshedDocument
                } else {
                    self.selectedDocument = nil
                    filenameDraft = ""
                }
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
            List(viewModel.documents, selection: $selectedDocument) { document in
                Label(
                    document.originalFilename,
                    systemImage: "doc.richtext"
                )
                .tag(document)
            }
            .frame(minWidth: 260, idealWidth: 320)

            Group {
                if let selectedDocument {
                    documentDetail(for: selectedDocument)
                } else {
                    ContentUnavailableView(
                        "Kein Dokument ausgewählt",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(
                            "Wähle links eine PDF-Datei aus, um sie anzuzeigen."
                        )
                    )
                }
            }
            .frame(minWidth: 620)
        }
    }

    private func documentDetail(
        for document: DocumentRecord
    ) -> some View {
        HSplitView {
            PDFPreviewView(url: document.sourceURL)
                .frame(minWidth: 420)

            Form {
                Section("Dateiname") {
                    TextField(
                        "Neuer Dateiname",
                        text: $filenameDraft
                    )

                    Text(".pdf")
                        .foregroundStyle(.secondary)

                    Button {
                        filenameDraft = viewModel.suggestFilename(
                            for: document
                        )
                    } label: {
                        Label(
                            "Vorschlag erzeugen",
                            systemImage: "sparkles"
                        )
                    }
                }

                Section("Aktueller Name") {
                    Text(document.originalFilename)
                        .textSelection(.enabled)
                }

                Section("Status") {
                    Label(
                        "Bereit zum Umbenennen",
                        systemImage: "pencil"
                    )
                    .foregroundStyle(.secondary)
                }

                Section {
                    Button("Datei umbenennen") {
                        renameSelectedDocument()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(
                        filenameDraft
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                            .isEmpty
                    )
                }
            }
            .formStyle(.grouped)
            .frame(minWidth: 300, idealWidth: 350)
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
}

#Preview {
    InboxView()
        .frame(width: 1200, height: 760)
}
