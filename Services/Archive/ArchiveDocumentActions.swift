import Foundation
import AppKit

struct ArchiveDocumentActions {

    func open(
        _ document: DocumentRecord
    ) {
        NSWorkspace.shared.open(
            document.sourceURL
        )
    }

    func revealInFinder(
        _ document: DocumentRecord
    ) {
        NSWorkspace.shared
            .activateFileViewerSelecting(
                [document.sourceURL]
            )
    }
}
