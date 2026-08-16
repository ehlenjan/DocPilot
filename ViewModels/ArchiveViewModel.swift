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

    var rootNodesByWorkspace:
        [UUID: ArchiveNode] = [:]

    var errorMessage:
        String?

    var isLoading =
        false

    var loadingURLs:
        Set<URL> = []

    var documents:
        [DocumentRecord] = []

    var isLoadingDocuments =
        false

    var documentErrorMessage:
        String?

    var isMovingDocument =
        false

    var moveErrorMessage:
        String?

    var workspaces:
        [ArchiveWorkspace] {

        archiveWorkspaceStore
            .workspaces
    }

    // MARK: - Archive Loading

    func reload() {

        errorMessage =
            nil

        rootNodesByWorkspace =
            [:]

        isLoading =
            true

        let availableWorkspaces =
            archiveWorkspaceStore
                .workspaces
                .filter {
                    workspace in

                    archiveWorkspaceStore
                        .folderURL(
                            for:
                                workspace
                        ) != nil
                }

        guard
            !availableWorkspaces.isEmpty
        else {

            errorMessage =
                "Für keinen Arbeitsbereich wurde bisher ein Archivort ausgewählt."

            isLoading =
                false

            return
        }

        Task {

            var loadedRoots:
                [UUID: ArchiveNode] = [:]

            var errors:
                [String] = []

            for workspace in
                availableWorkspaces {

                guard let folder =
                    archiveWorkspaceStore
                        .folderURL(
                            for:
                                workspace
                        )
                else {

                    continue
                }

                do {

                    let scannedRoot =
                        try await Task.detached(
                            priority:
                                .userInitiated
                        ) {

                            try self.scanner
                                .scanRoot(
                                    rootURL:
                                        folder
                                )
                        }
                        .value

                    loadedRoots[
                        workspace.id
                    ] =
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

                errorMessage =
                    nil

            } else {

                errorMessage =
                    errors.joined(
                        separator:
                            "\n"
                    )
            }

            isLoading =
                false
        }
    }

    // MARK: - Workspace

    func rootNode(
        for workspace:
            ArchiveWorkspace
    ) -> ArchiveNode? {

        rootNodesByWorkspace[
            workspace.id
        ]
    }

    func folderURL(
        for workspace:
            ArchiveWorkspace
    ) -> URL? {

        archiveWorkspaceStore
            .folderURL(
                for:
                    workspace
            )
    }

    // MARK: - Folder Loading

    func loadChildren(
        for node:
            ArchiveNode
    ) {

        guard
            !loadingURLs.contains(
                node.url
            )
        else {

            return
        }

        loadingURLs.insert(
            node.url
        )

        Task {

            do {

                let children =
                    try await Task.detached(
                        priority:
                            .userInitiated
                    ) {

                        try self.scanner
                            .loadChildren(
                                of:
                                    node.url
                            )
                    }
                    .value

                updateNode(
                    url:
                        node.url,
                    children:
                        children
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
        for node:
            ArchiveNode
    ) -> Bool {

        loadingURLs.contains(
            node.url
        )
    }

    // MARK: - Automatic Destination Suggestion

    /// Sucht nur in tatsächlich geladenen
    /// Archivordnern.
    ///
    /// Es wird niemals ein Pfad erfunden.
    func suggestDestination(
        for area: ArchiveArea,
        documentType: DocumentType,
        sender: String?
    ) -> URL? {

        guard
            let workspace =
                archiveWorkspaceStore
                    .workspace(
                        matching:
                            area
                    )
        else {

            return nil
        }

        guard
            let rootNode =
                rootNode(
                    for:
                        workspace
                )
        else {

            return nil
        }

        let allNodes =
            flattenedNodes(
                from:
                    rootNode
            )

        guard
            !allNodes.isEmpty
        else {

            return nil
        }

        let cleanedSender =
            sender?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        let documentTerms =
            searchTerms(
                for:
                    documentType
            )

        var scored:
            [(node: ArchiveNode, score: Int)] =
            []

        for node in
            allNodes {

            let normalizedName =
                normalize(
                    node.name
                )

            guard
                !normalizedName.isEmpty
            else {

                continue
            }

            var score =
                0

            // MARK: Document Type

            for term in
                documentTerms {

                if normalizedName.contains(
                    normalize(
                        term
                    )
                ) {

                    score +=
                        100
                }
            }

            // MARK: Sender / Company

            if !cleanedSender.isEmpty {

                let normalizedSender =
                    normalize(
                        cleanedSender
                    )

                if normalizedName.contains(
                    normalizedSender
                ) {

                    score +=
                        40
                }
            }

            // MARK: Exact-ish Folder Names

            if isStrongFolderMatch(
                folderName:
                    node.name,
                documentType:
                    documentType
            ) {

                score +=
                    50
            }

            // Root selbst soll nicht bevorzugt
            // werden, wenn echte Unterordner da sind.
            if node.url ==
                rootNode.url {

                score -=
                    30
            }

            if score > 0 {

                scored.append(
                    (
                        node:
                            node,
                        score:
                            score
                    )
                )
            }
        }

        let sorted =
            scored.sorted {

                if $0.score ==
                    $1.score {

                    return
                        $0.node.name
                            .localizedStandardCompare(
                                $1.node.name
                            )
                        ==
                        .orderedAscending
                }

                return
                    $0.score >
                    $1.score
            }

        guard let best =
            sorted.first
        else {

            return nil
        }

        // Wenn die besten zwei nahezu gleich
        // stark sind, lieber keine automatische
        // Auswahl treffen.
        if sorted.count > 1 {

            let second =
                sorted[1]

            if best.score -
                second.score < 20 {

                return nil
            }
        }

        return best.node.url
    }

    // MARK: - Search Terms

    private func searchTerms(
        for documentType:
            DocumentType
    ) -> [String] {

        let raw =
            documentType
                .rawValue
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        var terms:
            [String] = []

        if !raw.isEmpty {

            terms.append(
                raw
            )
        }

        switch documentType {

        case .deliveryNote:

            terms.append(
                contentsOf: [
                    "Lieferschein",
                    "Lieferscheine",
                    "Lieferung"
                ]
            )

        case .invoice:

            terms.append(
                contentsOf: [
                    "Rechnung",
                    "Rechnungen",
                    "Belege",
                    "Finanzen"
                ]
            )

        default:

            break
        }

        return uniqueTerms(
            terms
        )
    }

    // MARK: - Strong Folder Match

    private func isStrongFolderMatch(
        folderName: String,
        documentType: DocumentType
    ) -> Bool {

        let normalizedName =
            normalize(
                folderName
            )

        switch documentType {

        case .deliveryNote:

            return
                normalizedName ==
                    "lieferschein"
                ||
                normalizedName ==
                    "lieferscheine"
                ||
                normalizedName
                    .hasPrefix(
                        "lieferschein "
                    )
                ||
                normalizedName
                    .hasPrefix(
                        "lieferscheine "
                    )

        case .invoice:

            return
                normalizedName ==
                    "rechnung"
                ||
                normalizedName ==
                    "rechnungen"
                ||
                normalizedName
                    .hasPrefix(
                        "rechnung "
                    )
                ||
                normalizedName
                    .hasPrefix(
                        "rechnungen "
                    )

        default:

            let normalizedType =
                normalize(
                    documentType
                        .rawValue
                )

            guard
                !normalizedType.isEmpty
            else {

                return false
            }

            return
                normalizedName ==
                    normalizedType
                ||
                normalizedName
                    .hasPrefix(
                        normalizedType
                        + " "
                    )
        }
    }

    // MARK: - Flatten Tree

    private func flattenedNodes(
        from root:
            ArchiveNode
    ) -> [ArchiveNode] {

        var result:
            [ArchiveNode] = [
                root
            ]

        for child in
            root.children {

            result.append(
                contentsOf:
                    flattenedNodes(
                        from:
                            child
                    )
            )
        }

        return result
    }

    // MARK: - Unique Terms

    private func uniqueTerms(
        _ terms:
            [String]
    ) -> [String] {

        var result:
            [String] = []

        var seen:
            Set<String> = []

        for term in
            terms {

            let cleaned =
                term
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            guard
                !cleaned.isEmpty
            else {

                continue
            }

            let key =
                normalize(
                    cleaned
                )

            guard
                !seen.contains(
                    key
                )
            else {

                continue
            }

            seen.insert(
                key
            )

            result.append(
                cleaned
            )
        }

        return result
    }

    // MARK: - Normalize

    private func normalize(
        _ value:
            String
    ) -> String {

        value
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive
                ],
                locale:
                    Locale(
                        identifier:
                            "de_DE"
                    )
            )
            .lowercased()
    }

    // MARK: - Documents

    func loadDocuments(
        for node:
            ArchiveNode
    ) {

        documents =
            []

        documentErrorMessage =
            nil

        isLoadingDocuments =
            true

        Task {

            do {

                let loadedDocuments =
                    try await Task.detached(
                        priority:
                            .userInitiated
                    ) {

                        try self.documentService
                            .documents(
                                in:
                                    node.url
                            )
                    }
                    .value

                documents =
                    loadedDocuments

            } catch {

                documentErrorMessage =
                    error.localizedDescription
            }

            isLoadingDocuments =
                false
        }
    }

    // MARK: - Move Document

    func moveDocument(
        _ document:
            DocumentRecord,
        to destinationFolderURL:
            URL,
        currentFolder:
            ArchiveNode?
    ) async -> Bool {

        moveErrorMessage =
            nil

        isMovingDocument =
            true

        defer {

            isMovingDocument =
                false
        }

        do {

            _ =
                try await Task.detached(
                    priority:
                        .userInitiated
                ) {

                    try self.fileMover
                        .move(
                            file:
                                document.sourceURL,
                            to:
                                destinationFolderURL
                        )
                }
                .value

            if let currentFolder {

                loadDocuments(
                    for:
                        currentFolder
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
        url:
            URL,
        children:
            [ArchiveNode]
    ) {

        let workspaceIDs =
            Array(
                rootNodesByWorkspace
                    .keys
            )

        for workspaceID in
            workspaceIDs {

            guard var rootNode =
                rootNodesByWorkspace[
                    workspaceID
                ]
            else {

                continue
            }

            if rootNode.url ==
                url {

                rootNode.children =
                    children

                rootNodesByWorkspace[
                    workspaceID
                ] =
                    rootNode

                return
            }

            if updateChildren(
                in:
                    &rootNode,
                targetURL:
                    url,
                children:
                    children
            ) {

                rootNodesByWorkspace[
                    workspaceID
                ] =
                    rootNode

                return
            }
        }
    }

    private func updateChildren(
        in node:
            inout ArchiveNode,
        targetURL:
            URL,
        children:
            [ArchiveNode]
    ) -> Bool {

        for index in
            node.children.indices {

            if node.children[index]
                .url ==
                targetURL {

                node.children[index]
                    .children =
                    children

                return true
            }

            if updateChildren(
                in:
                    &node.children[index],
                targetURL:
                    targetURL,
                children:
                    children
            ) {

                return true
            }
        }

        return false
    }
}
