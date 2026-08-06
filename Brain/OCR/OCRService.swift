import Foundation
import Vision
import PDFKit
import AppKit

final class OCRService {

    func recognizeText(
        from document: PDFDocument
    ) async throws -> String {

        var completeText = ""

        for pageIndex in 0..<document.pageCount {

            guard let page = document.page(at: pageIndex) else {
                continue
            }

            guard let image = render(page: page) else {
                continue
            }

            let pageText = try await recognizeText(
                in: image
            )

            completeText += pageText
            completeText += "\n\n"
        }

        return completeText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }

    // MARK: - Vision

    private func recognizeText(
        in image: NSImage
    ) async throws -> String {

        guard
            let cgImage = image.cgImage(
                forProposedRect: nil,
                context: nil,
                hints: nil
            )
        else {
            return ""
        }

        return try await withCheckedThrowingContinuation {
            continuation in

            let request = VNRecognizeTextRequest {

                request,
                error in

                if let error {
                    continuation.resume(
                        throwing: error
                    )
                    return
                }

                guard
                    let observations =
                        request.results
                        as? [VNRecognizedTextObservation]
                else {

                    continuation.resume(
                        returning: ""
                    )

                    return
                }

                let text = observations
                    .compactMap {
                        $0.topCandidates(1).first?.string
                    }
                    .joined(
                        separator: "\n"
                    )

                continuation.resume(
                    returning: text
                )
            }

            request.recognitionLevel = .accurate

            request.usesLanguageCorrection = true

            request.recognitionLanguages = [
                "de-DE",
                "en-US"
            ]

            let handler = VNImageRequestHandler(
                cgImage: cgImage
            )

            do {

                try handler.perform(
                    [request]
                )

            } catch {

                continuation.resume(
                    throwing: error
                )

            }

        }

    }

    // MARK: - PDF Rendering

    private func render(
        page: PDFPage
    ) -> NSImage? {

        let bounds = page.bounds(
            for: .mediaBox
        )

        let scale: CGFloat = 2.5

        let size = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )

        let image = NSImage(
            size: size
        )

        image.lockFocus()

        NSColor.white.setFill()

        NSBezierPath(
            rect: CGRect(
                origin: .zero,
                size: size
            )
        )
        .fill()

        guard
            let context =
                NSGraphicsContext.current?
                .cgContext
        else {

            image.unlockFocus()

            return nil

        }

        context.scaleBy(
            x: scale,
            y: scale
        )

        page.draw(
            with: .mediaBox,
            to: context
        )

        image.unlockFocus()

        return image

    }

}
