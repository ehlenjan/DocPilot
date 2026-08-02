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
                return "In diesem PDF wurde kein eingebetteter Text gefunden."
            }
        }
    }

    func extractText(from url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw ExtractionError.documentCouldNotBeOpened
        }

        let text = document.string?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !text.isEmpty else {
            throw ExtractionError.noTextFound
        }

        return text
    }
}
