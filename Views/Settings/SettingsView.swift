import SwiftUI

struct SettingsView: View {

    @State private var settingsManager = SettingsManager()

    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink {
                    GeneralSettingsView(
                        settingsManager: settingsManager
                    )
                } label: {
                    Label(
                        "Allgemein",
                        systemImage: "gearshape"
                    )
                }

                NavigationLink {
                    AtlasSettingsView(
                        settingsManager: settingsManager
                    )
                } label: {
                    Label(
                        "Atlas",
                        systemImage: "brain.head.profile"
                    )
                }

                NavigationLink {
                    LearningSettingsView(
                        settingsManager: settingsManager
                    )
                } label: {
                    Label(
                        "Lernen",
                        systemImage: "brain"
                    )
                }

                NavigationLink {
                    Text("OCR")
                        .navigationTitle("OCR")
                } label: {
                    Label(
                        "OCR",
                        systemImage: "doc.text.viewfinder"
                    )
                }

                NavigationLink {
                    Text("Über")
                        .navigationTitle("Über")
                } label: {
                    Label(
                        "Über",
                        systemImage: "info.circle"
                    )
                }
            }
            .navigationTitle("Einstellungen")
        } detail: {
            GeneralSettingsView(
                settingsManager: settingsManager
            )
        }
    }
}

#Preview {
    SettingsView()
}
