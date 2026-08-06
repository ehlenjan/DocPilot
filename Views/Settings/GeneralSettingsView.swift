import SwiftUI
import UniformTypeIdentifiers

struct GeneralSettingsView: View {

    @Bindable var settingsManager: SettingsManager

    @State private var archiveFolderStore = ArchiveFolderStore()
    @State private var isChoosingArchiveFolder = false

    var body: some View {
        Form {
            Section("Allgemein") {
                Toggle(
                    "Automatische Analyse",
                    isOn: Binding(
                        get: {
                            settingsManager.settings
                                .automaticAnalysisEnabled
                        },
                        set: { newValue in
                            settingsManager.update {
                                $0.automaticAnalysisEnabled = newValue
                            }
                        }
                    )
                )

                Toggle(
                    "Learning aktivieren",
                    isOn: Binding(
                        get: {
                            settingsManager.settings.learningEnabled
                        },
                        set: { newValue in
                            settingsManager.update {
                                $0.learningEnabled = newValue
                            }
                        }
                    )
                )
            }

            Section("Archivordner") {
                if let folderURL = archiveFolderStore.folderURL {
                    LabeledContent(
                        "Ausgewählter Ordner"
                    ) {
                        Text(folderURL.path)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }

                    HStack {
                        Button("Anderen Ordner wählen") {
                            isChoosingArchiveFolder = true
                        }

                        Spacer()

                        Button(
                            "Entfernen",
                            role: .destructive
                        ) {
                            archiveFolderStore.removeFolder()
                        }
                    }
                } else {
                    Text(
                        "Wähle den Ordner aus, in dem deine archivierten Dokumente abgelegt werden."
                    )
                    .foregroundStyle(.secondary)

                    Button("Archivordner auswählen") {
                        isChoosingArchiveFolder = true
                    }
                }

                if let errorMessage =
                    archiveFolderStore.errorMessage {

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Anzeige") {
                Toggle(
                    "Confidence anzeigen",
                    isOn: Binding(
                        get: {
                            settingsManager.settings.showConfidence
                        },
                        set: { newValue in
                            settingsManager.update {
                                $0.showConfidence = newValue
                            }
                        }
                    )
                )

                Toggle(
                    "Begründungen anzeigen",
                    isOn: Binding(
                        get: {
                            settingsManager.settings.showReasons
                        },
                        set: { newValue in
                            settingsManager.update {
                                $0.showReasons = newValue
                            }
                        }
                    )
                )
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Allgemein")
        .fileImporter(
            isPresented: $isChoosingArchiveFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleArchiveFolderSelection(result)
        }
    }

    private func handleArchiveFolderSelection(
        _ result: Result<[URL], Error>
    ) {
        switch result {
        case .success(let urls):
            guard let selectedFolder = urls.first else {
                return
            }

            archiveFolderStore.saveFolder(
                selectedFolder
            )

        case .failure(let error):
            print(
                "Archivordner konnte nicht ausgewählt werden: \(error.localizedDescription)"
            )
        }
    }
}

#Preview {
    NavigationStack {
        GeneralSettingsView(
            settingsManager: SettingsManager()
        )
    }
}
