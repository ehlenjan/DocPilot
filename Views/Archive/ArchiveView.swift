import SwiftUI

struct ArchiveView: View {

    @State private var viewModel =
        ArchiveViewModel()

    @State private var selectedNode:
        ArchiveNode?

    @State private var selectedDocument:
        DocumentRecord?

    @State private var documentToMove:
        DocumentRecord?

    var body: some View {

        HSplitView {

            archiveSidebar
                .frame(
                    minWidth: 240,
                    idealWidth: 280,
                    maxWidth: 340
                )
                .frame(
                    maxHeight: .infinity,
                    alignment: .top
                )

            documentColumn
                .frame(
                    minWidth: 300,
                    idealWidth: 360,
                    maxWidth: 460
                )
                .frame(
                    maxHeight: .infinity,
                    alignment: .top
                )

            previewColumn
                .frame(
                    minWidth: 420,
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .top
                )
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
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
        .onChange(
            of: selectedNode
        ) { _, _ in
            selectedDocument = nil
        }
        .background {
            Button {
                guard let selectedDocument else {
                    return
                }

                QuickLookManager.shared.togglePreview(
                    for: selectedDocument
                )
            } label: {
                EmptyView()
            }
            .keyboardShortcut(
                .space,
                modifiers: []
            )
            .buttonStyle(.plain)
            .hidden()
        }
        .sheet(
            item: $documentToMove
        ) { document in

            ArchiveMoveSheet(
                document: document,
                viewModel: viewModel,
                isMoving:
                    viewModel.isMovingDocument,
                errorMessage:
                    viewModel.moveErrorMessage,
                onCancel: {
                    documentToMove = nil
                },
                onMove: { destinationURL in

                    let currentFolder =
                        currentSelectedNode

                    Task {
                        let success =
                            await viewModel.moveDocument(
                                document,
                                to: destinationURL,
                                currentFolder:
                                    currentFolder
                            )

                        if success {
                            selectedDocument = nil
                            documentToMove = nil
                        }
                    }
                }
            )
        }
        .alert(
            "Verschieben fehlgeschlagen",
            isPresented: Binding(
                get: {
                    viewModel.moveErrorMessage != nil &&
                    documentToMove == nil
                },
                set: { isPresented in
                    if !isPresented {
                        viewModel.moveErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                viewModel.moveErrorMessage = nil
            }
        } message: {
            Text(
                viewModel.moveErrorMessage
                ?? "Die Datei konnte nicht verschoben werden."
            )
        }
    }

    // MARK: - Archive Sidebar

    @ViewBuilder
    private var archiveSidebar: some View {

        if viewModel.isLoading &&
            viewModel.rootNodesByWorkspace.isEmpty {

            ProgressView(
                "Archive werden geladen …"
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )

        } else if viewModel.workspaces.isEmpty {

            ContentUnavailableView(
                "Keine Arbeitsbereiche",
                systemImage: "externaldrive",
                description: Text(
                    "Lege zuerst unter Einstellungen → Archivorte einen Arbeitsbereich an."
                )
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

                        ArchiveWorkspaceRow(
                            workspace: workspace,
                            viewModel: viewModel,
                            selectedNode:
                                $selectedNode
                        )
                    }

                    if let errorMessage =
                        viewModel.errorMessage {

                        Divider()
                            .padding(.vertical, 8)

                        Label(
                            errorMessage,
                            systemImage:
                                "exclamationmark.triangle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Document Column

    @ViewBuilder
    private var documentColumn: some View {

        if let node = currentSelectedNode {

            VStack(spacing: 0) {

                documentHeader(
                    for: node
                )

                Divider()

                documentList
            }

        } else {

            ContentUnavailableView(
                "Kein Ordner ausgewählt",
                systemImage: "folder",
                description: Text(
                    "Wähle links einen Arbeitsbereich oder Ordner aus."
                )
            )
        }
    }

    // MARK: - Document Header

    private func documentHeader(
        for node: ArchiveNode
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 5
        ) {

            Label(
                node.name,
                systemImage: "folder.fill"
            )
            .font(.headline)
            .lineLimit(1)

            Text(node.url.path)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(node.url.path)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Document List

    @ViewBuilder
    private var documentList: some View {

        if viewModel.isLoadingDocuments {

            ProgressView(
                "Dokumente werden geladen …"
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )

        } else if let documentErrorMessage =
                    viewModel.documentErrorMessage {

            ContentUnavailableView(
                "Dokumente konnten nicht geladen werden",
                systemImage:
                    "exclamationmark.triangle",
                description:
                    Text(documentErrorMessage)
            )

        } else if viewModel.documents.isEmpty {

            ContentUnavailableView(
                "Keine PDFs",
                systemImage: "doc",
                description: Text(
                    "In diesem Ordner wurden keine PDF-Dateien gefunden."
                )
            )

        } else {

            List(
                viewModel.documents,
                selection: $selectedDocument
            ) { document in

                HStack(
                    alignment: .top,
                    spacing: 8
                ) {

                    Image(
                        systemName: "doc.fill"
                    )
                    .foregroundStyle(.secondary)

                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {

                        Text(
                            document.originalFilename
                        )
                        .lineLimit(2)

                        HStack(spacing: 6) {

                            Text(
                                document.formattedModificationDate
                            )

                            Text("·")

                            Text(
                                document.formattedFileSize
                            )
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .tag(document)
                .draggable(
                    document.sourceURL
                )
                .contextMenu {

                    Button {
                        ArchiveDocumentActions()
                            .open(document)
                    } label: {
                        Label(
                            "Öffnen",
                            systemImage:
                                "arrow.up.forward.app"
                        )
                    }

                    Button {
                        ArchiveDocumentActions()
                            .revealInFinder(
                                document
                            )
                    } label: {
                        Label(
                            "Im Finder zeigen",
                            systemImage: "folder"
                        )
                    }

                    Divider()

                    Button {
                        documentToMove =
                            document
                    } label: {
                        Label(
                            "Verschieben …",
                            systemImage:
                                "folder.badge.arrow.forward"
                        )
                    }
                }
            }
        }
    }

    // MARK: - Preview Column

    @ViewBuilder
    private var previewColumn: some View {

        if let selectedDocument {

            PDFPreviewView(
                url:
                    selectedDocument.sourceURL
            )

        } else if let node =
                    currentSelectedNode {

            folderInformation(
                for: node
            )

        } else {

            ContentUnavailableView(
                "Kein Dokument ausgewählt",
                systemImage:
                    "doc.text.magnifyingglass",
                description: Text(
                    "Wähle zuerst einen Ordner und anschließend eine PDF-Datei aus."
                )
            )
        }
    }

    // MARK: - Folder Information

    private func folderInformation(
        for node: ArchiveNode
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 16
        ) {

            Label(
                node.name,
                systemImage: "folder.fill"
            )
            .font(.title.bold())

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

            } else {

                HStack(spacing: 18) {

                    Label(
                        "\(node.children.count) Unterordner",
                        systemImage: "folder"
                    )

                    Label(
                        "\(viewModel.documents.count) PDFs",
                        systemImage: "doc"
                    )
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            ContentUnavailableView(
                "Kein Dokument ausgewählt",
                systemImage:
                    "doc.text.magnifyingglass",
                description: Text(
                    "Wähle in der mittleren Spalte eine PDF-Datei aus."
                )
            )

            Spacer()
        }
        .padding(24)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }

    // MARK: - Selection

    private var currentSelectedNode:
        ArchiveNode? {

        guard let selectedURL =
            selectedNode?.url
        else {
            return nil
        }

        for workspace in
            viewModel.workspaces {

            guard let rootNode =
                viewModel.rootNode(
                    for: workspace
                )
            else {
                continue
            }

            if let result = findNode(
                with: selectedURL,
                in: rootNode
            ) {
                return result
            }
        }

        return nil
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
        selectedDocument = nil
        documentToMove = nil

        viewModel.moveErrorMessage = nil

        viewModel.reload()
    }
}

// MARK: - Workspace Row

private struct ArchiveWorkspaceRow: View {

    let workspace:
        ArchiveWorkspace

    let viewModel:
        ArchiveViewModel

    @Binding var selectedNode:
        ArchiveNode?

    @State private var isExpanded =
        true

    var body: some View {

        if let rootNode =
            viewModel.rootNode(
                for: workspace
            ) {

            DisclosureGroup(
                isExpanded: $isExpanded
            ) {

                ForEach(
                    rootNode.children
                ) { node in

                    ArchiveLazyNodeRow(
                        node: node,
                        viewModel: viewModel,
                        selectedNode:
                            $selectedNode,
                        level: 1
                    )
                }

                if rootNode.children.isEmpty {

                    Text(
                        "Keine Unterordner"
                    )
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 36)
                    .padding(.vertical, 4)
                }

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
                    .lineLimit(1)

                    Spacer()
                }
                .contentShape(
                    Rectangle()
                )
                .onTapGesture {

                    selectedNode =
                        rootNode

                    viewModel.loadDocuments(
                        for: rootNode
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 3)

        } else {

            HStack(spacing: 8) {

                Image(
                    systemName:
                        workspace.icon
                )
                .frame(width: 18)

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {

                    Text(
                        workspace.name
                    )
                    .fontWeight(.semibold)

                    if viewModel.folderURL(
                        for: workspace
                    ) == nil {

                        Text(
                            "Kein Archivort ausgewählt"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    } else {

                        Text(
                            "Archiv nicht verfügbar"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Lazy Folder Row

private struct ArchiveLazyNodeRow: View {

    let node:
        ArchiveNode

    let viewModel:
        ArchiveViewModel

    @Binding var selectedNode:
        ArchiveNode?

    let level:
        Int

    @State private var isExpanded =
        false

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

                Text(
                    "Keine Unterordner"
                )
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.leading, 24)

            } else {

                ForEach(
                    node.children
                ) { child in

                    ArchiveLazyNodeRow(
                        node: child,
                        viewModel: viewModel,
                        selectedNode:
                            $selectedNode,
                        level:
                            level + 1
                    )
                }
            }

        } label: {

            HStack(spacing: 8) {

                Image(
                    systemName:
                        "folder.fill"
                )

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
            .contentShape(
                Rectangle()
            )
            .onTapGesture {

                selectedNode = node

                viewModel.loadDocuments(
                    for: node
                )
            }
        }
        .padding(
            .leading,
            CGFloat(level) * 12
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .onChange(
            of: isExpanded
        ) { _, expanded in

            guard expanded else {
                return
            }

            selectedNode = node

            viewModel.loadChildren(
                for: node
            )

            viewModel.loadDocuments(
                for: node
            )
        }
        .dropDestination(
            for: URL.self
        ) { urls, _ in

            guard let sourceURL =
                urls.first
            else {
                return false
            }

            let document =
                DocumentRecord(
                    sourceURL: sourceURL
                )

            let sourceFolder =
                selectedNode

            Task {
                _ = await viewModel.moveDocument(
                    document,
                    to: node.url,
                    currentFolder:
                        sourceFolder
                )
            }

            return true
        }
    }
}

#Preview {
    ArchiveView()
        .frame(
            width: 1400,
            height: 800
        )
}
