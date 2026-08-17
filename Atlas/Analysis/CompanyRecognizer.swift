import Foundation

struct CompanyRecognitionResult {

    let company:
        String

    let matchedText:
        String

    let score:
        Int
}

// MARK: - Company Recognizer

struct CompanyRecognizer {

    private let knowledgeBase:
        KnowledgeBase

    private let learnedSignatureStore =
        LearnedCompanySignatureStore()

    init(
        knowledgeBase:
            KnowledgeBase
    ) {

        self.knowledgeBase =
            knowledgeBase
    }

    // MARK: - Existing Interface

    func detect(
        in text:
            String
    ) -> String? {

        detectResult(
            in:
                text
        )?
        .company
    }

    // MARK: - Detailed Result

    func detectResult(
        in text:
            String
    ) -> CompanyRecognitionResult? {

        let normalizedText =
            normalize(
                text
            )

        guard
            !normalizedText.isEmpty
        else {

            return nil
        }

        let headerText =
            headerSection(
                from:
                    normalizedText
            )

        // MARK: - KnowledgeBase Candidates

        let knowledgeCandidates =
            knowledgeBase
                .companies
                .compactMap {
                    company in

                    evaluate(
                        company:
                            company,
                        fullText:
                            normalizedText,
                        headerText:
                            headerText
                    )
                }

        let bestKnowledgeCandidate =
            knowledgeCandidates.max(
                by: {

                    $0.score <
                        $1.score
                }
            )

        // MARK: - Learned Candidate

        let learnedMatch =
            learnedSignatureStore
                .bestMatch(
                    in:
                        text
                )

        // MARK: - Compare

        let knowledgeResult:
            CompanyRecognitionResult?

        if let bestKnowledgeCandidate,
           bestKnowledgeCandidate.score >= 30 {

            knowledgeResult =
                CompanyRecognitionResult(
                    company:
                        bestKnowledgeCandidate.name,
                    matchedText:
                        bestKnowledgeCandidate.bestMatchedKeyword,
                    score:
                        bestKnowledgeCandidate.score
                )

        } else {

            knowledgeResult =
                nil
        }

        let learnedResult:
            CompanyRecognitionResult?

        if let learnedMatch,
           learnedMatch.isReliable {

            let matchedText =
                learnedMatch
                    .matchedSignals
                    .first
                ??
                learnedMatch.company

            learnedResult =
                CompanyRecognitionResult(
                    company:
                        learnedMatch.company,
                    matchedText:
                        matchedText,
                    score:
                        learnedMatch.score
                )

        } else {

            learnedResult =
                nil
        }

        switch (
            knowledgeResult,
            learnedResult
        ) {

        case let (
            knowledge?,
            learned?
        ):

            // Wenn beide dieselbe Firma meinen,
            // vertrauen wir der Zuordnung und nehmen
            // die stärkere Punktzahl.
            if sameCompany(
                knowledge.company,
                learned.company
            ) {

                if learned.score >
                    knowledge.score {

                    return learned
                }

                return knowledge
            }

            // Bei widersprüchlichen Firmen darf ein
            // gelernter Treffer nur gewinnen, wenn
            // er merklich stärker ist.
            if learned.score >=
                knowledge.score + 12 {

                return learned
            }

            return knowledge

        case let (
            knowledge?,
            nil
        ):

            return knowledge

        case let (
            nil,
            learned?
        ):

            return learned

        case (
            nil,
            nil
        ):

            return nil
        }
    }

    // MARK: - Candidate

    private struct Candidate {

        let name:
            String

        let score:
            Int

        let bestMatchedKeyword:
            String
    }

    // MARK: - Knowledge Evaluation

    private func evaluate(
        company:
            CompanyRule,
        fullText:
            String,
        headerText:
            String
    ) -> Candidate? {

        var score =
            0

        var matchedKeywords:
            Set<String> = []

        var bestMatchedKeyword =
            ""

        var bestKeywordScore =
            Int.min

        for keyword in
            company.keywords {

            let normalizedKeyword =
                normalize(
                    keyword
                )

            guard
                !normalizedKeyword.isEmpty
            else {

                continue
            }

            let occurrences =
                occurrenceCount(
                    of:
                        normalizedKeyword,
                    in:
                        fullText
                )

            guard
                occurrences > 0
            else {

                continue
            }

            matchedKeywords.insert(
                normalizedKeyword
            )

            var keywordScore =
                0

            // Jeder Treffer zählt etwas.
            let occurrenceScore =
                min(
                    occurrences * 8,
                    24
                )

            score +=
                occurrenceScore

            keywordScore +=
                occurrenceScore

            // Treffer weit oben im Dokument
            // sind deutlich relevanter.
            if headerText.contains(
                normalizedKeyword
            ) {

                score +=
                    30

                keywordScore +=
                    30
            }

            // Längere, spezifischere Begriffe
            // sind vertrauenswürdiger.
            if normalizedKeyword.count >= 10 {

                score +=
                    8

                keywordScore +=
                    8

            } else if
                normalizedKeyword.count >= 6 {

                score +=
                    4

                keywordScore +=
                    4
            }

            if keywordScore >
                bestKeywordScore {

                bestKeywordScore =
                    keywordScore

                // Ursprüngliches Keyword zurückgeben,
                // damit Atlas ggf. danach suchen kann.
                bestMatchedKeyword =
                    keyword
            }
        }

        guard
            !matchedKeywords.isEmpty,
            !bestMatchedKeyword.isEmpty
        else {

            return nil
        }

        // Mehrere unterschiedliche Merkmale
        // derselben Firma stärken die Zuordnung.
        if matchedKeywords.count >= 2 {

            score +=
                15
        }

        if matchedKeywords.count >= 3 {

            score +=
                10
        }

        return Candidate(
            name:
                company.name,
            score:
                score,
            bestMatchedKeyword:
                bestMatchedKeyword
        )
    }

    // MARK: - Header

    private func headerSection(
        from text:
            String
    ) -> String {

        let maximumLength =
            min(
                text.count,
                2500
            )

        let endIndex =
            text.index(
                text.startIndex,
                offsetBy:
                    maximumLength
            )

        return String(
            text[
                text.startIndex
                ..<
                endIndex
            ]
        )
    }

    // MARK: - Occurrences

    private func occurrenceCount(
        of keyword:
            String,
        in text:
            String
    ) -> Int {

        guard
            !keyword.isEmpty,
            !text.isEmpty
        else {

            return 0
        }

        var count =
            0

        var searchRange =
            text.startIndex
            ..<
            text.endIndex

        while let range =
            text.range(
                of:
                    keyword,
                options:
                    [],
                range:
                    searchRange
            ) {

            count +=
                1

            searchRange =
                range.upperBound
                ..<
                text.endIndex
        }

        return count
    }

    // MARK: - Same Company

    private func sameCompany(
        _ first:
            String,
        _ second:
            String
    ) -> Bool {

        normalize(
            first
        )
        ==
        normalize(
            second
        )
    }

    // MARK: - Normalize

    private func normalize(
        _ value:
            String
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
