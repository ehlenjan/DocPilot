import Foundation

struct ArchiveScanner: Sendable {

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

    // MARK: - Root

    func scanRoot(
        rootURL: URL
    ) throws -> ArchiveNode {

        guard FileManager.default.fileExists(
            atPath: rootURL.path
        ) else {
            throw ScanError.folderDoesNotExist
        }

        let children = try loadChildren(
            of: rootURL
        )

        return ArchiveNode(
            name: rootURL.lastPathComponent,
            url: rootURL,
            children: children
        )
    }

    // MARK: - Compatibility

    func scan(
        rootURL: URL
    ) throws -> ArchiveNode {

        try scanRoot(
            rootURL: rootURL
        )
    }

    // MARK: - Children

    func loadChildren(
        of folderURL: URL
    ) throws -> [ArchiveNode] {

        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists(
            atPath: folderURL.path,
            isDirectory: &isDirectory
        ),
        isDirectory.boolValue
        else {
            throw ScanError.folderDoesNotExist
        }

        let resourceKeys: Set<URLResourceKey> = [
            .isDirectoryKey
        ]

        let urls: [URL]

        do {
            urls = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [
                    .skipsHiddenFiles
                ]
            )
        } catch {
            throw ScanError.couldNotReadFolder(
                folderURL
            )
        }

        return urls
            .filter { url in
                guard let values = try? url.resourceValues(
                    forKeys: resourceKeys
                ) else {
                    return false
                }

                return values.isDirectory == true
            }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare(
                    $1.lastPathComponent
                ) == .orderedAscending
            }
            .map { url in
                ArchiveNode(
                    name: url.lastPathComponent,
                    url: url,
                    children: []
                )
            }
    }
}
