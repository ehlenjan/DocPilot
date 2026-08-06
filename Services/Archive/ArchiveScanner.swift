import Foundation

struct ArchiveScanner {

    enum ScanError: LocalizedError {
        case folderDoesNotExist
        case couldNotReadFolder(URL)

        var errorDescription: String? {
            switch self {

            case .folderDoesNotExist:
                return "Der Archivordner existiert nicht."

            case .couldNotReadFolder(let url):
                return "Der Ordner konnte nicht gelesen werden: \(url.lastPathComponent)"
            }
        }
    }

    func scan(rootURL: URL) throws -> ArchiveNode {

        guard FileManager.default.fileExists(atPath: rootURL.path) else {
            throw ScanError.folderDoesNotExist
        }

        return try scanNode(at: rootURL)
    }

    private func scanNode(
        at url: URL
    ) throws -> ArchiveNode {

        let resourceKeys: Set<URLResourceKey> = [
            .isDirectoryKey
        ]

        let urls = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [
                .skipsHiddenFiles
            ]
        )

        let childFolders = try urls
            .filter {

                let values = try? $0.resourceValues(
                    forKeys: resourceKeys
                )

                return values?.isDirectory == true
            }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare(
                    $1.lastPathComponent
                ) == .orderedAscending
            }
            .map {
                try scanNode(at: $0)
            }

        return ArchiveNode(
            name: url.lastPathComponent,
            url: url,
            children: childFolders
        )
    }
}
