import SwiftUI
import PDFKit
import AppKit

struct PDFPreviewView: View {

    let url: URL

    var evidence: [PDFEvidence] = []

    // Vision-Bounding-Box des visuell
    // erkannten Absenders.
    //
    // Koordinaten 0 ... 1 innerhalb
    // des oberen 30-%-Dokumentbereichs.
    var visualSenderBoundingBox:
        CGRect? = nil

    @State private var pdfView =
        PDFView()

    var body: some View {

        VStack(
            spacing: 0
        ) {

            // MARK: - Toolbar

            HStack(
                spacing: 12
            ) {

                Button {

                    rotateCurrentPage(
                        by: -90
                    )

                } label: {

                    Label(
                        "Links drehen",
                        systemImage:
                            "rotate.left"
                    )
                }

                Button {

                    rotateCurrentPage(
                        by: 90
                    )

                } label: {

                    Label(
                        "Rechts drehen",
                        systemImage:
                            "rotate.right"
                    )
                }

                Spacer()
            }
            .padding(
                .horizontal,
                10
            )
            .padding(
                .vertical,
                6
            )

            Divider()

            // MARK: - PDF

            PDFKitView(
                url:
                    url,
                pdfView:
                    pdfView,
                evidence:
                    evidence,
                visualSenderBoundingBox:
                    visualSenderBoundingBox
            )
        }
    }

    // MARK: - Rotate Current Page

    private func rotateCurrentPage(
        by degrees: Int
    ) {

        guard
            let document =
                pdfView.document
        else {

            return
        }

        guard
            let page =
                pdfView.currentPage
                ?? document.page(
                    at: 0
                )
        else {

            return
        }

        var newRotation =
            page.rotation +
            degrees

        newRotation =
            newRotation % 360

        if newRotation < 0 {

            newRotation += 360
        }

        page.rotation =
            newRotation

        guard
            document.write(
                to: url
            )
        else {

            print(
                "PDF konnte nach dem Drehen nicht gespeichert werden."
            )

            return
        }

        pdfView.needsDisplay =
            true

        pdfView.layoutDocumentView()
    }
}

// MARK: - PDFKit View

