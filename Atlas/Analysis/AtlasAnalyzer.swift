import Foundation

struct AtlasAnalysis {
    var documentType: DocumentType
    var detectedDate: Date?
    var sender: String?
    var keywords: [String]
    var confidence: Double
    var reasons: [String]
}

struct AtlasAnalyzer {

    private let companyRecognizer: CompanyRecognizer
    private let documentClassifier: DocumentClassifier
    private let dateRecognizer: DateRecognizer
    private let keywordRecognizer: KeywordRecognizer

    init() {
        let knowledgeBase: KnowledgeBase

        do {
            knowledgeBase = try KnowledgeBase.load()
        } catch {
            print(
                "KnowledgeBase konnte nicht geladen werden: \(error.localizedDescription)"
            )

            knowledgeBase = KnowledgeBase(
                companies: [],
                documentTypes: [],
                folderRules: []
            )
        }

        companyRecognizer = CompanyRecognizer(
            knowledgeBase: knowledgeBase
        )

        documentClassifier = DocumentClassifier(
            knowledgeBase: knowledgeBase
        )

        dateRecognizer = DateRecognizer()

        keywordRecognizer = KeywordRecognizer(
            knowledgeBase: knowledgeBase
        )
    }

    func analyze(text: String) -> AtlasAnalysis {
        let documentType = documentClassifier.detect(
            in: text
        )

        let sender = companyRecognizer.detect(
            in: text
        )

        let detectedDate = dateRecognizer.detect(
            in: text
        )

        let keywords = keywordRecognizer.detect(
            in: text
        )

        let reasons = buildReasons(
            documentType: documentType,
            sender: sender,
            detectedDate: detectedDate,
            keywords: keywords
        )

        let confidence = calculateConfidence(
            documentType: documentType,
            sender: sender,
            detectedDate: detectedDate,
            keywords: keywords
        )

        return AtlasAnalysis(
            documentType: documentType,
            detectedDate: detectedDate,
            sender: sender,
            keywords: keywords,
            confidence: confidence,
            reasons: reasons
        )
    }

    private func buildReasons(
        documentType: DocumentType,
        sender: String?,
        detectedDate: Date?,
        keywords: [String]
    ) -> [String] {
        var reasons: [String] = []

        if documentType != .unknown {
            reasons.append(
                "Dokumentart \(documentType.rawValue) erkannt"
            )
        }

        if let sender {
            reasons.append(
                "Absender \(sender) erkannt"
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

    private func calculateConfidence(
        documentType: DocumentType,
        sender: String?,
        detectedDate: Date?,
        keywords: [String]
    ) -> Double {
        var score = 0.0

        if documentType != .unknown {
            score += 0.40
        }

        if sender != nil {
            score += 0.25
        }

        if detectedDate != nil {
            score += 0.20
        }

        if !keywords.isEmpty {
            score += 0.15
        }

        return min(score, 1.0)
    }
}
