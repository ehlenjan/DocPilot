import Foundation
import Observation

@Observable
final class InboxFolderStore {

    private(set) var folderURL: URL?
    private(set) var errorMessage: String?

    private var isAccessingFolder = false

    deinit {
        stopAccessingFolder()
    }

    func saveFolder(_ url: URL) {
        stopAccessingFolder()

        errorMessage = nil
        folderURL = url

        isAccessingFolder = url.startAccessingSecurityScopedResource()

        if !isAccessingFolder {
            errorMessage = "Auf den ausgewählten Ordner konnte nicht zugegriffen werden."
        }
    }

    func removeFolder() {
        stopAccessingFolder()
        folderURL = nil
        errorMessage = nil
    }

    private func stopAccessingFolder() {
        guard isAccessingFolder, let folderURL else {
            return
        }

        folderURL.stopAccessingSecurityScopedResource()
        isAccessingFolder = false
    }
}
