import Foundation
import Observation

@Observable
final class InboxFolderStore {

    private enum StorageKey {
        static let bookmarkData = "inboxFolderBookmarkData"
    }

    private(set) var folderURL: URL?
    private(set) var errorMessage: String?

    private var isAccessingSecurityScopedResource = false

    init() {
        restoreFolderAccess()
    }

    deinit {
        stopAccessingFolder()
    }

    func saveFolder(_ url: URL) {
        errorMessage = nil
        stopAccessingFolder()

        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            UserDefaults.standard.set(
                bookmarkData,
                forKey: StorageKey.bookmarkData
            )

            folderURL = url
            startAccessingFolder()
        } catch {
            folderURL = nil
            errorMessage = "Der Eingangsordner konnte nicht gespeichert werden: \(error.localizedDescription)"
        }
    }

    func removeFolder() {
        stopAccessingFolder()
        folderURL = nil
        errorMessage = nil

        UserDefaults.standard.removeObject(
            forKey: StorageKey.bookmarkData
        )
    }

    private func restoreFolderAccess() {
        guard let bookmarkData = UserDefaults.standard.data(
            forKey: StorageKey.bookmarkData
        ) else {
            return
        }

        do {
            var isStale = false

            let restoredURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            folderURL = restoredURL
            startAccessingFolder()

            if isStale {
                saveFolder(restoredURL)
            }
        } catch {
            folderURL = nil
            errorMessage = "Der gespeicherte Eingangsordner konnte nicht geöffnet werden: \(error.localizedDescription)"
        }
    }

    private func startAccessingFolder() {
        guard let folderURL else {
            return
        }

        isAccessingSecurityScopedResource =
            folderURL.startAccessingSecurityScopedResource()
    }

    private func stopAccessingFolder() {
        guard
            isAccessingSecurityScopedResource,
            let folderURL
        else {
            return
        }

        folderURL.stopAccessingSecurityScopedResource()
        isAccessingSecurityScopedResource = false
    }
}
