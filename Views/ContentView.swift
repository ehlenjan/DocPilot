import SwiftUI

struct ContentView: View {

    enum AppSection: String, CaseIterable, Identifiable {
        case inbox = "Posteingang"
        case archive = "Archiv"
        case search = "Suche"
        case knowledge = "Wissen"
        case settings = "Einstellungen"

        var id: String {
            rawValue
        }

        var icon: String {
            switch self {
            case .inbox:
                return "tray.full"

            case .archive:
                return "archivebox"

            case .search:
                return "magnifyingglass"

            case .knowledge:
                return "brain"

            case .settings:
                return "gear"
            }
        }
    }

    @State private var selection: AppSection? = .inbox
    @State private var columnVisibility:
        NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(
            columnVisibility: $columnVisibility
        ) {
            List(
                AppSection.allCases,
                selection: $selection
            ) { section in
                Label(
                    section.rawValue,
                    systemImage: section.icon
                )
                .tag(section)
            }
            .listStyle(.sidebar)
            .navigationTitle("DocPilot")
            .navigationSplitViewColumnWidth(
                min: 190,
                ideal: 220,
                max: 280
            )
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .frame(
            minWidth: 1000,
            minHeight: 650
        )
        .onAppear {
            columnVisibility = .all

            if selection == nil {
                selection = .inbox
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .inbox:
            InboxView()

        case .archive:
            ArchiveView()

        case .search:
            ContentUnavailableView(
                "Suche",
                systemImage: "magnifyingglass",
                description: Text(
                    "Hier wird später die intelligente Dokumentensuche angezeigt."
                )
            )

        case .knowledge:
            ContentUnavailableView(
                "Wissen",
                systemImage: "brain",
                description: Text(
                    "Hier entsteht später das Atlas-Wissensnetz."
                )
            )

        case .settings:
            ContentUnavailableView(
                "Einstellungen",
                systemImage: "gear",
                description: Text(
                    "Die Einstellungen öffnest du über DocPilot → Settings…"
                )
            )

        case .none:
            ContentUnavailableView(
                "Bereich auswählen",
                systemImage: "sidebar.left",
                description: Text(
                    "Wähle links einen Bereich aus."
                )
            )
        }
    }
}

#Preview {
    ContentView()
        .frame(
            width: 1400,
            height: 800
        )
}
