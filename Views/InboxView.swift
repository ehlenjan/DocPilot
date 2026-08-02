import SwiftUI
import UniformTypeIdentifiers

struct InboxView: View {

    @State private var folderStore = InboxFolderStore()
    @State private var isChoosingFolder = false

    var body: some View {
        VStack(spacing: 20) {

            if let folderURL = folderStore.folderURL {
                Image(systemName: "folder.fill")
                    .font(.system(size: 48))

                Text("Eingangsordner")
                    .font(.title2)

                Text(folderURL.path)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)

                HStack {
                    Button("Anderen Ordner auswählen") {
                        isChoosingFolder = true
                    }

                    Button("Ordner entfernen", role: .destructive) {
                        folderStore.removeFolder()
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

            if let errorMessage = folderStore.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
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

                folderStore.saveFolder(selectedFolder)

            case .failure(let error):
                print(
                    "Ordner konnte nicht ausgewählt werden: \(error.localizedDescription)"
                )
            }
        }
    }
}

#Preview {
    InboxView()
        .frame(width: 800, height: 500)
}
