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

    private let knowledgeBase:
        KnowledgeBase

    private let learningManager:
        LearningManager

    private let learningMatcher:
        LearningMatcher

    init(
        knowledgeBase: KnowledgeBase,
        learningManager: LearningManager = LearningManager(),
        learningMatcher: LearningMatcher = LearningMatcher()
    ) {
        self.knowledgeBase =
            knowledgeBase

        self.learningManager =
            learningManager

        self.learningMatcher =
            learningMatcher
    }

    // MARK: - Suggestion

    func suggestFolder(
        for analysis: AtlasAnalysis,
        text: String
    ) -> FolderSuggestion? {

        // Neu gelernte Zuordnungen immer
        // vor einer Empfehlung nachladen.
        learningManager.reload()

        let ruleSuggestion =
            bestRuleSuggestion(
                for: analysis,
                text: text
            )

        // Wenn der Empfänger erkannt wurde,
        // dürfen nur Lernerfahrungen desselben
        // Archivbereichs berücksichtigt werden.
        let learningEntries =
            filteredLearningEntries(
                for: analysis
            )

        let learningMatch =
            learningMatcher.bestMatch(
                for: analysis,
                entries:
                    learningEntries
            )

        return combine(
            ruleSuggestion:
                ruleSuggestion,
            learningMatch:
                learningMatch,
            analysis:
                analysis
        )
    }

    // MARK: - Learning Area Filter

    private func filteredLearningEntries(
        for analysis: AtlasAnalysis
    ) -> [LearningEntry] {

        guard let recipientArea =
            analysis.recipientArea
        else {
            return learningManager.entries
        }

        return learningManager.entries.filter {
            $0.archiveArea ==
                recipientArea
        }
    }

    // MARK: - Rules

    private func bestRuleSuggestion(
        for analysis: AtlasAnalysis,
        text: String
    ) -> FolderSuggestion? {

        let candidates =
            knowledgeBase
                .folderRules
                .compactMap { rule in

                    evaluate(
                        rule: rule,
                        analysis:
                            analysis,
                        text:
                            text
                    )
                }

        return candidates.max {
            $0.confidence <
                $1.confidence
        }
    }

    // MARK: - Combine Rule + Learning

    private func combine(
        ruleSuggestion: FolderSuggestion?,
        learningMatch: LearningMatch?,
        analysis: AtlasAnalysis
    ) -> FolderSuggestion? {

        guard let learningMatch
        else {

            return addRecipientReason(
                to:
                    ruleSuggestion,
                analysis:
                    analysis
            )
        }

        let learnedEntry =
            learningMatch.entry

        let learningConfidence =
            confidence(
                forLearningScore:
                    learningMatch.score
            )

        var learningReasons:
            [String] = []

        learningReasons.append(
            "Atlas hat ähnliche Dokumente gefunden (\(learningMatch.score) Punkte)"
        )

        if let recipientArea =
            analysis.recipientArea {

            learningReasons.append(
                "Empfänger gehört zu \(recipientArea.rawValue)"
            )
        }

        if learningMatch.companyMatched {

            learningReasons.append(
                "Firma stimmt überein"
            )

        } else {

            learningReasons.append(
                "Firma ist unterschiedlich"
            )
        }

        if learningMatch
            .documentTypeMatched {

            learningReasons.append(
                "Dokumenttyp stimmt überein"
            )

        } else {

            learningReasons.append(
                "Dokumenttyp ist unterschiedlich"
            )
        }

        if learningMatch
            .keywordMatches > 0 {

            learningReasons.append(
                "\(learningMatch.keywordMatches) Schlüsselwörter stimmen überein"
            )

        } else {

            learningReasons.append(
                "Keine Schlüsselwörter stimmen überein"
            )
        }

        if learningMatch.usageCount > 1 {

            learningReasons.append(
                "Dieses Ziel wurde bereits \(learningMatch.usageCount)× bestätigt"
            )
        }

        // Keine passende Regel vorhanden:
        // gelernte Zuordnung verwenden.
        guard let ruleSuggestion
        else {

            return FolderSuggestion(
                ruleName:
                    "Gelernte Zuordnung",
                area:
                    learnedEntry.archiveArea,
                folder:
                    learnedEntry.folder,
                confidence:
                    learningConfidence,
                reasons:
                    learningReasons
            )
        }

        let learnedPathMatchesRule =
            ruleSuggestion.area ==
                learnedEntry.archiveArea
            &&
            ruleSuggestion.folder
                .caseInsensitiveCompare(
                    learnedEntry.folder
                ) == .orderedSame

        // Regel und Lernen zeigen auf
        // exakt dasselbe Ziel.
        if learnedPathMatchesRule {

            let bonus =
                min(
                    Double(
                        learningMatch.score
                    ) / 500.0,
                    0.20
                )

            return FolderSuggestion(
                ruleName:
                    ruleSuggestion.ruleName,
                area:
                    ruleSuggestion.area,
                folder:
                    ruleSuggestion.folder,
                confidence:
                    min(
                        ruleSuggestion
                            .confidence
                            + bonus,
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

        // Lernen ist stärker.
        if learningConfidence >
            ruleSuggestion.confidence {

            return FolderSuggestion(
                ruleName:
                    "Gelernte Zuordnung",
                area:
                    learnedEntry.archiveArea,
                folder:
                    learnedEntry.folder,
                confidence:
                    learningConfidence,
                reasons:
                    learningReasons
                    + [
                        "Gelernter Zielordner ist stärker als der Regelvorschlag",
                        "Regelvorschlag war \(ruleSuggestion.displayPath)"
                    ]
            )
        }

        // Regel bleibt stärker.
        return FolderSuggestion(
            ruleName:
                ruleSuggestion.ruleName,
            area:
                ruleSuggestion.area,
            folder:
                ruleSuggestion.folder,
            confidence:
                ruleSuggestion.confidence,
            reasons:
                ruleSuggestion.reasons
                + learningReasons
                + [
                    "Eine gelernte Alternative wurde geprüft",
                    "Regelvorschlag bleibt stärker als die gelernte Zuordnung"
                ]
        )
    }

    // MARK: - Recipient Reason

    private func addRecipientReason(
        to suggestion:
            FolderSuggestion?,
        analysis:
            AtlasAnalysis
    ) -> FolderSuggestion? {

        guard let suggestion
        else {
            return nil
        }

        guard let recipientArea =
            analysis.recipientArea
        else {
            return suggestion
        }

        return FolderSuggestion(
            ruleName:
                suggestion.ruleName,
            area:
                suggestion.area,
            folder:
                suggestion.folder,
            confidence:
                suggestion.confidence,
            reasons:
                suggestion.reasons
                + [
                    "Empfänger \(recipientArea.rawValue) wurde berücksichtigt"
                ]
        )
    }

    // MARK: - Learning Confidence

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

        case 35..<60:
            return 0.65

        default:
            return 0.50
        }
    }

    // MARK: - Evaluate Rule

    private func evaluate(
        rule: FolderRule,
        analysis: AtlasAnalysis,
        text: String
    ) -> FolderSuggestion? {

        guard let area =
            rule.archiveArea
        else {
            return nil
        }

        // MARK: Empfänger als Bereichs-Gate

        // Wenn Atlas den Empfänger sicher erkannt hat,
        // darf keine Regel eines anderen Betriebs
        // mehr gewinnen.
        if let recipientArea =
            analysis.recipientArea,
           area != recipientArea {

            return nil
        }

        var score =
            0.0

        var reasons:
            [String] = []

        // Empfänger ist für deine Archivstruktur
        // das wichtigste Merkmal.
        if let recipientArea =
            analysis.recipientArea,
           recipientArea == area {

            score += 0.45

            reasons.append(
                "Empfänger \(recipientArea.rawValue) passt zum Archivbereich"
            )
        }

        if rule.matchesDocumentType(
            analysis.documentType
        ) {

            score += 0.30

            reasons.append(
                "Dokumentart \(analysis.documentType.rawValue) passt"
            )
        }

        if rule.matchesCompany(
            analysis.sender
        ) {

            score += 0.15

            if let sender =
                analysis.sender {

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

            let keywordScore =
                min(
                    Double(
                        matchingKeywords.count
                    ) * 0.05,
                    0.10
                )

            score +=
                keywordScore

            reasons.append(
                "Schlüsselwörter: \(matchingKeywords.joined(separator: ", "))"
            )
        }

        guard score > 0
        else {
            return nil
        }

        return FolderSuggestion(
            ruleName:
                rule.name,
            area:
                area,
            folder:
                rule.folder,
            confidence:
                min(
                    score,
                    1.0
                ),
            reasons:
                reasons
        )
    }
}
