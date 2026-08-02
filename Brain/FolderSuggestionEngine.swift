import Foundation

struct FolderSuggestion {
    let ruleName: String
    let area: ArchiveArea
    let folder: String
    let confidence: Double
    let reasons: [String]

    var displayPath: String {
        "\(area.rawValue) → \(folder)"
    }
}

struct FolderSuggestionEngine {

    private let knowledgeBase: KnowledgeBase

    init(knowledgeBase: KnowledgeBase) {
        self.knowledgeBase = knowledgeBase
    }

    func suggestFolder(
        for analysis: AtlasAnalysis,
        text: String
    ) -> FolderSuggestion? {
        let candidates = knowledgeBase.folderRules.compactMap { rule in
            evaluate(
                rule: rule,
                analysis: analysis,
                text: text
            )
        }

        return candidates.max {
            $0.confidence < $1.confidence
        }
    }

    private func evaluate(
        rule: FolderRule,
        analysis: AtlasAnalysis,
        text: String
    ) -> FolderSuggestion? {
        guard let area = rule.archiveArea else {
            return nil
        }

        var score = 0.0
        var reasons: [String] = []

        if rule.matchesDocumentType(analysis.documentType) {
            score += 0.40
            reasons.append(
                "Dokumentart \(analysis.documentType.rawValue) passt"
            )
        }

        if rule.matchesCompany(analysis.sender) {
            score += 0.35

            if let sender = analysis.sender {
                reasons.append(
                    "Absender \(sender) passt"
                )
            }
        }

        let matchingKeywords = rule.matchingKeywords(
            in: text
        )

        if !matchingKeywords.isEmpty {
            let keywordScore = min(
                Double(matchingKeywords.count) * 0.10,
                0.25
            )

            score += keywordScore

            reasons.append(
                "Schlüsselwörter: \(matchingKeywords.joined(separator: ", "))"
            )
        }

        guard score > 0 else {
            return nil
        }

        return FolderSuggestion(
            ruleName: rule.name,
            area: area,
            folder: rule.folder,
            confidence: min(score, 1.0),
            reasons: reasons
        )
    }
}
