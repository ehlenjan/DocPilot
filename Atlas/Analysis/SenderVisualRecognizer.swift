import Foundation
import PDFKit
import Vision
import AppKit

struct SenderVisualRecognizer {

    private let knowledgeBase:
        KnowledgeBase

    init(
        knowledgeBase: KnowledgeBase
    ) {

        self.knowledgeBase =
            knowledgeBase
    }

    // MARK: - OCR Observation

    private struct RecognizedTextItem {

        let text:
            String

        // Vision-Koordinaten:
        // 0 ... 1 innerhalb des gerenderten
        // Kopfbereichs.
        let boundingBox:
            CGRect
    }

    // MARK: - Company Match

    private struct CompanyMatch {

        let company:
            String

        let matchedText:
            String

        let boundingBox:
            CGRect

        let score:
            Int
    }

    // MARK: - Combined Analysis

    struct Result {

        let detectedCompany:
            String?

        let recognizedText:
            String

        let signature:
            VisualFeatureSignature?

        // Exakter OCR-Text, über den die
        // Firma visuell erkannt wurde.
        let detectedCompanyText:
            String?

        // Vision-Koordinaten innerhalb
        // des oberen 30-%-Ausschnitts.
        let detectedCompanyBoundingBox:
            CGRect?
    }

    func analyze(
        pdfURL: URL
    ) async -> Result {

        guard
            let headerImage =
                firstPageHeaderImage(
                    from:
                        pdfURL
                )
        else {

            return Result(
                detectedCompany:
                    nil,
                recognizedText:
                    "",
                signature:
                    nil,
                detectedCompanyText:
                    nil,
                detectedCompanyBoundingBox:
                    nil
            )
        }

        async let recognizedTextItemsTask =
            recognizeTextItems(
                in:
                    headerImage
            )

        async let signatureTask =
            generateSignature(
                from:
                    headerImage
            )

        do {

            let recognizedTextItems =
                try await
                    recognizedTextItemsTask

            let signature =
                try await
                    signatureTask

            let recognizedText =
                recognizedTextItems
                    .map(
                        \.text
                    )
                    .joined(
                        separator:
                            "\n"
                    )

            let companyMatch =
                bestCompany(
                    in:
                        recognizedTextItems
                )

            return Result(
                detectedCompany:
                    companyMatch?
                        .company,
                recognizedText:
                    recognizedText,
                signature:
                    signature,
                detectedCompanyText:
                    companyMatch?
                        .matchedText,
                detectedCompanyBoundingBox:
                    companyMatch?
                        .boundingBox
            )

        } catch {

            print(
                "Visuelle Absenderanalyse fehlgeschlagen: \(error.localizedDescription)"
            )

            return Result(
                detectedCompany:
                    nil,
                recognizedText:
                    "",
                signature:
                    nil,
                detectedCompanyText:
                    nil,
                detectedCompanyBoundingBox:
                    nil
            )
        }
    }

    // MARK: - Simple Sender Detection

    func detect(
        in pdfURL: URL
    ) async -> String? {

        let result =
            await analyze(
                pdfURL:
                    pdfURL
            )

        return result
            .detectedCompany
    }

    // MARK: - Signature

    func signature(
        for pdfURL: URL
    ) async -> VisualFeatureSignature? {

        guard
            let headerImage =
                firstPageHeaderImage(
                    from:
                        pdfURL
                )
        else {

            return nil
        }

        do {

            return try await
                generateSignature(
                    from:
                        headerImage
                )

        } catch {

            print(
                "Visuelle Signatur konnte nicht erzeugt werden: \(error.localizedDescription)"
            )

            return nil
        }
    }

    // MARK: - First Page Header

    private func firstPageHeaderImage(
        from pdfURL: URL
    ) -> CGImage? {

        guard
            let document =
                PDFDocument(
                    url:
                        pdfURL
                ),
            let firstPage =
                document.page(
                    at:
                        0
                )
        else {

            return nil
        }

        return renderFirstPageHeader(
            page:
                firstPage
        )
    }

