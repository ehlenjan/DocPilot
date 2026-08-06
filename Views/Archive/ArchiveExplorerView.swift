import SwiftUI

struct ArchiveExplorerView: View {

    @State private var viewModel = ArchiveViewModel()

    var body: some View {

        NavigationStack {

            Group {

                if let errorMessage = viewModel.errorMessage {

                    ContentUnavailableView(
                        "Archiv",
                        systemImage: "externaldrive",
                        description: Text(errorMessage)
                    )

                } else if let root = viewModel.rootNode {

                    List {
                        ArchiveNodeRow(node: root)
                    }

                } else {

                    ProgressView()
                }
            }
            .navigationTitle("Archiv")
            .toolbar {

                Button {

                    viewModel.reload()

                } label: {

                    Label(
                        "Neu laden",
                        systemImage: "arrow.clockwise"
                    )
                }
            }
        }
        .onAppear {

            viewModel.reload()

        }
    }
}

private struct ArchiveNodeRow: View {

    let node: ArchiveNode

    var body: some View {

        DisclosureGroup {

            ForEach(node.children) { child in

                ArchiveNodeRow(
                    node: child
                )
            }

        } label: {

            Label(
                node.name,
                systemImage:
                    node.children.isEmpty
                    ? "folder"
                    : "folder.fill"
            )
        }
    }
}

#Preview {

    ArchiveExplorerView()
}
