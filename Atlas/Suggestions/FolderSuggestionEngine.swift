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
    private let learningManager: LearningManager
    private let learningMatcher: LearningMatcher

    init(
        knowledgeBase: KnowledgeBase,
        learningManager: LearningManager = LearningManager(),
        learningMatcher: LearningMatcher = LearningMatcher()
    ) {
        self.knowledgeBase = knowledgeBase
        self.learningManager = learningManager
        self.learningMatcher = learningMatcher
    }

    func suggestFolder(
        for analysis: AtlasAnalysis,
        text: String
    ) -> FolderSuggestion? {
        let ruleSuggestion = bestRuleSuggestion(
            for: analysis,
            text: text
        )

        let learningMatch = learningMatcher.bestMatch(
            for: analysis,
            entries: learningManager.entries
        )

        return combine(
            ruleSuggestion: ruleSuggestion,
            learningMatch: learningMatch
        )
    }

    private func bestRuleSuggestion(
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

    private func combine(
        ruleSuggestion: FolderSuggestion?,
        learningMatch: LearningMatch?
    ) -> FolderSuggestion? {
        guard let learningMatch else {
            return ruleSuggestion
        }

        let learnedEntry = learningMatch.entry
        let learningConfidence = confidence(
            forLearningScore: learningMatch.score
        )

        var learningReasons: [String] = []

        learningReasons.append(
            "Atlas hat ähnliche Dokumente gefunden (\(learningMatch.score) Punkte)"
        )

        if learningMatch.companyMatched {
            learningReasons.append(
                "Firma stimmt überein"
            )
        } else {
            learningReasons.append(
                "Firma ist unterschiedlich"
            )
        }

        if learningMatch.documentTypeMatched {
            learningReasons.append(
                "Dokumenttyp stimmt überein"
            )
        } else {
            learningReasons.append(
                "Dokumenttyp ist unterschiedlich"
            )
        }

        if learningMatch.keywordMatches > 0 {
            learningReasons.append(
                "\(learningMatch.keywordMatches) Schlüsselwörter stimmen überein"
            )
        } else {
            learningReasons.append(
                "Keine Schlüsselwörter stimmen überein"
            )
        }

        guard let ruleSuggestion else {
            return FolderSuggestion(
                ruleName: "Gelernte Zuordnung",
                area: learnedEntry.archiveArea,
                folder: learnedEntry.folder,
                confidence: learningConfidence,
                reasons: learningReasons
            )
        }

        let learnedPathMatchesRule =
            ruleSuggestion.area == learnedEntry.archiveArea &&
            ruleSuggestion.folder.caseInsensitiveCompare(
                learnedEntry.folder
            ) == .orderedSame

        if learnedPathMatchesRule {
            let bonus = min(
                Double(learningMatch.score) / 500.0,
                0.20
            )

            return FolderSuggestion(
                ruleName: ruleSuggestion.ruleName,
                area: ruleSuggestion.area,
                folder: ruleSuggestion.folder,
                confidence: min(
                    ruleSuggestion.confidence + bonus,
                    1.0
                ),
                reasons:
                    ruleSuggestion.reasons
                    + learningReasons
                    + [
                        "Gelernte Zuordnung bestätigt den Regelvorschlag"
                    ]
            )
        }

        if learningConfidence > ruleSuggestion.confidence {
            return FolderSuggestion(
                ruleName: "Gelernte Zuordnung",
                area: learnedEntry.archiveArea,
                folder: learnedEntry.folder,
                confidence: learningConfidence,
                reasons:
                    learningReasons
                    + [
                        "Gelernter Zielordner ist stärker als der Regelvorschlag",
                        "Regelvorschlag war \(ruleSuggestion.displayPath)"
                    ]
            )
        }

        return FolderSuggestion(
            ruleName: ruleSuggestion.ruleName,
            area: ruleSuggestion.area,
            folder: ruleSuggestion.folder,
            confidence: ruleSuggestion.confidence,
            reasons:
                ruleSuggestion.reasons
                + learningReasons
                + [
                    "Eine gelernte Alternative wurde geprüft",
                    "Regelvorschlag bleibt stärker als die gelernte Zuordnung"
                ]
        )
    }

    private func confidence(
        forLearningScore score: Int
    ) -> Double {
        switch score {
        case 90...:
            return 0.95

        case 80..<90:
            return 0.90

        case 60..<80:
            return 0.80

        case 30..<60:
            return 0.65

        default:
            return 0.50
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

        if rule.matchesDocumentType(
            analysis.documentType
        ) {
            score += 0.40

            reasons.append(
                "Dokumentart \(analysis.documentType.rawValue) passt"
            )
        }

        if rule.matchesCompany(
            analysis.sender
        ) {
            score += 0.35

            if let sender = analysis.sender {
                reasons.append(
                    "Absender \(sender) passt"
                )
            }
        }

        let matchingKeywords =
            rule.matchingKeywords(
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
