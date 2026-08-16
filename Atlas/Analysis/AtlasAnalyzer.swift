import Foundation

// MARK: - Atlas Analysis

struct AtlasAnalysis {

    var documentType:
        DocumentType

    // Exakter Text / Suchbegriff,
    // über den Atlas die Dokumentart erkannt hat.
    var documentTypeDetectedText:
        String? = nil

    var detectedDate:
        Date?

    // Exakter Text, aus dem Atlas
    // das Datum erkannt hat.
    var detectedDateText:
        String? = nil

    var sender:
        String?

    // Exakter Text / Suchbegriff, über den Atlas
    // den Absender erkannt hat.
    var senderDetectedText:
        String? = nil

    // Welchem Archivbereich / Betrieb ist das
    // Dokument als Empfänger zuzuordnen?
    var recipientArea:
        ArchiveArea?

    // Exakter Text, über den Atlas
    // den Empfänger erkannt hat.
    var recipientDetectedText:
        String? = nil

    var keywords:
        [String]

    var confidence:
        Double

    var reasons:
        [String]
}

// MARK: - Atlas Analyzer

struct AtlasAnalyzer {

    private let companyRecognizer:
        CompanyRecognizer

    private let documentClassifier:
        DocumentClassifier

    private let dateRecognizer:
        DateRecognizer

    private let keywordRecognizer:
        KeywordRecognizer

    private let recipientRecognizer:
        RecipientRecognizer

    init() {

        let knowledgeBase:
            KnowledgeBase

        do {

            knowledgeBase =
                try KnowledgeBase.load()

        } catch {

            print(
                "KnowledgeBase konnte nicht geladen werden: \(error.localizedDescription)"
            )

            knowledgeBase =
                KnowledgeBase(
                    companies: [],
                    documentTypes: [],
                    folderRules: []
                )
        }

        companyRecognizer =
            CompanyRecognizer(
                knowledgeBase:
                    knowledgeBase
            )

        documentClassifier =
            DocumentClassifier(
                knowledgeBase:
                    knowledgeBase
            )

        dateRecognizer =
            DateRecognizer()

        keywordRecognizer =
            KeywordRecognizer(
                knowledgeBase:
                    knowledgeBase
            )

        recipientRecognizer =
            RecipientRecognizer()
    }

    func analyze(
        text: String
    ) -> AtlasAnalysis {

        // MARK: - Document Type

        let documentTypeResult =
            documentClassifier.detectResult(
                in:
                    text
            )

        let documentType =
            documentTypeResult?
                .documentType
            ?? .unknown

        let documentTypeDetectedText =
            documentTypeResult?
                .matchedText

        // MARK: - Sender

        let senderResult =
            companyRecognizer.detectResult(
                in:
                    text
            )

        let sender =
            senderResult?.company

        let senderDetectedText =
            senderResult?.matchedText

        // MARK: - Recipient

        let recipientResult =
            recipientRecognizer.detectResult(
                in:
                    text
            )

        let recipientArea =
            recipientResult?.area

        let recipientDetectedText =
            recipientResult?.matchedText

        // MARK: - Date

        let dateResult =
            dateRecognizer.detectResult(
                in:
                    text
            )

        let detectedDate =
            dateResult?.date

        let detectedDateText =
            dateResult?.matchedText

        // MARK: - Keywords

        let keywords =
            keywordRecognizer.detect(
                in:
                    text
            )

        // MARK: - Reasons

        let reasons =
            buildReasons(
                documentType:
                    documentType,
                documentTypeDetectedText:
                    documentTypeDetectedText,
                sender:
                    sender,
                senderDetectedText:
                    senderDetectedText,
                recipientArea:
                    recipientArea,
                recipientDetectedText:
                    recipientDetectedText,
                detectedDate:
                    detectedDate,
                detectedDateText:
                    detectedDateText,
                keywords:
                    keywords
            )

        // MARK: - Confidence

        let confidence =
            calculateConfidence(
                documentType:
                    documentType,
                sender:
                    sender,
                recipientArea:
                    recipientArea,
                detectedDate:
                    detectedDate,
                keywords:
                    keywords
            )

        // MARK: - Result

        return AtlasAnalysis(
            documentType:
                documentType,
            documentTypeDetectedText:
                documentTypeDetectedText,
            detectedDate:
                detectedDate,
            detectedDateText:
                detectedDateText,
            sender:
                sender,
            senderDetectedText:
                senderDetectedText,
            recipientArea:
                recipientArea,
            recipientDetectedText:
                recipientDetectedText,
            keywords:
                keywords,
            confidence:
                confidence,
            reasons:
                reasons
        )
    }

    // MARK: - Reasons

    private func buildReasons(
        documentType: DocumentType,
        documentTypeDetectedText: String?,
        sender: String?,
        senderDetectedText: String?,
        recipientArea: ArchiveArea?,
        recipientDetectedText: String?,
        detectedDate: Date?,
        detectedDateText: String?,
        keywords: [String]
    ) -> [String] {

        var reasons:
            [String] = []

        // MARK: Dokumentart

        if documentType !=
            .unknown {

            if let documentTypeDetectedText,
               !documentTypeDetectedText.isEmpty {

                reasons.append(
                    "Dokumentart \(documentType.rawValue) über „\(documentTypeDetectedText)“ erkannt"
                )

            } else {

                reasons.append(
                    "Dokumentart \(documentType.rawValue) erkannt"
                )
            }
        }

        // MARK: Absender

        if let sender {

            if let senderDetectedText,
               !senderDetectedText.isEmpty {

                reasons.append(
                    "Absender \(sender) über „\(senderDetectedText)“ erkannt"
                )

            } else {

                reasons.append(
                    "Absender \(sender) erkannt"
                )
            }
        }

        // MARK: Empfänger

        if let recipientArea {

            if let recipientDetectedText,
               !recipientDetectedText.isEmpty {

                reasons.append(
                    "Empfänger \(recipientArea.rawValue) über „\(recipientDetectedText)“ erkannt"
                )

            } else {

                reasons.append(
                    "Empfänger \(recipientArea.rawValue) erkannt"
                )
            }
        }

        // MARK: Datum

        if let detectedDateText,
           !detectedDateText.isEmpty {

            reasons.append(
                "Datum \(detectedDateText) erkannt"
            )

        } else if detectedDate != nil {

            reasons.append(
                "Datum erkannt"
            )
        }

        // MARK: Keywords

        if !keywords.isEmpty {

            reasons.append(
                "\(keywords.count) relevante Schlüsselwörter gefunden"
            )
        }

        return reasons
    }

    // MARK: - Confidence

    private func calculateConfidence(
        documentType: DocumentType,
        sender: String?,
        recipientArea: ArchiveArea?,
        detectedDate: Date?,
        keywords: [String]
    ) -> Double {

        var score =
            0.0

        if documentType !=
            .unknown {

            score +=
                0.30
        }

        if sender != nil {

            score +=
                0.20
        }

        if recipientArea != nil {

            score +=
                0.30
        }

        if detectedDate != nil {

            score +=
                0.10
        }

        if !keywords.isEmpty {

            score +=
                0.10
        }

        return min(
            score,
            1.0
        )
    }
}
