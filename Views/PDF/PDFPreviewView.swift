import SwiftUI
import PDFKit

struct PDFPreviewView: NSViewRepresentable {

    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .windowBackgroundColor
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        guard pdfView.document?.documentURL != url else {
            return
        }

        pdfView.document = PDFDocument(url: url)
    }
}
