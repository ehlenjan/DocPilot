import Foundation
import PDFKit

struct PDFTextExtractionService {

    enum ExtractionError: LocalizedError {
        case documentCouldNotBeOpened
        case noTextFound

        var errorDescription: String? {
            switch self {
            case .documentCouldNotBeOpened:
                return "Das PDF konnte nicht geöffnet werden."

            case .noTextFound:
                return "In diesem PDF wurde kein Text erkannt."
            }
        }
    }

    private let ocrService = OCRService()

    func extractText(from url: URL) async throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw ExtractionError.documentCouldNotBeOpened
        }

        let embeddedText = document.string?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? ""

        if embeddedText.count >= 100 {
            return embeddedText
        }

        let ocrText = try await ocrService.recognizeText(
            from: document
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if ocrText.count > embeddedText.count {
            return ocrText
        }

        if !embeddedText.isEmpty {
            return embeddedText
        }

        guard !ocrText.isEmpty else {
            throw ExtractionError.noTextFound
        }

        return ocrText
    }
}