private struct PDFKitView:
    NSViewRepresentable {

    let url:
        URL

    let pdfView:
        PDFView

    let evidence:
        [PDFEvidence]

    let visualSenderBoundingBox:
        CGRect?

    func makeNSView(
        context: Context
    ) -> PDFView {

        pdfView.autoScales =
            true

        pdfView.displayMode =
            .singlePageContinuous

        pdfView.displayDirection =
            .vertical

        pdfView.backgroundColor =
            .windowBackgroundColor

        pdfView.document =
            PDFDocument(
                url:
                    url
            )

        applyEvidence(
            to:
                pdfView
        )

        return pdfView
    }

    func updateNSView(
        _ pdfView: PDFView,
        context: Context
    ) {

        if pdfView.document?
            .documentURL != url {

            pdfView.document =
                PDFDocument(
                    url:
                        url
                )
        }

        applyEvidence(
            to:
                pdfView
        )
    }

    // MARK: - Evidence

    private func applyEvidence(
        to pdfView: PDFView
    ) {

        guard
            let document =
                pdfView.document
        else {

            return
        }

        removeAtlasAnnotations(
            from:
                document
        )

        // MARK: Text Evidence

        for item in evidence {

            let selections =
                findSelections(
                    for:
                        item,
                    in:
                        document
                )

            for selection in selections {

                guard
                    let page =
                        selection.pages.first
                else {

                    continue
                }

                let bounds =
                    selection.bounds(
                        for:
                            page
                    )

                guard
                    !bounds.isEmpty
                else {

                    continue
                }

                let annotation =
                    PDFAnnotation(
                        bounds:
                            bounds.insetBy(
                                dx:
                                    -2,
                                dy:
                                    -1
                            ),
                        forType:
                            .highlight,
                        withProperties:
                            nil
                    )

                annotation.userName =
                    "AtlasEvidence"

                annotation.contents =
                    label(
                        for:
                            item.kind
                    )

                annotation.color =
                    color(
                        for:
                            item.kind
                    )

                page.addAnnotation(
                    annotation
                )
            }
        }

        // MARK: Visual Sender Evidence

        if let visualSenderBoundingBox {

            addVisualSenderAnnotation(
                normalizedBoundingBox:
                    visualSenderBoundingBox,
                to:
                    document
            )
        }
    }

    // MARK: - Visual Sender Annotation

    private func addVisualSenderAnnotation(
        normalizedBoundingBox: CGRect,
        to document: PDFDocument
    ) {

        guard
            let page =
                document.page(
                    at:
                        0
                )
        else {

            return
        }

        let pageBounds =
            page.bounds(
                for:
                    .mediaBox
            )

        guard
            pageBounds.width > 0,
            pageBounds.height > 0
        else {

            return
        }

        /*
         SenderVisualRecognizer verwendet
         nur die oberen 30 % der Seite.

         Vision liefert:
         x/y/width/height = 0 ... 1
         innerhalb dieses Ausschnitts.

         Vision-Koordinaten haben den Ursprung
         unten links. PDFKit ebenfalls.

         Der Kopfbereich beginnt bei:

         70 % der Seitenhöhe.
         */

        let headerRatio:
            CGFloat = 0.30

        let headerHeight =
            pageBounds.height *
            headerRatio

        let headerBottom =
            pageBounds.minY +
            pageBounds.height -
            headerHeight

        let x =
            pageBounds.minX +
            normalizedBoundingBox.minX *
            pageBounds.width

        let y =
            headerBottom +
            normalizedBoundingBox.minY *
            headerHeight

        let width =
            normalizedBoundingBox.width *
            pageBounds.width

        let height =
            normalizedBoundingBox.height *
            headerHeight

        var bounds =
            CGRect(
                x:
                    x,
                y:
                    y,
                width:
                    width,
                height:
                    height
            )

        // Etwas Luft um den OCR-Text,
        // damit die Markierung gut sichtbar ist.
        bounds =
            bounds.insetBy(
                dx:
                    -3,
                dy:
                    -2
            )

        guard
            !bounds.isEmpty,
            !bounds.isNull,
            bounds.width > 0,
            bounds.height > 0
        else {

            return
        }

        let annotation =
            PDFAnnotation(
                bounds:
                    bounds,
                forType:
                    .square,
                withProperties:
                    nil
            )

        annotation.userName =
            "AtlasEvidence"

        annotation.contents =
            "Atlas: Absender visuell erkannt"

        // Visueller Absender bekommt Blau,
        // damit er vom Datum unterscheidbar ist.
        annotation.color =
            NSColor.systemBlue
                .withAlphaComponent(
                    0.85
                )

        let border =
            PDFBorder()

        border.lineWidth =
            2

        annotation.border =
            border

        page.addAnnotation(
            annotation
        )
    }

    // MARK: - Find Evidence

    private func findSelections(
        for item: PDFEvidence,
        in document: PDFDocument
    ) -> [PDFSelection] {

        // 1. Zuerst exakt den Text suchen,
        // den Atlas tatsächlich erkannt hat.

        let exactMatches =
            document.findString(
                item.text,
                withOptions: [
                    .caseInsensitive
                ]
            )

        if !exactMatches.isEmpty {

            return exactMatches
        }

        // 2. Fallback momentan nur für Datum.

        guard
            item.kind ==
                .date
        else {

            return []
        }

        let alternatives =
            dateAlternatives(
                from:
                    item.text
            )

        for alternative in alternatives {

            let matches =
                document.findString(
                    alternative,
                    withOptions: [
                        .caseInsensitive
                    ]
                )

            if !matches.isEmpty {

                return matches
            }
        }

        return []
    }

    // MARK: - Date Alternatives

    private func dateAlternatives(
        from text: String
    ) -> [String] {

        let trimmed =
            text.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        let formats = [
            "dd.MM.yyyy",
            "dd.MM.yy",
            "dd-MM-yyyy",
            "dd-MM-yy",
            "dd/MM/yyyy",
            "dd/MM/yy",
            "yyyy-MM-dd"
        ]

        var recognizedDate:
            Date?

        for format in formats {

            let formatter =
                DateFormatter()

            formatter.locale =
                Locale(
                    identifier:
                        "de_DE"
                )

            formatter.dateFormat =
                format

            formatter.isLenient =
                false

            if let date =
                formatter.date(
                    from:
                        trimmed
                ) {

                recognizedDate =
                    date

                break
            }
        }

        guard
            let recognizedDate
        else {

            return []
        }

        let outputFormats = [
            "dd.MM.yyyy",
            "dd.MM.yy",
            "dd-MM-yyyy",
            "dd-MM-yy",
            "dd/MM/yyyy",
            "dd/MM/yy",
            "dd MM yyyy",
            "yyyy-MM-dd"
        ]

        var results:
            [String] = []

        for format in outputFormats {

            let formatter =
                DateFormatter()

            formatter.locale =
                Locale(
                    identifier:
                        "de_DE"
                )

            formatter.dateFormat =
                format

            let value =
                formatter.string(
                    from:
                        recognizedDate
                )

            if value != trimmed &&
                !results.contains(
                    value
                ) {

                results.append(
                    value
                )
            }
        }

        return results
    }

    // MARK: - Remove Atlas Annotations

    private func removeAtlasAnnotations(
        from document: PDFDocument
    ) {

        for pageIndex in
            0..<document.pageCount {

            guard
                let page =
                    document.page(
                        at:
                            pageIndex
                    )
            else {

                continue
            }

            let atlasAnnotations =
                page.annotations.filter {

                    $0.userName ==
                        "AtlasEvidence"
                }

            for annotation in
                atlasAnnotations {

                page.removeAnnotation(
                    annotation
                )
            }
        }
    }

    // MARK: - Evidence Color

    private func color(
        for kind:
            PDFEvidence.Kind
    ) -> NSColor {

        switch kind {

        case .date:

            return NSColor.systemYellow
                .withAlphaComponent(
                    0.35
                )

        case .sender:

            return NSColor.systemBlue
                .withAlphaComponent(
                    0.30
                )

        case .recipient:

            return NSColor.systemGreen
                .withAlphaComponent(
                    0.30
                )

        case .documentType:

            return NSColor.systemOrange
                .withAlphaComponent(
                    0.30
                )
        }
    }

    // MARK: - Label

    private func label(
        for kind:
            PDFEvidence.Kind
    ) -> String {

        switch kind {

        case .date:

            return
                "Atlas: Datum"

        case .sender:

            return
                "Atlas: Absender"

        case .recipient:

            return
                "Atlas: Empfänger"

        case .documentType:

            return
                "Atlas: Dokumentenart"
        }
    }
}
