import SwiftUI

struct GeneralSettingsView: View {

    @Bindable var settingsManager: SettingsManager

    var body: some View {

        Form {

            Section("Allgemein") {

                Toggle(
                    "Automatische Analyse",
                    isOn: Binding(
                        get: {
                            settingsManager.settings.automaticAnalysisEnabled
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
    }
}

#Preview {

    NavigationStack {

        GeneralSettingsView(
            settingsManager: SettingsManager()
        )

    }

}
