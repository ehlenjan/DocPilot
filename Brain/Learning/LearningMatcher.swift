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
        var bestMatch: LearningMatch?

        for entry in entries {
            let companyMatched = companyMatches(
                analysisSender: analysis.sender,
                learnedCompany: entry.company
            )

            let documentTypeMatched =
                entry.documentType == analysis.documentType

            let keywordMatches = matchingKeywordCount(
                analysisKeywords: analysis.keywords,
                learnedKeywords: entry.keywords
            )

            var score = 0

            if companyMatched {
                score += 50
            }

            if documentTypeMatched {
                score += 30
            }

            score += keywordMatches * 5
            score += experienceBonus(
                for: entry.usageCount
            )

            guard score > 0 else {
                continue
            }

            let match = LearningMatch(
                entry: entry,
                score: score,
                companyMatched: companyMatched,
                documentTypeMatched: documentTypeMatched,
                keywordMatches: keywordMatches,
                usageCount: entry.usageCount
            )

            if bestMatch == nil ||
                match.score > bestMatch!.score {

                bestMatch = match
            }
        }

        return bestMatch
    }

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

    private func matchingKeywordCount(
        analysisKeywords: [String],
        learnedKeywords: [String]
    ) -> Int {
        let normalizedLearnedKeywords = Set(
            learnedKeywords.map {
                normalize($0)
            }
        )

        return analysisKeywords.reduce(
            into: 0
        ) { count, keyword in
            if normalizedLearnedKeywords.contains(
                normalize(keyword)
            ) {
                count += 1
            }
        }
    }

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

        default:
            return 0
        }
    }

    private func normalize(
        _ value: String
    ) -> String {
        value
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive
                ],
                locale: Locale(
                    identifier: "de_DE"
                )
            )
    }
}
