import Foundation
import Observation

@Observable
final class ArchiveLocationsStore {

    private var bookmarkStores: [ArchiveArea: FolderBookmarkStore] = [:]
    private var accessStates: [ArchiveArea: Bool] = [:]

    private(set) var folderURLs: [ArchiveArea: URL] = [:]
    private(set) var errorMessages: [ArchiveArea: String] = [:]

    init() {
        for area in ArchiveArea.allCases {
            bookmarkStores[area] = FolderBookmarkStore(
                key: bookmarkKey(for: area)
            )

            restoreFolder(for: area)
        }
    }

    deinit {
        stopAccessingAllFolders()
    }

    func folderURL(
        for area: ArchiveArea
    ) -> URL? {
        folderURLs[area]
    }

    func errorMessage(
        for area: ArchiveArea
    ) -> String? {
        errorMessages[area]
    }

    func saveFolder(
        _ url: URL,
        for area: ArchiveArea
    ) {
        stopAccessingFolder(for: area)

        errorMessages[area] = nil
        folderURLs[area] = url

        startAccessingFolder(
            url,
            for: area
        )

        guard let bookmarkStore =
                bookmarkStores[area]
        else {
            errorMessages[area] =
                "Der Archivort konnte nicht vorbereitet werden."
            return
        }

        do {
            try bookmarkStore.save(
                url: url
            )
        } catch {
            errorMessages[area] =
                "Der Archivort ist für diese Sitzung geöffnet, konnte aber nicht dauerhaft gespeichert werden: \(error.localizedDescription)"
        }
    }

    func removeFolder(
        for area: ArchiveArea
    ) {
        stopAccessingFolder(
            for: area
        )

        bookmarkStores[area]?.remove()

        folderURLs.removeValue(
            forKey: area
        )

        errorMessages.removeValue(
            forKey: area
        )
    }

    private func restoreFolder(
        for area: ArchiveArea
    ) {
        errorMessages[area] = nil

        guard let bookmarkStore =
                bookmarkStores[area]
        else {
            return
        }

        do {
            guard let restoredURL =
                    try bookmarkStore.load()
            else {
                folderURLs.removeValue(
                    forKey: area
                )
                return
            }

            folderURLs[area] =
                restoredURL

            startAccessingFolder(
                restoredURL,
                for: area
            )

        } catch {
            folderURLs.removeValue(
                forKey: area
            )

            errorMessages[area] =
                "Der Archivort \(area.rawValue) konnte nicht wiederhergestellt werden: \(error.localizedDescription)"
        }
    }

    private func startAccessingFolder(
        _ url: URL,
        for area: ArchiveArea
    ) {
        let isAccessing =
            url.startAccessingSecurityScopedResource()

        accessStates[area] =
            isAccessing

        if !isAccessing {
            errorMessages[area] =
                "Auf den gespeicherten Archivort \(area.rawValue) konnte nicht zugegriffen werden."
        }
    }

    private func stopAccessingFolder(
        for area: ArchiveArea
    ) {
        guard
            accessStates[area] == true,
            let folderURL =
                folderURLs[area]
        else {
            return
        }

        folderURL
            .stopAccessingSecurityScopedResource()

        accessStates[area] = false
    }

    private func stopAccessingAllFolders() {
        for area in ArchiveArea.allCases {
            stopAccessingFolder(
                for: area
            )
        }
    }

    private func bookmarkKey(
        for area: ArchiveArea
    ) -> String {
        switch area {
        case .business:
            return "docpilot.archiveLocation.business"

        case .ehaKG:
            return "docpilot.archiveLocation.ehaKG"

        case .privateArea:
            return "docpilot.archiveLocation.private"

        case .fireDepartment:
            return "docpilot.archiveLocation.fireDepartment"
        }
    }
}
