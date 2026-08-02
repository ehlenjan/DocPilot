import SwiftUI
import UniformTypeIdentifiers

struct InboxView: View {

    @State private var viewModel = InboxViewModel()
    @State private var isChoosingFolder = false

    var body: some View {
        VStack(spacing: 20) {

            if let folderURL = viewModel.folderURL {
                Image(systemName: "folder.fill")
                    .font(.system(size: 48))

                Text("Eingangsordner")
                    .font(.title2)

                Text(folderURL.path)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)

                if viewModel.documents.isEmpty {
                    Text("Keine PDF-Dateien gefunden")
                        .foregroundStyle(.secondary)
                } else {
                    List(viewModel.documents) { document in
                        Label(
                            document.originalFilename,
                            systemImage: "doc.richtext"
                        )
                    }
                    .frame(minHeight: 220)
                }

                HStack {
                    Button("Anderen Ordner auswählen") {
                        isChoosingFolder = true
                    }

                    Button("Neu laden") {
                        viewModel.loadDocuments()
                    }
                }
            } else {
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
            }
        }
        .padding(40)
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

                viewModel.selectFolder(selectedFolder)

            case .failure(let error):
                print(
                    "Ordner konnte nicht ausgewählt werden: \(error.localizedDescription)"
                )
            }
        }
        .onAppear {
            viewModel.loadDocuments()
        }
    }
}

#Preview {
    InboxView()
        .frame(width: 800, height: 500)
}
