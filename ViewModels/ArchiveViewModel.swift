import Foundation
import Observation

@MainActor
@Observable
final class ArchiveViewModel {

    private let archiveWorkspaceStore =
        ArchiveWorkspaceStore()

    private let scanner =
        ArchiveScanner()

    private let documentService =
        ArchiveDocumentService()

    private let fileMover =
        ArchiveFileMover()

    var rootNodesByWorkspace: [UUID: ArchiveNode] = [:]

    var errorMessage: String?

    var isLoading = false

    var loadingURLs: Set<URL> = []

    var documents: [DocumentRecord] = []

    var isLoadingDocuments = false

    var documentErrorMessage: String?

    var isMovingDocument = false

    var moveErrorMessage: String?

    var workspaces: [ArchiveWorkspace] {
        archiveWorkspaceStore.workspaces
    }

    // MARK: - Archive Loading

    func reload() {
        errorMessage = nil
        rootNodesByWorkspace = [:]
        isLoading = true

        let availableWorkspaces =
            archiveWorkspaceStore.workspaces.filter { workspace in
                archiveWorkspaceStore.folderURL(
                    for: workspace
                ) != nil
            }

        guard !availableWorkspaces.isEmpty else {
            errorMessage =
                "Für keinen Arbeitsbereich wurde bisher ein Archivort ausgewählt."

            isLoading = false
            return
        }

        Task {
            var loadedRoots: [UUID: ArchiveNode] = [:]
            var errors: [String] = []

            for workspace in availableWorkspaces {

                guard let folder =
                    archiveWorkspaceStore.folderURL(
                        for: workspace
                    )
                else {
                    continue
                }

                do {
                    let scannedRoot =
                        try await Task.detached(
                            priority: .userInitiated
                        ) {
                            try self.scanner.scanRoot(
                                rootURL: folder
                            )
                        }
                        .value

                    loadedRoots[workspace.id] =
                        scannedRoot

                } catch {
                    errors.append(
                        "\(workspace.name): \(error.localizedDescription)"
                    )
                }
            }

            rootNodesByWorkspace =
                loadedRoots

            if errors.isEmpty {
                errorMessage = nil
            } else {
                errorMessage =
                    errors.joined(
                        separator: "\n"
                    )
            }

            isLoading = false
        }
    }

    // MARK: - Workspace

    func rootNode(
        for workspace: ArchiveWorkspace
    ) -> ArchiveNode? {
        rootNodesByWorkspace[
            workspace.id
        ]
    }

    func folderURL(
        for workspace: ArchiveWorkspace
    ) -> URL? {
        archiveWorkspaceStore.folderURL(
            for: workspace
        )
    }

    // MARK: - Folder Loading

    func loadChildren(
        for node: ArchiveNode
    ) {
        guard !loadingURLs.contains(
            node.url
        ) else {
            return
        }

        loadingURLs.insert(
            node.url
        )

        Task {
            do {
                let children =
                    try await Task.detached(
                        priority: .userInitiated
                    ) {
                        try self.scanner.loadChildren(
                            of: node.url
                        )
                    }
                    .value

                updateNode(
                    url: node.url,
                    children: children
                )

            } catch {
                errorMessage =
                    error.localizedDescription
            }

            loadingURLs.remove(
                node.url
            )
        }
    }

    func isLoadingChildren(
        for node: ArchiveNode
    ) -> Bool {
        loadingURLs.contains(
            node.url
        )
    }

    // MARK: - Documents

    func loadDocuments(
        for node: ArchiveNode
    ) {
        documents = []
        documentErrorMessage = nil
        isLoadingDocuments = true

        Task {
            do {
                let loadedDocuments =
                    try await Task.detached(
                        priority: .userInitiated
                    ) {
                        try self.documentService.documents(
                            in: node.url
                        )
                    }
                    .value

                documents =
                    loadedDocuments

            } catch {
                documentErrorMessage =
                    error.localizedDescription
            }

            isLoadingDocuments = false
        }
    }

    // MARK: - Move Document

    func moveDocument(
        _ document: DocumentRecord,
        to destinationFolderURL: URL,
        currentFolder: ArchiveNode?
    ) async -> Bool {

        moveErrorMessage = nil
        isMovingDocument = true

        defer {
            isMovingDocument = false
        }

        do {
            _ = try await Task.detached(
                priority: .userInitiated
            ) {
                try self.fileMover.move(
                    file: document.sourceURL,
                    to: destinationFolderURL
                )
            }
            .value

            if let currentFolder {
                loadDocuments(
                    for: currentFolder
                )
            }

            return true

        } catch {
            moveErrorMessage =
                error.localizedDescription

            return false
        }
    }

    // MARK: - Tree Update

    private func updateNode(
        url: URL,
        children: [ArchiveNode]
    ) {
        let workspaceIDs =
            Array(
                rootNodesByWorkspace.keys
            )

        for workspaceID in workspaceIDs {

            guard var rootNode =
                rootNodesByWorkspace[
                    workspaceID
                ]
            else {
                continue
            }

            if rootNode.url == url {
                rootNode.children =
                    children

                rootNodesByWorkspace[
                    workspaceID
                ] = rootNode

                return
            }

            if updateChildren(
                in: &rootNode,
                targetURL: url,
                children: children
            ) {
                rootNodesByWorkspace[
                    workspaceID
                ] = rootNode

                return
            }
        }
    }

    private func updateChildren(
        in node: inout ArchiveNode,
        targetURL: URL,
        children: [ArchiveNode]
    ) -> Bool {
        for index in node.children.indices {

            if node.children[index].url ==
                targetURL {

                node.children[index]
                    .children =
                    children

                return true
            }

            if updateChildren(
                in: &node.children[index],
                targetURL: targetURL,
                children: children
            ) {
                return true
            }
        }

        return false
    }
}
