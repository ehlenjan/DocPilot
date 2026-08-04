import SwiftUI

struct AtlasSettingsView: View {

    @Bindable var settingsManager: SettingsManager

    var body: some View {
        Form {
            Section("Analyse") {
                Toggle(
                    "Automatische Analyse",
                    isOn: Binding(
                        get: {
                            settingsManager.settings
                                .automaticAnalysisEnabled
                        },
                        set: { newValue in
                            settingsManager.update {
                                $0.automaticAnalysisEnabled =
                                    newValue
                            }
                        }
                    )
                )

                Text(
                    "Neue Dokumente werden nach dem Laden automatisch analysiert."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Anzeige") {
                Toggle(
                    "Confidence anzeigen",
                    isOn: Binding(
                        get: {
                            settingsManager.settings
                                .showConfidence
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
                            settingsManager.settings
                                .showReasons
                        },
                        set: { newValue in
                            settingsManager.update {
                                $0.showReasons = newValue
                            }
                        }
                    )
                )
            }

            Section("Zurücksetzen") {
                Button(
                    "Atlas-Einstellungen zurücksetzen",
                    role: .destructive
                ) {
                    settingsManager.update {
                        $0.automaticAnalysisEnabled = true
                        $0.showConfidence = true
                        $0.showReasons = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Atlas")
    }
}

#Preview {
    NavigationStack {
        AtlasSettingsView(
            settingsManager: SettingsManager()
        )
    }
}
