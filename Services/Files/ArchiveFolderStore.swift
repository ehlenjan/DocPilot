import Foundation
import Observation

@Observable
final class ArchiveFolderStore {

    private let bookmarkStore = FolderBookmarkStore(
        key: "docpilot.archiveFolderBookmark"
    )

    private(set) var folderURL: URL?
    private(set) var errorMessage: String?

    private var isAccessingFolder = false

    init() {
        restoreFolder()
    }

    deinit {
        stopAccessingFolder()
    }

    func saveFolder(_ url: URL) {
        stopAccessingFolder()

        errorMessage = nil
        folderURL = url

        startAccessingFolder(url)

        do {
            try bookmarkStore.save(url: url)
        } catch {
            errorMessage =
                "Der Archivordner ist für diese Sitzung geöffnet, konnte aber nicht dauerhaft gespeichert werden: \(error.localizedDescription)"
        }
    }

    func removeFolder() {
        stopAccessingFolder()

        bookmarkStore.remove()

        folderURL = nil
        errorMessage = nil
    }

    private func restoreFolder() {
        errorMessage = nil

        do {
            guard let restoredURL = try bookmarkStore.load() else {
                folderURL = nil
                return
            }

            folderURL = restoredURL
            startAccessingFolder(restoredURL)
        } catch {
            folderURL = nil
            errorMessage =
                "Der Archivordner konnte nicht wiederhergestellt werden: \(error.localizedDescription)"
        }
    }

    private func startAccessingFolder(
        _ url: URL
    ) {
        isAccessingFolder =
            url.startAccessingSecurityScopedResource()

        if !isAccessingFolder {
            errorMessage =
                "Auf den gespeicherten Archivordner konnte nicht zugegriffen werden."
        }
    }

    private func stopAccessingFolder() {
        guard
            isAccessingFolder,
            let folderURL
        else {
            return
        }

        folderURL.stopAccessingSecurityScopedResource()
        isAccessingFolder = false
    }
}
