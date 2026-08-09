import SwiftUI

struct ArchiveFolderPickerSheet: View {

    let title: String
    let subtitle: String?

    let actionTitle: String

    let viewModel: ArchiveViewModel

    let isWorking: Bool
    let errorMessage: String?

    let onCancel: () -> Void
    let onSelect: (URL) -> Void

    @State private var selectedFolderURL: URL?

    var body: some View {

        VStack(spacing: 0) {

            header

            Divider()

            folderSelection
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )

            Divider()

            footer
        }
        .frame(
            width: 700,
            height: 650
        )
        .onAppear {
            if viewModel.rootNodesByWorkspace.isEmpty {
                viewModel.reload()
            }
        }
    }

    // MARK: - Header

    private var header: some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            Text(title)
                .font(.title2.bold())

            if let subtitle {

                Text(subtitle)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if isWorking {

                HStack(spacing: 8) {

                    ProgressView()
                        .controlSize(.small)

                    Text("Bitte warten …")
                        .foregroundStyle(.secondary)
                }

            } else {

                Text(
                    "Wähle einen Ordner aus dem Archiv."
                )
                .foregroundStyle(.secondary)
            }

            if let errorMessage {

                Label(
                    errorMessage,
                    systemImage:
                        "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.red)
                .padding(.top, 4)
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(20)
    }

    // MARK: - Folder Selection

    @ViewBuilder
    private var folderSelection: some View {

        if viewModel.isLoading &&
            viewModel.rootNodesByWorkspace.isEmpty {

            ProgressView(
                "Archivorte werden geladen …"
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )

        } else {

            ScrollView {

                LazyVStack(
                    alignment: .leading,
                    spacing: 4
                ) {

                    ForEach(
                        viewModel.workspaces
                    ) { workspace in

                        ArchiveFolderPickerWorkspaceRow(
                            workspace:
                                workspace,
                            viewModel:
                                viewModel,
                            selectedFolderURL:
                                $selectedFolderURL
                        )
                    }
                }
                .padding(12)
            }
            .disabled(isWorking)
        }
    }

    // MARK: - Footer

    private var footer: some View {

        HStack(spacing: 12) {

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text("Ziel")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let selectedFolderURL {

                    Text(
                        selectedFolderURL.path
                    )
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)

                } else {

                    Text(
                        "Noch keinen Ordner ausgewählt"
                    )
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button("Abbrechen") {
                onCancel()
            }
            .keyboardShortcut(
                .cancelAction
            )
            .disabled(isWorking)

            Button {

                guard let selectedFolderURL else {
                    return
                }

                onSelect(
                    selectedFolderURL
                )

            } label: {

                if isWorking {

                    HStack(spacing: 6) {

                        ProgressView()
                            .controlSize(.small)

                        Text(actionTitle)
                    }

                } else {

                    Text(actionTitle)
                }
            }
            .keyboardShortcut(
                .defaultAction
            )
            .disabled(
                selectedFolderURL == nil ||
                isWorking
            )
        }
        .padding(16)
    }
}

// MARK: - Workspace Row

private struct ArchiveFolderPickerWorkspaceRow: View {

    let workspace:
        ArchiveWorkspace

    let viewModel:
        ArchiveViewModel

    @Binding var selectedFolderURL:
        URL?

    @State private var isExpanded =
        false

    var body: some View {

        if let rootNode =
            viewModel.rootNode(
                for: workspace
            ) {

            DisclosureGroup(
                isExpanded: $isExpanded
            ) {

                ArchiveFolderPickerRow(
                    node: rootNode,
                    viewModel: viewModel,
                    selectedFolderURL:
                        $selectedFolderURL,
                    level: 1
                )

            } label: {

                HStack(spacing: 8) {

                    Image(
                        systemName:
                            workspace.icon
                    )
                    .frame(width: 18)

                    Text(
                        workspace.name
                    )
                    .fontWeight(.semibold)

                    Spacer()
                }
                .contentShape(
                    Rectangle()
                )
                .onTapGesture {

                    selectedFolderURL =
                        rootNode.url
                }
            }
            .padding(.vertical, 4)

        } else {

            HStack(spacing: 8) {

                Image(
                    systemName:
                        workspace.icon
                )
                .frame(width: 18)

                Text(
                    workspace.name
                )
                .fontWeight(.semibold)

                Spacer()

                if viewModel.folderURL(
                    for: workspace
                ) == nil {

                    Text(
                        "Kein Archivort"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                } else {

                    Text(
                        "Nicht verfügbar"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Folder Row

private struct ArchiveFolderPickerRow: View {

    let node:
        ArchiveNode

    let viewModel:
        ArchiveViewModel

    @Binding var selectedFolderURL:
        URL?

    let level:
        Int

    @State private var isExpanded =
        false

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 2
        ) {

            DisclosureGroup(
                isExpanded: $isExpanded
            ) {

                if viewModel.isLoadingChildren(
                    for: node
                ) {

                    HStack(spacing: 8) {

                        ProgressView()
                            .controlSize(.small)

                        Text(
                            "Unterordner werden geladen …"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 8)

                } else if node.children.isEmpty {

                    Text(
                        "Keine Unterordner"
                    )
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 8)

                } else {

                    ForEach(
                        node.children
                    ) { child in

                        ArchiveFolderPickerRow(
                            node: child,
                            viewModel:
                                viewModel,
                            selectedFolderURL:
                                $selectedFolderURL,
                            level:
                                level + 1
                        )
                    }
                }

            } label: {

                HStack(spacing: 8) {

                    Image(
                        systemName:
                            selectedFolderURL ==
                            node.url
                            ? "folder.fill"
                            : "folder"
                    )

                    Text(node.name)
                        .lineLimit(1)

                    Spacer()

                    if viewModel
                        .isLoadingChildren(
                            for: node
                        ) {

                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .contentShape(
                    Rectangle()
                )
                .padding(.vertical, 3)
                .padding(.horizontal, 5)
                .background {

                    if selectedFolderURL ==
                        node.url {

                        RoundedRectangle(
                            cornerRadius: 6
                        )
                        .fill(
                            Color
                                .accentColor
                                .opacity(0.15)
                        )
                    }
                }
                .onTapGesture {

                    selectedFolderURL =
                        node.url
                }
            }
            .onChange(
                of: isExpanded
            ) { _, expanded in

                guard expanded else {
                    return
                }

                viewModel.loadChildren(
                    for: node
                )
            }
        }
        .padding(
            .leading,
            CGFloat(level) * 10
        )
    }
}
