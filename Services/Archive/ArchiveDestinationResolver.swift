import Foundation

struct ArchiveDestinationResolver: Sendable {

    enum ResolverError: LocalizedError {
        case emptyPath
        case folderDoesNotExist(URL)
        case destinationIsNotFolder(URL)

        var errorDescription: String? {
            switch self {

            case .emptyPath:
                return "Für den Archivvorschlag wurde kein Zielordner angegeben."

            case .folderDoesNotExist(let url):
                return "Der vorgeschlagene Zielordner wurde nicht gefunden: \(url.path)"

            case .destinationIsNotFolder(let url):
                return "Das vorgeschlagene Archivziel ist kein Ordner: \(url.path)"
            }
        }
    }

    func resolve(
        rootURL: URL,
        relativePath: String
    ) throws -> URL {

        let cleanedPath =
            relativePath
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .trimmingCharacters(
                    in: CharacterSet(
                        charactersIn: "/"
                    )
                )

        guard !cleanedPath.isEmpty else {
            throw ResolverError.emptyPath
        }

        let components =
            cleanedPath
                .split(separator: "/")
                .map(String.init)

        var destinationURL =
            rootURL

        for component in components {
            destinationURL =
                destinationURL
                    .appendingPathComponent(
                        component,
                        isDirectory: true
                    )
        }

        var isDirectory:
            ObjCBool = false

        guard FileManager.default.fileExists(
            atPath: destinationURL.path,
            isDirectory: &isDirectory
        ) else {
            throw ResolverError
                .folderDoesNotExist(
                    destinationURL
                )
        }

        guard isDirectory.boolValue else {
            throw ResolverError
                .destinationIsNotFolder(
                    destinationURL
                )
        }

        return destinationURL
    }
}
