import AppKit
import QuickLookUI

@MainActor
final class QuickLookManager: NSObject {

    static let shared =
        QuickLookManager()

    private var previewURL: URL?

    private override init() {
        super.init()
    }

    func togglePreview(
        for document: DocumentRecord
    ) {
        guard let panel =
            QLPreviewPanel.shared()
        else {
            return
        }

        if panel.isVisible {
            panel.orderOut(nil)
            previewURL = nil
            return
        }

        previewURL =
            document.sourceURL

        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }
}

// MARK: - QLPreviewPanelDataSource

extension QuickLookManager:
    QLPreviewPanelDataSource {

    func numberOfPreviewItems(
        in panel: QLPreviewPanel!
    ) -> Int {
        previewURL == nil ? 0 : 1
    }

    func previewPanel(
        _ panel: QLPreviewPanel!,
        previewItemAt index: Int
    ) -> QLPreviewItem {

        guard let previewURL else {
            return NSURL(
                fileURLWithPath: "/"
            )
        }

        return previewURL as NSURL
    }
}

// MARK: - QLPreviewPanelDelegate

extension QuickLookManager:
    QLPreviewPanelDelegate {

    func previewPanelWillClose(
        _ panel: QLPreviewPanel!
    ) {
        previewURL = nil
    }
}
