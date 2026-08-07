import SwiftUI
import UniformTypeIdentifiers

struct ArchiveLocationsSettingsView: View {

    @State private var store =
        ArchiveWorkspaceStore()

    @State private var selectedWorkspace:
        ArchiveWorkspace?

    @State private var isChoosingFolder =
        false

    var body: some View {
        Form {
            ForEach(
                store.workspaces
            ) { workspace in

                Section(workspace.name) {

                    if let url =
                        store.folderURL(
                            for: workspace
                        ) {

                        Text(url.path)
                            .font(.caption)
                            .textSelection(.enabled)

                    } else {

                        Text(
                            "Noch kein Ordner ausgewählt."
                        )
                        .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button("Ordner auswählen") {
                            selectedWorkspace =
                                workspace

                            isChoosingFolder = true
                        }

                        if store.folderURL(
                            for: workspace
                        ) != nil {

                            Button(
                                "Entfernen",
                                role: .destructive
                            ) {
                                store.removeFolder(
                                    for: workspace
                                )
                            }
                        }
                    }

                    if let errorMessage =
                        store.errorMessage(
                            for: workspace
                        ) {

                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle("Archivorte")
        .fileImporter(
            isPresented: $isChoosingFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in

            guard let workspace =
                selectedWorkspace
            else {
                return
            }

            switch result {

            case .success(let urls):
                guard let url = urls.first else {
                    return
                }

                store.saveFolder(
                    url,
                    for: workspace
                )

                selectedWorkspace = nil

            case .failure(let error):
                print(
                    "Archivort konnte nicht ausgewählt werden: \(error.localizedDescription)"
                )

                selectedWorkspace = nil
            }
        }
    }
}

#Preview {
    NavigationStack {
        ArchiveLocationsSettingsView()
    }
}
