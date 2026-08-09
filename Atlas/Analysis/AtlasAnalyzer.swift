import Foundation

struct AtlasAnalysis {
    var documentType: DocumentType
    var detectedDate: Date?
    var sender: String?

    // Neu:
    // Welchem Archivbereich / Betrieb ist das
    // Dokument als Empfänger zuzuordnen?
    var recipientArea: ArchiveArea?

    var keywords: [String]
    var confidence: Double
    var reasons: [String]
}

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

        let documentType =
            documentClassifier.detect(
                in: text
            )

        let sender =
            companyRecognizer.detect(
                in: text
            )

        let recipientArea =
            recipientRecognizer.detect(
                in: text
            )

        let detectedDate =
            dateRecognizer.detect(
                in: text
            )

        let keywords =
            keywordRecognizer.detect(
                in: text
            )

        let reasons =
            buildReasons(
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

        return AtlasAnalysis(
            documentType:
                documentType,
            detectedDate:
                detectedDate,
            sender:
                sender,
            recipientArea:
                recipientArea,
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
        sender: String?,
        recipientArea: ArchiveArea?,
        detectedDate: Date?,
        keywords: [String]
    ) -> [String] {

        var reasons:
            [String] = []

        if documentType !=
            .unknown {

            reasons.append(
                "Dokumentart \(documentType.rawValue) erkannt"
            )
        }

        if let sender {

            reasons.append(
                "Absender \(sender) erkannt"
            )
        }

        if let recipientArea {

            reasons.append(
                "Empfänger \(recipientArea.rawValue) erkannt"
            )
        }

        if detectedDate != nil {

            reasons.append(
                "Datum erkannt"
            )
        }

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

        // Neu:
        // Empfänger/Betrieb ist für deinen
        // Archiv-Workflow ein starkes Merkmal.
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
