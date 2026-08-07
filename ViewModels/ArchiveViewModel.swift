import Foundation
import Observation

@MainActor
@Observable
final class ArchiveViewModel {

    private let archiveWorkspaceStore = ArchiveWorkspaceStore()
    private let scanner = ArchiveScanner()

    var rootNode: ArchiveNode?
    var errorMessage: String?

    var isLoading = false
    var loadingURLs: Set<URL> = []

    func reload() {
        errorMessage = nil
        rootNode = nil
        isLoading = true

        guard let workspace =
            archiveWorkspaceStore.workspaces.first
        else {
            errorMessage = "Es wurde noch kein Arbeitsbereich angelegt."
            isLoading = false
            return
        }

        guard let folder =
            archiveWorkspaceStore.folderURL(
                for: workspace
            )
        else {
            errorMessage =
                "Für \(workspace.name) wurde noch kein Archivort ausgewählt."
            isLoading = false
            return
        }

        Task {
            do {
                let scannedRoot = try await Task.detached(
                    priority: .userInitiated
                ) {
                    try self.scanner.scanRoot(
                        rootURL: folder
                    )
                }
                .value

                rootNode = scannedRoot

            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }

    func loadChildren(
        for node: ArchiveNode
    ) {
        guard !loadingURLs.contains(node.url) else {
            return
        }

        loadingURLs.insert(node.url)

        Task {
            do {
                let children = try await Task.detached(
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
                errorMessage = error.localizedDescription
            }

            loadingURLs.remove(node.url)
        }
    }

    func isLoadingChildren(
        for node: ArchiveNode
    ) -> Bool {
        loadingURLs.contains(node.url)
    }

    private func updateNode(
        url: URL,
        children: [ArchiveNode]
    ) {
        guard var rootNode else {
            return
        }

        if rootNode.url == url {
            rootNode.children = children
            self.rootNode = rootNode
            return
        }

        guard updateChildren(
            in: &rootNode,
            targetURL: url,
            children: children
        ) else {
            return
        }

        self.rootNode = rootNode
    }

    private func updateChildren(
        in node: inout ArchiveNode,
        targetURL: URL,
        children: [ArchiveNode]
    ) -> Bool {
        for index in node.children.indices {
            if node.children[index].url == targetURL {
                node.children[index].children = children
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
