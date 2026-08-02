import Foundation
import Observation

@Observable
final class InboxViewModel {

    private let folderStore = InboxFolderStore()

    var documents: [DocumentRecord] = []
    var errorMessage: String?

    var folderURL: URL? {
        folderStore.folderURL
    }

    func selectFolder(_ url: URL) {
        folderStore.saveFolder(url)
        loadDocuments()
    }

    func loadDocuments() {
        errorMessage = nil

        guard let folderURL else {
            documents = []
            return
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            documents = files
                .filter { url in
                    url.pathExtension.lowercased() == "pdf"
                }
                .sorted {
                    $0.lastPathComponent.localizedStandardCompare(
                        $1.lastPathComponent
                    ) == .orderedAscending
                }
                .map {
                    DocumentRecord(sourceURL: $0)
                }

        } catch {
            documents = []
            errorMessage =
                "Die Dateien konnten nicht gelesen werden: \(error.localizedDescription)"
        }
    }

    func removeFolder() {
        folderStore.removeFolder()
        documents = []
        errorMessage = nil
    }
}
