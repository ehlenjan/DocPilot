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

    private let knowledgeBase: KnowledgeBase

    init() {
        do {
            knowledgeBase = try KnowledgeBase.load()
        } catch {
            print("KnowledgeBase konnte nicht geladen werden: \(error.localizedDescription)")

            knowledgeBase = KnowledgeBase(
                companies: [],
                documentTypes: []
            )
        }
    }

    func analyze(text: String) -> AtlasAnalysis {
        let normalizedText = text.lowercased()

        let documentType = detectDocumentType(
            in: normalizedText
        )

        let sender = detectSender(
            in: normalizedText
        )

        let detectedDate = detectDate(
            in: text
        )

        let keywords = detectKeywords(
            in: normalizedText
        )

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

    private func detectDocumentType(
        in text: String
    ) -> DocumentType {
        for rule in knowledgeBase.documentTypes {
            let didMatch = rule.keywords.contains { keyword in
                text.contains(keyword.lowercased())
            }

            if didMatch {
                return rule.documentType
            }
        }

        return .unknown
    }

    private func detectSender(
        in text: String
    ) -> String? {
        for company in knowledgeBase.companies {
            let didMatch = company.keywords.contains { keyword in
                text.contains(keyword.lowercased())
            }

            if didMatch {
                return company.name
            }
        }

        return nil
    }

    private func detectDate(
        in text: String
    ) -> Date? {
        let patterns = [
            #"\b\d{2}\.\d{2}\.\d{4}\b"#,
            #"\b\d{2}\.\d{2}\.\d{2}\b"#,
            #"\b\d{4}-\d{2}-\d{2}\b"#
        ]

        for pattern in patterns {
            guard let range = text.range(
                of: pattern,
                options: .regularExpression
            ) else {
                continue
            }

            let dateString = String(text[range])

            let formats = [
                "dd.MM.yyyy",
                "dd.MM.yy",
                "yyyy-MM-dd"
            ]

            for format in formats {
                let formatter = DateFormatter()
                formatter.locale = Locale(
                    identifier: "de_DE"
                )
                formatter.dateFormat = format

                if let date = formatter.date(
                    from: dateString
                ) {
                    return date
                }
            }
        }

        return nil
    }

    private func detectKeywords(
        in text: String
    ) -> [String] {
        var matches: [String] = []

        for documentType in knowledgeBase.documentTypes {
            for keyword in documentType.keywords {
                if text.contains(keyword.lowercased()) {
                    matches.append(keyword)
                }
            }
        }

        return Array(
            Set(matches)
        )
        .sorted()
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
