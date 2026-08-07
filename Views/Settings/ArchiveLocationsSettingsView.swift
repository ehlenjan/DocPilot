import SwiftUI
import UniformTypeIdentifiers

struct ArchiveLocationsSettingsView: View {

    @State private var store =
        ArchiveLocationsStore()

    @State private var selectedArea:
        ArchiveArea?

    @State private var isChoosingFolder =
        false

    var body: some View {

        Form {

            ForEach(
                ArchiveArea.allCases,
                id: \.self
            ) { area in

                Section(area.rawValue) {

                    if let url =
                        store.folderURL(for: area) {

                        Text(url.path)
                            .font(.caption)
                            .textSelection(.enabled)

                    } else {

                        Text("Noch kein Ordner ausgewählt.")
                            .foregroundStyle(.secondary)

                    }

                    HStack {

                        Button("Ordner auswählen") {

                            selectedArea = area
                            isChoosingFolder = true

                        }

                        if store.folderURL(for: area) != nil {

                            Button(
                                "Entfernen",
                                role: .destructive
                            ) {

                                store.removeFolder(
                                    for: area
                                )

                            }

                        }

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

            guard
                let area = selectedArea
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
                    for: area
                )

            case .failure:

                break

            }

        }

    }

}

#Preview {

    NavigationStack {

        ArchiveLocationsSettingsView()

    }

}
