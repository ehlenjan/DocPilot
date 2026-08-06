import Foundation
import Observation

@Observable
final class ArchiveViewModel {

    private let archiveFolderStore = ArchiveFolderStore()
    private let scanner = ArchiveScanner()

    var rootNode: ArchiveNode?
    var errorMessage: String?

    func reload() {

        errorMessage = nil
        rootNode = nil

        guard let folder = archiveFolderStore.folderURL else {
            errorMessage = "Kein Archivordner ausgewählt."
            return
        }

        do {
            rootNode = try scanner.scan(
                rootURL: folder
            )

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
