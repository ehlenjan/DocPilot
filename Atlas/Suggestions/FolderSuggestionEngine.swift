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
        learningManager: LearningManager =
            LearningManager(),
        learningMatcher: LearningMatcher =
            LearningMatcher()
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

        learningManager.reload()

        learningManager
            .removeInvalidEntries(
                validFolders:
                    knowledgeBase
                        .archiveFolders
            )

        let ruleSuggestion =
            bestRuleSuggestion(
                for: analysis,
                text: text
            )

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

        let suggestion =
            combine(
                ruleSuggestion:
                    ruleSuggestion,
                learningMatch:
                    learningMatch,
                analysis:
                    analysis
            )

        // Letzte Sicherheitsstufe:
        // Niemals einen Ordner zurückgeben,
        // den Atlas nicht mehr kennt.
        guard let suggestion
        else {
            return nil
        }

        guard
            isValidFolder(
                area:
                    suggestion.area,
                folder:
                    suggestion.folder
            )
        else {

            print(
                """
                ⚠️ Atlas hat ungültigen Zielordner verworfen:
                \(suggestion.displayPath)
                Quelle: \(suggestion.ruleName)
                """
            )

            return nil
        }

        return suggestion
    }

    // MARK: - Learning Area Filter

    private func filteredLearningEntries(
        for analysis: AtlasAnalysis
    ) -> [LearningEntry] {

        var entries =
            learningManager.entries

        // MARK: Recipient Area

        if let recipientArea =
            analysis.recipientArea {

            entries =
                entries.filter {

                    $0.archiveArea ==
                        recipientArea
                }
        }

        // MARK: Existing Folders Only

        // Alte gelernte Zuordnungen auf inzwischen
        // entfernte oder umbenannte Ordner dürfen
        // nicht mehr am Matching teilnehmen.
        entries =
            entries.filter {
                entry in

                let valid =
                    isValidFolder(
                        area:
                            entry.archiveArea,
                        folder:
                            entry.folder
                    )

                if !valid {

                    print(
                        """
                        ⚠️ Veraltete Atlas-Lernzuordnung ignoriert:
                        \(entry.archiveArea.rawValue) → \(entry.folder)
                        """
                    )
                }

                return valid
            }

        return entries
    }

    // MARK: - Rules

    private func bestRuleSuggestion(
        for analysis: AtlasAnalysis,
        text: String
    ) -> FolderSuggestion? {

        let candidates =
            knowledgeBase
                .folderRules
                .compactMap {
                    rule in

                    evaluate(
                        rule:
                            rule,
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

        // Noch einmal absichern, falls sich die
        // KnowledgeBase zwischen Matching und
        // Kombination geändert haben sollte.
        let learnedFolderIsValid =
            isValidFolder(
                area:
                    learnedEntry.archiveArea,
                folder:
                    learnedEntry.folder
            )

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

        // MARK: Invalid Learned Folder

        // Wenn die gelernte Zuordnung inzwischen
        // auf einen nicht mehr vorhandenen Ordner
        // zeigt, darf sie niemals gewinnen.
        if !learnedFolderIsValid {

            if let ruleSuggestion {

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
                        + [
                            "Eine veraltete gelernte Zuordnung wurde ignoriert"
                        ]
                )
            }

            return nil
        }

        // MARK: Learning Only

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
                    + [
                        "Zielordner existiert in der aktuellen Archivstruktur"
                    ]
            )
        }

        let learnedPathMatchesRule =
            ruleSuggestion.area ==
                learnedEntry.archiveArea
            &&
            sameFolderName(
                ruleSuggestion.folder,
                learnedEntry.folder
            )

        // MARK: Rule + Learning Agree

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

        // MARK: Learning Stronger

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

        // MARK: Rule Stronger

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
        to suggestion: FolderSuggestion?,
        analysis: AtlasAnalysis
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

        // MARK: Folder Must Exist

        // Ganz wichtig:
        // Eine Regel, deren Zielordner nicht mehr
        // existiert, wird gar nicht erst bewertet.
        guard
            isValidFolder(
                area:
                    area,
                folder:
                    rule.folder
            )
        else {

            print(
                """
                ⚠️ Ungültige Atlas-Regel ignoriert:
                \(rule.name)
                Ziel: \(area.rawValue) → \(rule.folder)
                """
            )

            return nil
        }

        // MARK: Recipient Area Gate

        if let recipientArea =
            analysis.recipientArea,
           area != recipientArea {

            return nil
        }

        var score =
            0.0

        var reasons:
            [String] = []

        // MARK: Recipient

        if let recipientArea =
            analysis.recipientArea,
           recipientArea == area {

            score +=
                0.45

            reasons.append(
                "Empfänger \(recipientArea.rawValue) passt zum Archivbereich"
            )
        }

        // MARK: Document Type

        if rule.matchesDocumentType(
            analysis.documentType
        ) {

            score +=
                0.30

            reasons.append(
                "Dokumentart \(analysis.documentType.rawValue) passt"
            )
        }

        // MARK: Company

        if rule.matchesCompany(
            analysis.sender
        ) {

            score +=
                0.15

            if let sender =
                analysis.sender {

                reasons.append(
                    "Absender \(sender) passt"
                )
            }
        }

        // MARK: Keywords

        let matchingKeywords =
            rule.matchingKeywords(
                in:
                    text
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
                + [
                    "Zielordner wurde gegen die aktuelle Archivstruktur geprüft"
                ]
        )
    }

    // MARK: - Folder Validation

    private func isValidFolder(
        area: ArchiveArea,
        folder: String
    ) -> Bool {

        knowledgeBase
            .archiveFolders
            .contains {
                archiveFolder in

                archiveFolder.area ==
                    area
                &&
                sameFolderName(
                    archiveFolder.name,
                    folder
                )
            }
    }

    // MARK: - Folder Name Comparison

    private func sameFolderName(
        _ first: String,
        _ second: String
    ) -> Bool {

        normalizeFolderName(
            first
        ) ==
        normalizeFolderName(
            second
        )
    }

    // MARK: - Normalize Folder

    private func normalizeFolderName(
        _ value: String
    ) -> String {

        value
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive
                ],
                locale:
                    Locale(
                        identifier:
                            "de_DE"
                    )
            )
            .lowercased()
    }
}
