import Foundation

struct ArchiveDocumentService: Sendable {

    enum DocumentError: LocalizedError {
        case folderDoesNotExist
        case couldNotReadFolder(URL)

        var errorDescription: String? {
            switch self {

            case .folderDoesNotExist:
                return "Der ausgewählte Archivordner existiert nicht."

            case .couldNotReadFolder(let url):
                return "Der Ordner konnte nicht gelesen werden: \(url.lastPathComponent)"
            }
        }
    }

    func documents(
        in folderURL: URL
    ) throws -> [DocumentRecord] {

        guard FileManager.default.fileExists(
            atPath: folderURL.path
        ) else {
            throw DocumentError.folderDoesNotExist
        }

        let resourceKeys: Set<URLResourceKey> = [
            .isRegularFileKey
        ]

        let urls: [URL]

        do {
            urls = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys:
                    Array(resourceKeys),
                options: [
                    .skipsHiddenFiles
                ]
            )
        } catch {
            throw DocumentError.couldNotReadFolder(
                folderURL
            )
        }

        return urls
            .filter { url in

                guard
                    url.pathExtension
                        .lowercased() == "pdf"
                else {
                    return false
                }

                let values = try? url.resourceValues(
                    forKeys: resourceKeys
                )

                return values?.isRegularFile == true
            }
            .sorted { first, second in
                first.lastPathComponent
                    .localizedStandardCompare(
                        second.lastPathComponent
                    ) == .orderedAscending
            }
            .map { url in
                DocumentRecord(
                    sourceURL: url
                )
            }
    }
}
