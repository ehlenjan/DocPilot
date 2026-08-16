import Foundation
import Vision
import PDFKit
import AppKit

final class OCRService {

    // MARK: - Field Mode

    enum FieldMode {
        case normal
        case date
    }

    private let fieldImageProcessor =
        FieldImageProcessor()

    // MARK: - Complete Document

    func recognizeText(
        from document: PDFDocument
    ) async throws -> String {

        var completeText = ""

        for pageIndex in 0..<document.pageCount {

            guard
                let page =
                    document.page(
                        at: pageIndex
                    )
            else {
                continue
            }

            guard
                let image =
                    render(
                        page: page
                    )
            else {
                continue
            }

            let pageText =
                try await recognizeSingleImage(
                    image,
                    mode: .normal
                )

            completeText +=
                pageText

            completeText +=
                "\n\n"
        }

        return completeText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }

    // MARK: - Page Region

    func recognizeText(
        from page: PDFPage,
        normalizedRegion: CGRect,
        mode: FieldMode = .normal
    ) async throws -> String {

        guard
            let completeImage =
                render(
                    page: page
                )
        else {
            return ""
        }

        guard
            let croppedImage =
                crop(
                    image:
                        completeImage,
                    normalizedRegion:
                        normalizedRegion
                )
        else {
            return ""
        }

        switch mode {

        case .normal:

            return try await
                recognizeSingleImage(
                    croppedImage,
                    mode: .normal
                )

        case .date:

            return try await
                recognizeDateField(
                    croppedImage
                )
        }
    }

    // MARK: - Date Field

    private func recognizeDateField(
        _ image: NSImage
    ) async throws -> String {

        let variants =
            fieldImageProcessor
                .variants(
                    from: image
                )

        var results:
            [String] = []

        for (
            index,
            variant
        ) in variants.enumerated() {

            let text =
                try await recognizeSingleImage(
                    variant,
                    mode: .date
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

            guard
                !text.isEmpty
            else {
                continue
            }

            results.append(
                """
                [Variante \(index + 1)]
                \(text)
                """
            )
        }

        return results
            .joined(
                separator:
                    "\n\n"
            )
    }

    // MARK: - Vision

    private func recognizeSingleImage(
        _ image: NSImage,
        mode: FieldMode
    ) async throws -> String {

        guard
            let cgImage =
                image.cgImage(
                    forProposedRect:
                        nil,
                    context:
                        nil,
                    hints:
                        nil
                )
        else {
            return ""
        }

        return try await
            withCheckedThrowingContinuation {
                continuation in

                let request =
                    VNRecognizeTextRequest {
                        request,
                        error in

                        if let error {

                            continuation.resume(
                                throwing:
                                    error
                            )

                            return
                        }

                        guard
                            let observations =
                                request.results
                                as? [
                                    VNRecognizedTextObservation
                                ]
                        else {

                            continuation.resume(
                                returning:
                                    ""
                            )

                            return
                        }

                        let text:
                            String

                        switch mode {

                        case .normal:

                            text =
                                observations
                                    .compactMap {
                                        $0
                                            .topCandidates(
                                                1
                                            )
                                            .first?
                                            .string
                                    }
                                    .joined(
                                        separator:
                                            "\n"
                                    )

                        case .date:

                            text =
                                self.dateCandidateText(
                                    from:
                                        observations
                                )
                        }

                        continuation.resume(
                            returning:
                                text
                        )
                    }

                request.recognitionLevel =
                    .accurate

                switch mode {

                case .normal:

                    request.usesLanguageCorrection =
                        true

                    request.recognitionLanguages = [
                        "de-DE",
                        "en-US"
                    ]

                case .date:

                    request.usesLanguageCorrection =
                        false

                    request.recognitionLanguages = [
                        "de-DE"
                    ]
                }

                let handler =
                    VNImageRequestHandler(
                        cgImage:
                            cgImage
                    )

                do {

                    try handler.perform(
                        [
                            request
                        ]
                    )

                } catch {

                    continuation.resume(
                        throwing:
                            error
                    )
                }
            }
    }

    // MARK: - Date Candidates

    private func dateCandidateText(
        from observations:
            [VNRecognizedTextObservation]
    ) -> String {

        var lines:
            [String] = []

        for observation in observations {

            let candidates =
                observation
                    .topCandidates(
                        5
                    )

            guard
                !candidates.isEmpty
            else {
                continue
            }

            let candidateTexts =
                candidates
                    .map {
                        $0.string
                    }

            lines.append(
                candidateTexts
                    .joined(
                        separator:
                            " | "
                    )
            )
        }

        return lines
            .joined(
                separator:
                    "\n"
            )
    }

    // MARK: - PDF Rendering

    private func render(
        page: PDFPage
    ) -> NSImage? {

        let bounds =
            page.bounds(
                for:
                    .mediaBox
            )

        let scale:
            CGFloat = 3.0

        let size =
            CGSize(
                width:
                    bounds.width
                    *
                    scale,
                height:
                    bounds.height
                    *
                    scale
            )

        let image =
            NSImage(
                size:
                    size
            )

        image.lockFocus()

        NSColor.white
            .setFill()

        NSBezierPath(
            rect:
                CGRect(
                    origin:
                        .zero,
                    size:
                        size
                )
        )
        .fill()

        guard
            let context =
                NSGraphicsContext
                    .current?
                    .cgContext
        else {

            image.unlockFocus()

            return nil
        }

        context.scaleBy(
            x:
                scale,
            y:
                scale
        )

        page.draw(
            with:
                .mediaBox,
            to:
                context
        )

        image.unlockFocus()

        return image
    }

    // MARK: - Crop

    private func crop(
        image: NSImage,
        normalizedRegion: CGRect
    ) -> NSImage? {

        guard
            let cgImage =
                image.cgImage(
                    forProposedRect:
                        nil,
                    context:
                        nil,
                    hints:
                        nil
                )
        else {
            return nil
        }

        let imageWidth =
            CGFloat(
                cgImage.width
            )

        let imageHeight =
            CGFloat(
                cgImage.height
            )

        let minX =
            max(
                0,
                min(
                    normalizedRegion.minX,
                    1
                )
            )

        let minY =
            max(
                0,
                min(
                    normalizedRegion.minY,
                    1
                )
            )

        let maxX =
            max(
                0,
                min(
                    normalizedRegion.maxX,
                    1
                )
            )

        let maxY =
            max(
                0,
                min(
                    normalizedRegion.maxY,
                    1
                )
            )

        let normalized =
            CGRect(
                x:
                    minX,
                y:
                    minY,
                width:
                    max(
                        0,
                        maxX - minX
                    ),
                height:
                    max(
                        0,
                        maxY - minY
                    )
            )

        let cropRect =
            CGRect(
                x:
                    normalized.minX
                    *
                    imageWidth,

                y:
                    (
                        1
                        -
                        normalized.maxY
                    )
                    *
                    imageHeight,

                width:
                    normalized.width
                    *
                    imageWidth,

                height:
                    normalized.height
                    *
                    imageHeight
            )
            .integral

        guard
            cropRect.width > 0,
            cropRect.height > 0,
            let croppedCGImage =
                cgImage.cropping(
                    to:
                        cropRect
                )
        else {
            return nil
        }

        return NSImage(
            cgImage:
                croppedCGImage,
            size:
                NSSize(
                    width:
                        cropRect.width,
                    height:
                        cropRect.height
                )
        )
    }
}
