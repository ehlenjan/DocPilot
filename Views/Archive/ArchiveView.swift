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
            .disabled(viewModel.isLoading)
        }
        .onAppear {
            reloadArchive()
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var archiveSidebar: some View {
        if let errorMessage = viewModel.errorMessage {
            ContentUnavailableView(
                "Archiv nicht verfügbar",
                systemImage: "archivebox",
                description: Text(errorMessage)
            )

        } else if viewModel.isLoading {
            ProgressView("Archiv wird geladen …")
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )

        } else if let rootNode = viewModel.rootNode {
            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    ForEach(rootNode.children) { node in
                        ArchiveLazyNodeRow(
                            node: node,
                            viewModel: viewModel,
                            selectedNode: $selectedNode,
                            level: 0
                        )
                    }
                }
                .padding(.vertical, 8)
            }

        } else {
            ContentUnavailableView(
                "Kein Archiv verfügbar",
                systemImage: "archivebox",
                description: Text(
                    "Wähle zuerst einen Archivordner in den Einstellungen aus."
                )
            )
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var archiveDetail: some View {
        if let node = currentSelectedNode {
            VStack(
                alignment: .leading,
                spacing: 16
            ) {
                Label(
                    node.name,
                    systemImage: "folder.fill"
                )
                .font(.largeTitle.bold())

                Text(node.url.path)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Divider()

                if viewModel.isLoadingChildren(
                    for: node
                ) {
                    HStack(spacing: 10) {
                        ProgressView()

                        Text(
                            "Unterordner werden geladen …"
                        )
                        .foregroundStyle(.secondary)
                    }

                } else if node.children.isEmpty {
                    ContentUnavailableView(
                        "Ordner ausgewählt",
                        systemImage: "doc",
                        description: Text(
                            "Dokumente in diesem Ordner zeigen wir im nächsten Schritt an."
                        )
                    )

                } else {
                    Label(
                        "\(node.children.count) Unterordner geladen",
                        systemImage: "folder.badge.checkmark"
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
                "Kein Ordner ausgewählt",
                systemImage: "folder",
                description: Text(
                    "Wähle links einen Ordner aus."
                )
            )
        }
    }

    // MARK: - Selection

    private var currentSelectedNode: ArchiveNode? {
        guard
            let selectedURL = selectedNode?.url,
            let rootNode = viewModel.rootNode
        else {
            return nil
        }

        return findNode(
            with: selectedURL,
            in: rootNode
        )
    }

    private func findNode(
        with url: URL,
        in node: ArchiveNode
    ) -> ArchiveNode? {
        if node.url == url {
            return node
        }

        for child in node.children {
            if let result = findNode(
                with: url,
                in: child
            ) {
                return result
            }
        }

        return nil
    }

    private func reloadArchive() {
        selectedNode = nil
        viewModel.reload()
    }
}

// MARK: - Lazy Folder Row

private struct ArchiveLazyNodeRow: View {

    let node: ArchiveNode
    let viewModel: ArchiveViewModel

    @Binding var selectedNode: ArchiveNode?

    let level: Int

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded
        ) {
            if viewModel.isLoadingChildren(
                for: node
            ) {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)

                    Text("Lade …")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 24)

            } else if node.children.isEmpty {
                Text("Keine Unterordner")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 24)

            } else {
                ForEach(node.children) { child in
                    ArchiveLazyNodeRow(
                        node: child,
                        viewModel: viewModel,
                        selectedNode: $selectedNode,
                        level: level + 1
                    )
                }
            }

        } label: {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")

                Text(node.name)
                    .lineLimit(1)

                Spacer()

                if viewModel.isLoadingChildren(
                    for: node
                ) {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedNode = node
            }
        }
        .padding(.leading, CGFloat(level) * 12)
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .onChange(of: isExpanded) { _, expanded in
            guard expanded else {
                return
            }

            selectedNode = node

            viewModel.loadChildren(
                for: node
            )
        }
    }
}

#Preview {
    ArchiveView()
        .frame(
            width: 1000,
            height: 700
        )
}