    // MARK: - Render Header

    private func renderFirstPageHeader(
        page: PDFPage
    ) -> CGImage? {

        let pageBounds =
            page.bounds(
                for:
                    .mediaBox
            )

        guard
            pageBounds.width > 0,
            pageBounds.height > 0
        else {

            return nil
        }

        let targetWidth:
            CGFloat = 1800

        let scale =
            targetWidth /
            pageBounds.width

        let fullWidth =
            pageBounds.width *
            scale

        let fullHeight =
            pageBounds.height *
            scale

        guard
            let colorSpace =
                CGColorSpace(
                    name:
                        CGColorSpace.sRGB
                )
        else {

            return nil
        }

        guard
            let context =
                CGContext(
                    data:
                        nil,
                    width:
                        Int(
                            fullWidth
                        ),
                    height:
                        Int(
                            fullHeight
                        ),
                    bitsPerComponent:
                        8,
                    bytesPerRow:
                        0,
                    space:
                        colorSpace,
                    bitmapInfo:
                        CGImageAlphaInfo
                            .premultipliedLast
                            .rawValue
                )
        else {

            return nil
        }

        context.setFillColor(
            NSColor.white.cgColor
        )

        context.fill(
            CGRect(
                x:
                    0,
                y:
                    0,
                width:
                    fullWidth,
                height:
                    fullHeight
            )
        )

        context.saveGState()

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

        context.restoreGState()

        guard
            let fullImage =
                context.makeImage()
        else {

            return nil
        }

        let headerRatio =
            0.30

        let headerHeight =
            max(
                1,
                Int(
                    Double(
                        fullImage.height
                    ) *
                    headerRatio
                )
            )

        let cropRect =
            CGRect(
                x:
                    0,
                y:
                    fullImage.height -
                    headerHeight,
                width:
                    fullImage.width,
                height:
                    headerHeight
            )

        return fullImage.cropping(
            to:
                cropRect
        )
    }

    // MARK: - Vision OCR With Positions

    private func recognizeTextItems(
        in image: CGImage
    ) async throws -> [RecognizedTextItem] {

        try await
            withCheckedThrowingContinuation {
                continuation in

                let request =
                    VNRecognizeTextRequest {
                        request,
                        error in

                        if let error {

                            continuation
                                .resume(
                                    throwing:
                                        error
                                )

                            return
                        }

                        let observations =
                            request.results
                            as? [
                                VNRecognizedTextObservation
                            ]
                            ?? []

                        let items =
                            observations
                                .compactMap {
                                    observation
                                    -> RecognizedTextItem? in

                                    guard
                                        let candidate =
                                            observation
                                                .topCandidates(
                                                    1
                                                )
                                                .first
                                    else {

                                        return nil
                                    }

                                    let text =
                                        candidate
                                            .string
                                            .trimmingCharacters(
                                                in:
                                                    .whitespacesAndNewlines
                                            )

                                    guard
                                        !text.isEmpty
                                    else {

                                        return nil
                                    }

                                    return RecognizedTextItem(
                                        text:
                                            text,
                                        boundingBox:
                                            observation
                                                .boundingBox
                                    )
                                }

                        continuation
                            .resume(
                                returning:
                                    items
                            )
                    }

                request.recognitionLevel =
                    .accurate

                request.recognitionLanguages = [
                    "de-DE",
                    "en-US"
                ]

                request.usesLanguageCorrection =
                    true

                let handler =
                    VNImageRequestHandler(
                        cgImage:
                            image,
                        options:
                            [:]
                    )

                do {

                    try handler.perform(
                        [
                            request
                        ]
                    )

                } catch {

                    continuation
                        .resume(
                            throwing:
                                error
                        )
                }
            }
    }

    // MARK: - Feature Signature

