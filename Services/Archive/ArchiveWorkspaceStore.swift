import Foundation
import Observation

@Observable
final class ArchiveWorkspaceStore {

    private let userDefaults: UserDefaults
    private let storageKey = "docpilot.archiveWorkspaces"

    private(set) var workspaces: [ArchiveWorkspace] = []
    private(set) var folderURLs: [UUID: URL] = [:]
    private(set) var errorMessages: [UUID: String] = [:]

    private var bookmarkStores: [UUID: FolderBookmarkStore] = [:]
    private var accessStates: [UUID: Bool] = [:]

    init(
        userDefaults: UserDefaults = .standard
    ) {
        self.userDefaults = userDefaults

        loadWorkspaces()
        prepareBookmarkStores()
        restoreFolders()
    }

    deinit {
        stopAccessingAllFolders()
    }

    // MARK: - Workspaces

    func addWorkspace(
        name: String,
        icon: String = "externaldrive"
    ) {
        let trimmedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedName.isEmpty else {
            return
        }

        let workspace = ArchiveWorkspace(
            name: trimmedName,
            icon: icon
        )

        workspaces.append(workspace)

        bookmarkStores[workspace.id] =
            makeBookmarkStore(
                for: workspace.id
            )

        saveWorkspaces()
    }

    func removeWorkspace(
        _ workspace: ArchiveWorkspace
    ) {
        removeFolder(
            for: workspace
        )

        workspaces.removeAll {
            $0.id == workspace.id
        }

        bookmarkStores.removeValue(
            forKey: workspace.id
        )

        accessStates.removeValue(
            forKey: workspace.id
        )

        errorMessages.removeValue(
            forKey: workspace.id
        )

        saveWorkspaces()
    }

    func updateWorkspace(
        _ workspace: ArchiveWorkspace,
        name: String,
        icon: String
    ) {
        guard let index = workspaces.firstIndex(
            where: {
                $0.id == workspace.id
            }
        ) else {
            return
        }

        let trimmedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedName.isEmpty else {
            return
        }

        workspaces[index].name = trimmedName
        workspaces[index].icon = icon

        saveWorkspaces()
    }

    func workspace(
        id: UUID
    ) -> ArchiveWorkspace? {
        workspaces.first {
            $0.id == id
        }
    }
    func workspace(
        matching area: ArchiveArea
    ) -> ArchiveWorkspace? {
        workspaces.first { workspace in
            workspace.name.compare(
                area.rawValue,
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive
                ]
            ) == .orderedSame
        }
    }

    // MARK: - Folder Locations

    func folderURL(
        for workspace: ArchiveWorkspace
    ) -> URL? {
        folderURLs[workspace.id]
    }

    func errorMessage(
        for workspace: ArchiveWorkspace
    ) -> String? {
        errorMessages[workspace.id]
    }

    func saveFolder(
        _ url: URL,
        for workspace: ArchiveWorkspace
    ) {
        stopAccessingFolder(
            for: workspace
        )

        errorMessages[workspace.id] = nil
        folderURLs[workspace.id] = url

        startAccessingFolder(
            url,
            for: workspace
        )

        let bookmarkStore =
            bookmarkStores[workspace.id]
            ?? makeBookmarkStore(
                for: workspace.id
            )

        bookmarkStores[workspace.id] =
            bookmarkStore

        do {
            try bookmarkStore.save(
                url: url
            )
        } catch {
            errorMessages[workspace.id] =
                "Der Archivort ist für diese Sitzung geöffnet, konnte aber nicht dauerhaft gespeichert werden: \(error.localizedDescription)"
        }
    }

    func removeFolder(
        for workspace: ArchiveWorkspace
    ) {
        stopAccessingFolder(
            for: workspace
        )

        bookmarkStores[workspace.id]?
            .remove()

        folderURLs.removeValue(
            forKey: workspace.id
        )

        errorMessages.removeValue(
            forKey: workspace.id
        )
    }

    // MARK: - Workspace Persistence

    private func loadWorkspaces() {
        guard
            let data = userDefaults.data(
                forKey: storageKey
            )
        else {
            createDefaultWorkspaces()
            return
        }

        do {
            workspaces = try JSONDecoder().decode(
                [ArchiveWorkspace].self,
                from: data
            )

            if workspaces.isEmpty {
                createDefaultWorkspaces()
            }

        } catch {
            print(
                "Arbeitsbereiche konnten nicht geladen werden: \(error.localizedDescription)"
            )

            createDefaultWorkspaces()
        }
    }

    private func saveWorkspaces() {
        do {
            let data = try JSONEncoder().encode(
                workspaces
            )

            userDefaults.set(
                data,
                forKey: storageKey
            )

        } catch {
            print(
                "Arbeitsbereiche konnten nicht gespeichert werden: \(error.localizedDescription)"
            )
        }
    }

    private func createDefaultWorkspaces() {
        workspaces = [
            ArchiveWorkspace(
                name: "Betrieb",
                icon: "building.2"
            ),
            ArchiveWorkspace(
                name: "EHA KG",
                icon: "shippingbox"
            ),
            ArchiveWorkspace(
                name: "Jan Ehlen",
                icon: "person"
            ),
            ArchiveWorkspace(
                name: "Feuerwehr",
                icon: "flame"
            )
        ]

        saveWorkspaces()
    }

    // MARK: - Bookmark Setup

    private func prepareBookmarkStores() {
        for workspace in workspaces {
            bookmarkStores[workspace.id] =
                makeBookmarkStore(
                    for: workspace.id
                )
        }
    }

    private func restoreFolders() {
        for workspace in workspaces {
            restoreFolder(
                for: workspace
            )
        }
    }

    private func restoreFolder(
        for workspace: ArchiveWorkspace
    ) {
        guard let bookmarkStore =
                bookmarkStores[workspace.id]
        else {
            return
        }

        errorMessages[workspace.id] = nil

        do {
            guard let restoredURL =
                    try bookmarkStore.load()
            else {
                return
            }

            folderURLs[workspace.id] =
                restoredURL

            startAccessingFolder(
                restoredURL,
                for: workspace
            )

        } catch {
            folderURLs.removeValue(
                forKey: workspace.id
            )

            errorMessages[workspace.id] =
                "Der Archivort \(workspace.name) konnte nicht wiederhergestellt werden: \(error.localizedDescription)"
        }
    }

    private func makeBookmarkStore(
        for workspaceID: UUID
    ) -> FolderBookmarkStore {
        FolderBookmarkStore(
            key:
                "docpilot.archiveWorkspace.\(workspaceID.uuidString).bookmark"
        )
    }

    // MARK: - Security Scope

    private func startAccessingFolder(
        _ url: URL,
        for workspace: ArchiveWorkspace
    ) {
        let isAccessing =
            url.startAccessingSecurityScopedResource()

        accessStates[workspace.id] =
            isAccessing

        if !isAccessing {
            errorMessages[workspace.id] =
                "Auf den Archivort \(workspace.name) konnte nicht zugegriffen werden."
        }
    }

    private func stopAccessingFolder(
        for workspace: ArchiveWorkspace
    ) {
        guard
            accessStates[workspace.id] == true,
            let folderURL =
                folderURLs[workspace.id]
        else {
            return
        }

        folderURL
            .stopAccessingSecurityScopedResource()

        accessStates[workspace.id] = false
    }

    private func stopAccessingAllFolders() {
        for workspace in workspaces {
            stopAccessingFolder(
                for: workspace
            )
        }
    }
}
