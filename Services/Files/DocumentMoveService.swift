import Foundation

struct DocumentMoveService {

    private let archiveService = ArchiveService()

    func move(
        documentURL: URL,
        to folder: ArchiveNode
    ) throws -> URL {

        try archiveService.move(
            documentURL: documentURL,
            to: folder.url
        )
    }

    func move(
        document: DocumentRecord,
        to folder: ArchiveNode
    ) throws -> URL {

        try move(
            documentURL: document.sourceURL,
            to: folder
        )
    }
}