    private func generateSignature(
        from image: CGImage
    ) async throws
        -> VisualFeatureSignature {

        try await
            withCheckedThrowingContinuation {
                continuation in

                let request =
                    VNGenerateImageFeaturePrintRequest {
                        request,
                        error in

                        if let error {

                            continuation
                                .resume(
                                    throwing:
                                        error
                                )

                            return
                        }

                        guard
                            let observation =
                                request.results?
                                    .first
                                as?
                                    VNFeaturePrintObservation
                        else {

                            continuation
                                .resume(
                                    throwing:
                                        SenderVisualRecognizerError
                                            .featurePrintMissing
                                )

                            return
                        }

                        let signature =
                            VisualFeatureSignature(
                                observation:
                                    observation
                            )

                        continuation
                            .resume(
                                returning:
                                    signature
                            )
                    }

                request
                    .imageCropAndScaleOption =
                        .scaleFit

                let handler =
                    VNImageRequestHandler(
                        cgImage:
                            image,
                        options:
                            [:]
                    )

                do {

                    try handler.perform(
                        [
                            request
                        ]
                    )

                } catch {

                    continuation
                        .resume(
                            throwing:
                                error
                        )
                }
            }
    }

    // MARK: - Company Matching

    private func bestCompany(
        in items: [RecognizedTextItem]
    ) -> CompanyMatch? {

        var bestMatch:
            CompanyMatch?

        for company in
            knowledgeBase.companies {

            for keyword in
                company.keywords {

                let normalizedKeyword =
                    normalize(
                        keyword
                    )

                guard
                    !normalizedKeyword.isEmpty
                else {

                    continue
                }

                for item in items {

                    let normalizedItem =
                        normalize(
                            item.text
                        )

                    guard
                        normalizedItem.contains(
                            normalizedKeyword
                        )
                    else {

                        continue
                    }

                    var score =
                        50

                    if normalizedKeyword.count >= 10 {

                        score +=
                            15

                    } else if
                        normalizedKeyword.count >= 6 {

                        score +=
                            8
                    }

                    let candidate =
                        CompanyMatch(
                            company:
                                company.name,
                            matchedText:
                                item.text,
                            boundingBox:
                                item.boundingBox,
                            score:
                                score
                        )

                    if bestMatch == nil ||
                        candidate.score >
                            bestMatch!.score {

                        bestMatch =
                            candidate
                    }
                }
            }
        }

        guard
            let bestMatch,
            bestMatch.score >= 50
        else {

            return nil
        }

        return bestMatch
    }

    // MARK: - Debug Similarity

    func debugSimilarity(
        between firstPDF: URL,
        and secondPDF: URL
    ) async {

        guard
            let firstSignature =
                await signature(
                    for:
                        firstPDF
                )
        else {

            print(
                "❌ Keine visuelle Signatur für:",
                firstPDF.lastPathComponent
            )

            return
        }

        guard
            let secondSignature =
                await signature(
                    for:
                        secondPDF
                )
        else {

            print(
                "❌ Keine visuelle Signatur für:",
                secondPDF.lastPathComponent
            )

            return
        }

        guard
            let similarity =
                firstSignature
                    .similarity(
                        to:
                            secondSignature
                    )
        else {

            print(
                "❌ Visuelle Signaturen konnten nicht verglichen werden."
            )

            return
        }

        print(
            """

            🧠 Atlas Visual Test
            --------------------
            Datei 1: \(firstPDF.lastPathComponent)
            Datei 2: \(secondPDF.lastPathComponent)
            Similarity: \(String(format: "%.4f", similarity))
            Prozent: \(String(format: "%.1f", similarity * 100)) %
            --------------------

            """
        )
    }

    // MARK: - Normalize

    private func normalize(
        _ value: String
    ) -> String {

        value
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive
                ],
                locale:
                    Locale(
                        identifier:
                            "de_DE"
                    )
            )
            .lowercased()
    }
}

// MARK: - Error

private enum SenderVisualRecognizerError:
    LocalizedError {

    case featurePrintMissing

    var errorDescription:
        String? {

        switch self {

        case .featurePrintMissing:

            return
                "Vision konnte keine visuelle Signatur für den Dokumentkopf erzeugen."
        }
    }
}
