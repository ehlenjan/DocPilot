import SwiftUI

struct LearningSettingsView: View {

    @Bindable var settingsManager: SettingsManager
    @State private var learningManager = LearningManager()

    var body: some View {
        Form {
            Section("Lernfunktion") {
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

                Text(
                    "Atlas kann bestätigte Zuordnungen speichern und später für bessere Vorschläge verwenden."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Gelernte Zuordnungen") {
                if learningManager.entries.isEmpty {
                    Text("Atlas hat bisher noch nichts gelernt.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(learningManager.entries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.company ?? "Unbekannter Absender")
                                    .font(.headline)

                                Text(
                                    "\(entry.archiveArea.rawValue) → \(entry.folder)"
                                )
                                .foregroundStyle(.secondary)

                                Text(entry.documentType.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                learningManager.remove(entry)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Zuordnung löschen")
                        }
                    }
                }
            }

            Section("Zurücksetzen") {
                Button(
                    "Alle gelernten Zuordnungen löschen",
                    role: .destructive
                ) {
                    learningManager.clear()
                }
                .disabled(learningManager.entries.isEmpty)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Lernen")
        .onAppear {
            learningManager.reload()
        }
    }
}

#Preview {
    NavigationStack {
        LearningSettingsView(
            settingsManager: SettingsManager()
        )
    }
}
