import SwiftUI

struct ArchiveView: View {

    @State private var viewModel = ArchiveViewModel()
    @State private var selectedNode: ArchiveNode?

    var body: some View {
        NavigationSplitView {
            archiveSidebar
                .navigationSplitViewColumnWidth(
                    min: 220,
                    ideal: 280
                )
        } detail: {
            archiveDetail
        }
        .navigationTitle("Archiv")
        .toolbar {
            Button {
                reloadArchive()
            } label: {
                Label(
                    "Neu laden",
                    systemImage: "arrow.clockwise"
                )
            }
        }
        .onAppear {
            reloadArchive()
        }
    }

    @ViewBuilder
    private var archiveSidebar: some View {
        if let errorMessage = viewModel.errorMessage {
            ContentUnavailableView(
                "Archiv nicht verfügbar",
                systemImage: "archivebox",
                description: Text(errorMessage)
            )
        } else if let rootNode = viewModel.rootNode {
            List(selection: $selectedNode) {
                OutlineGroup(
                    rootNode.children,
                    children: \.optionalChildren
                ) { node in
                    Label(
                        node.name,
                        systemImage: node.isLeaf
                            ? "folder"
                            : "folder.fill"
                    )
                    .tag(node)
                }
            }
            .listStyle(.sidebar)
        } else {
            ProgressView("Archiv wird geladen …")
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
        }
    }

    @ViewBuilder
    private var archiveDetail: some View {
        if let selectedNode {
            VStack(alignment: .leading, spacing: 16) {
                Label(
                    selectedNode.name,
                    systemImage: "folder.fill"
                )
                .font(.largeTitle.bold())

                Text(selectedNode.url.path)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Divider()

                if selectedNode.children.isEmpty {
                    ContentUnavailableView(
                        "Ordner ausgewählt",
                        systemImage: "doc",
                        description: Text(
                            "Die Dokumente in diesem Ordner zeigen wir im nächsten Schritt an."
                        )
                    )
                } else {
                    Text(
                        "\(selectedNode.children.count) Unterordner"
                    )
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(24)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
        } else {
            ContentUnavailableView(
                "Kein Archivordner ausgewählt",
                systemImage: "folder",
                description: Text(
                    "Wähle links einen Ordner aus."
                )
            )
        }
    }

    private func reloadArchive() {
        selectedNode = nil
        viewModel.reload()
    }
}

private extension ArchiveNode {

    var optionalChildren: [ArchiveNode]? {
        children.isEmpty ? nil : children
    }
}

#Preview {
    ArchiveView()
        .frame(
            width: 1000,
            height: 700
        )
}
