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

    // MARK: - Combined Analysis

    struct Result {

        let detectedCompany:
            String?

        let recognizedText:
            String

        let signature:
            VisualFeatureSignature?
    }

    func analyze(
        pdfURL: URL
    ) async -> Result {

        guard let headerImage =
            firstPageHeaderImage(
                from: pdfURL
            )
        else {

            return Result(
                detectedCompany:
                    nil,
                recognizedText:
                    "",
                signature:
                    nil
            )
        }

        async let recognizedTextTask =
            recognizeText(
                in: headerImage
            )

        async let signatureTask =
            generateSignature(
                from: headerImage
            )

        do {

            let recognizedText =
                try await recognizedTextTask

            let signature =
                try await signatureTask

            let company =
                bestCompany(
                    in: recognizedText
                )

            return Result(
                detectedCompany:
                    company,
                recognizedText:
                    recognizedText,
                signature:
                    signature
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

        return result.detectedCompany
    }

    // MARK: - Signature

    func signature(
        for pdfURL: URL
    ) async -> VisualFeatureSignature? {

        guard let headerImage =
            firstPageHeaderImage(
                from: pdfURL
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
                    at: 0
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

        // Hohe Auflösung für OCR und
        // visuelle Feature-Erkennung.
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
                        Int(fullWidth),
                    height:
                        Int(fullHeight),
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
                x: 0,
                y: 0,
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

        guard let fullImage =
            context.makeImage()
        else {
            return nil
        }

        // Wir verwenden bewusst nur den oberen
        // Dokumentbereich. Dadurch beeinflussen
        // wechselnde Positionen, Artikelzeilen,
        // Beträge usw. die visuelle Signatur
        // wesentlich weniger.
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

    // MARK: - Vision OCR

    private func recognizeText(
        in image: CGImage
    ) async throws -> String {

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

                        let strings =
                            observations
                                .compactMap {
                                    observation in

                                    observation
                                        .topCandidates(
                                            1
                                        )
                                        .first?
                                        .string
                                }

                        continuation
                            .resume(
                                returning:
                                    strings.joined(
                                        separator:
                                            "\n"
                                    )
                            )
                    }

                request.recognitionLevel =
                    .accurate

                request.recognitionLanguages =
                    [
                        "de-DE",
                        "en-US"
                    ]

                request.usesLanguageCorrection =
                    true

                let handler =
                    VNImageRequestHandler(
                        cgImage:
                            image,
                        options: [:]
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
                        options: [:]
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
        in recognizedText: String
    ) -> String? {

        let normalizedText =
            normalize(
                recognizedText
            )

        guard
            !normalizedText.isEmpty
        else {
            return nil
        }

        var bestCompany:
            String?

        var bestScore =
            0

        for company in
            knowledgeBase.companies {

            var score =
                0

            for keyword in
                company.keywords {

                let normalizedKeyword =
                    normalize(
                        keyword
                    )

                guard
                    !normalizedKeyword
                        .isEmpty
                else {
                    continue
                }

                if normalizedText.contains(
                    normalizedKeyword
                ) {

                    // Ein OCR-Treffer im Kopfbereich
                    // ist wesentlich stärker als ein
                    // zufälliges Vorkommen im Volltext.
                    score += 50

                    if normalizedKeyword.count >= 10 {

                        score += 15

                    } else if
                        normalizedKeyword.count >= 6 {

                        score += 8
                    }
                }
            }

            if score >
                bestScore {

                bestScore =
                    score

                bestCompany =
                    company.name
            }
        }

        guard
            bestScore >= 50
        else {
            return nil
        }

        return bestCompany
    }

    // MARK: - Debug Similarity

    func debugSimilarity(
        between firstPDF: URL,
        and secondPDF: URL
    ) async {

        guard
            let firstSignature =
                await signature(
                    for: firstPDF
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
                    for: secondPDF
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
                firstSignature.similarity(
                    to: secondSignature
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
