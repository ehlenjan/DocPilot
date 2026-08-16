import Foundation
import PDFKit

struct LayoutFieldRecognizer {

    private let ocrService =
        OCRService()

    // MARK: - Field

    enum Field {

        case date
        case recipient
    }

    // MARK: - Recognize

    func recognize(
        field: Field,
        in url: URL,
        profile: DocumentLayoutProfile
    ) async -> String? {

        guard
            let document =
                PDFDocument(
                    url: url
                ),
            let firstPage =
                document.page(
                    at: 0
                )
        else {

            return nil
        }

        guard
            let region =
                region(
                    for:
                        field,
                    profile:
                        profile
                )
        else {

            return nil
        }

        do {

            let mode:
                OCRService.FieldMode

            switch field {

            case .date:
                mode = .date

            case .recipient:
                mode = .normal
            }

            let text =
                try await ocrService
                    .recognizeText(
                        from:
                            firstPage,
                        normalizedRegion:
                            region,
                        mode:
                            mode
                    )
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            guard
                !text.isEmpty
            else {

                return nil
            }

            return text

        } catch {

            print(
                "Layout-OCR fehlgeschlagen: \(error.localizedDescription)"
            )

            return nil
        }
    }

    // MARK: - Matching Profile

    func matchingProfiles(
        company: String,
        documentType: DocumentType
    ) -> [DocumentLayoutProfile] {

        DocumentLayoutProfile
            .matching(
                company:
                    company,
                documentType:
                    documentType
            )
    }

    // MARK: - Region

    private func region(
        for field: Field,
        profile: DocumentLayoutProfile
    ) -> CGRect? {

        switch field {

        case .date:

            return profile
                .dateRegion

        case .recipient:

            return profile
                .archiveIdentityRegion
        }
    }
}
