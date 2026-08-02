import SwiftUI

struct ContentView: View {

    enum Section: String, CaseIterable, Identifiable {
        case inbox = "Posteingang"
        case search = "Suche"
        case knowledge = "Wissen"
        case settings = "Einstellungen"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .inbox:
                return "tray.full"

            case .search:
                return "magnifyingglass"

            case .knowledge:
                return "brain"

            case .settings:
                return "gear"
            }
        }
    }

    @State private var selection: Section? = .inbox

    var body: some View {

        NavigationSplitView {

            List(Section.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .navigationTitle("DocPilot")

        } detail: {

            switch selection {

            case .inbox:
                InboxView()

            case .search:
                ContentUnavailableView(
                    "Suche",
                    systemImage: "magnifyingglass",
                    description: Text("Hier wird später die intelligente Dokumentensuche angezeigt.")
                )

            case .knowledge:
                ContentUnavailableView(
                    "Wissen",
                    systemImage: "brain",
                    description: Text("Hier entsteht später das Atlas-Wissensnetz.")
                )

            case .settings:
                ContentUnavailableView(
                    "Einstellungen",
                    systemImage: "gear",
                    description: Text("Hier werden später NAS, Scanner und weitere Optionen eingerichtet.")
                )

            case .none:
                ContentUnavailableView(
                    "Bereich auswählen",
                    systemImage: "sidebar.left"
                )
            }

        }
        .frame(minWidth: 1000, minHeight: 650)

    }
}

#Preview {
    ContentView()
}
