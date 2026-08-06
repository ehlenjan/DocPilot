import Foundation
import AppKit

struct ArchiveService {

    enum ArchiveError: LocalizedError {
        case sourceDoesNotExist
        case destinationDoesNotExist
        case fileAlreadyExists
        case moveFailed(Error)

        var errorDescription: String? {
            switch self {
            case .sourceDoesNotExist:
                return "Die Quelldatei existiert nicht."

            case .destinationDoesNotExist:
                return "Der Zielordner existiert nicht."

            case .fileAlreadyExists:
                return "Im Zielordner existiert bereits eine Datei mit diesem Namen."

            case .moveFailed(let error):
                return "Die Datei konnte nicht archiviert werden: \(error.localizedDescription)"
            }
        }
    }

    func move(
        documentURL: URL,
        to folderURL: URL
    ) throws -> URL {
        let fileManager = FileManager.default

        guard fileManager.fileExists(
            atPath: documentURL.path
        ) else {
            throw ArchiveError.sourceDoesNotExist
        }

        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(
            atPath: folderURL.path,
            isDirectory: &isDirectory
        ),
        isDirectory.boolValue
        else {
            throw ArchiveError.destinationDoesNotExist
        }

        let destinationURL = folderURL
            .appendingPathComponent(
                documentURL.lastPathComponent
            )

        guard !fileManager.fileExists(
            atPath: destinationURL.path
        ) else {
            throw ArchiveError.fileAlreadyExists
        }

        do {
            try fileManager.moveItem(
                at: documentURL,
                to: destinationURL
            )

            return destinationURL
        } catch {
            throw ArchiveError.moveFailed(error)
        }
    }

    func revealInFinder(
        _ url: URL
    ) {
        NSWorkspace.shared.activateFileViewerSelecting(
            [url]
        )
    }
}
