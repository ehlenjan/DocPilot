import Foundation

struct LearningMatch {

    let entry: LearningEntry
    let score: Int

    let companyMatched: Bool
    let documentTypeMatched: Bool
    let keywordMatches: Int
    let usageCount: Int
}

struct LearningMatcher {

    func bestMatch(
        for analysis: AtlasAnalysis,
        entries: [LearningEntry]
    ) -> LearningMatch? {

        var bestMatch:
            LearningMatch?

        for entry in entries {

            let companyMatched =
                companyMatches(
                    analysisSender:
                        analysis.sender,
                    learnedCompany:
                        entry.company
                )

            let documentTypeMatched =
                entry.documentType ==
                analysis.documentType

            let keywordMatches =
                matchingKeywordCount(
                    analysisKeywords:
                        analysis.keywords,
                    learnedKeywords:
                        entry.keywords
                )

            // MARK: - Mindestähnlichkeit

            // Ein gleicher Dokumenttyp allein
            // ist kein ausreichendes Lernsignal.
            //
            // Sonst würde jede Rechnung mit jeder
            // anderen Rechnung konkurrieren.
            guard
                companyMatched ||
                keywordMatches > 0
            else {
                continue
            }

            var score = 0

            // Firma ist unser stärkstes Merkmal.
            if companyMatched {
                score += 60
            }

            // Dokumenttyp verstärkt einen bereits
            // plausiblen Treffer.
            if documentTypeMatched {
                score += 20
            }

            // Gemeinsame Schlüsselwörter.
            score +=
                min(
                    keywordMatches * 8,
                    32
                )

            // Wiederholt bestätigte Zuordnungen
            // werden mit der Zeit stärker.
            score +=
                experienceBonus(
                    for:
                        entry.usageCount
                )

            // Sehr schwache Treffer ignorieren.
            guard score >= 35 else {
                continue
            }

            let match =
                LearningMatch(
                    entry:
                        entry,
                    score:
                        score,
                    companyMatched:
                        companyMatched,
                    documentTypeMatched:
                        documentTypeMatched,
                    keywordMatches:
                        keywordMatches,
                    usageCount:
                        entry.usageCount
                )

            if bestMatch == nil ||
                match.score >
                bestMatch!.score {

                bestMatch =
                    match
            }
        }

        return bestMatch
    }

    // MARK: - Company

    private func companyMatches(
        analysisSender: String?,
        learnedCompany: String?
    ) -> Bool {

        guard
            let analysisSender,
            let learnedCompany
        else {
            return false
        }

        return analysisSender.compare(
            learnedCompany,
            options: [
                .caseInsensitive,
                .diacriticInsensitive
            ]
        ) == .orderedSame
    }

    // MARK: - Keywords

    private func matchingKeywordCount(
        analysisKeywords: [String],
        learnedKeywords: [String]
    ) -> Int {

        let normalizedLearnedKeywords =
            Set(
                learnedKeywords.map {
                    normalize($0)
                }
            )

        return analysisKeywords.reduce(
            into: 0
        ) { count, keyword in

            if normalizedLearnedKeywords
                .contains(
                    normalize(
                        keyword
                    )
                ) {

                count += 1
            }
        }
    }

    // MARK: - Experience

    private func experienceBonus(
        for usageCount: Int
    ) -> Int {

        switch usageCount {

        case 100...:
            return 25

        case 50..<100:
            return 20

        case 20..<50:
            return 15

        case 10..<20:
            return 10

        case 5..<10:
            return 5

        case 2..<5:
            return 3

        default:
            return 0
        }
    }

    // MARK: - Normalize

    private func normalize(
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
    }
}
