import SwiftUI

struct ArchiveMoveSheet: View {

    let document: DocumentRecord
    let viewModel: ArchiveViewModel

    let isMoving: Bool
    let errorMessage: String?

    let onCancel: () -> Void
    let onMove: (URL) -> Void

    var body: some View {
        ArchiveFolderPickerSheet(
            title: "Dokument verschieben",
            subtitle: document.originalFilename,
            actionTitle: "Verschieben",
            viewModel: viewModel,
            isWorking: isMoving,
            errorMessage: errorMessage,
            onCancel: onCancel,
            onSelect: onMove
        )
    }
}
