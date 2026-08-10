import Foundation

struct CompanyRecognizer {

    private let knowledgeBase: KnowledgeBase

    init(
        knowledgeBase: KnowledgeBase
    ) {
        self.knowledgeBase =
            knowledgeBase
    }

    func detect(
        in text: String
    ) -> String? {

        let normalizedText =
            normalize(text)

        guard !normalizedText.isEmpty else {
            return nil
        }

        let headerText =
            headerSection(
                from: normalizedText
            )

        let candidates =
            knowledgeBase.companies
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

        guard let bestCandidate =
            candidates.max(
                by: {
                    $0.score <
                        $1.score
                }
            )
        else {
            return nil
        }

        // Sehr schwache Einzel-Treffer
        // lieber nicht als Absender ausgeben.
        guard bestCandidate.score >= 30
        else {
            return nil
        }

        return bestCandidate.name
    }

    // MARK: - Candidate

    private struct Candidate {

        let name: String
        let score: Int
    }

    // MARK: - Evaluation

    private func evaluate(
        company: CompanyRule,
        fullText: String,
        headerText: String
    ) -> Candidate? {

        var score = 0

        var matchedKeywords:
            Set<String> = []

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

            guard occurrences > 0
            else {
                continue
            }

            matchedKeywords.insert(
                normalizedKeyword
            )

            // Jeder Treffer zählt etwas.
            score +=
                min(
                    occurrences * 8,
                    24
                )

            // Treffer weit oben im Dokument
            // sind deutlich relevanter.
            if headerText.contains(
                normalizedKeyword
            ) {
                score += 30
            }

            // Längere, spezifischere Begriffe
            // sind vertrauenswürdiger.
            if normalizedKeyword.count >= 10 {
                score += 8
            } else if normalizedKeyword.count >= 6 {
                score += 4
            }
        }

        guard !matchedKeywords.isEmpty
        else {
            return nil
        }

        // Mehrere unterschiedliche Merkmale
        // derselben Firma stärken die Zuordnung.
        if matchedKeywords.count >= 2 {
            score += 15
        }

        if matchedKeywords.count >= 3 {
            score += 10
        }

        return Candidate(
            name:
                company.name,
            score:
                score
        )
    }

    // MARK: - Header

    private func headerSection(
        from text: String
    ) -> String {

        // Für den ersten Schritt nehmen wir
        // ungefähr den vorderen Bereich des
        // extrahierten Textes.
        //
        // Das ist nicht perfekt, aber deutlich
        // besser als jeden Treffer im gesamten
        // Dokument gleich zu behandeln.

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
        of keyword: String,
        in text: String
    ) -> Int {

        guard
            !keyword.isEmpty,
            !text.isEmpty
        else {
            return 0
        }

        var count = 0

        var searchRange =
            text.startIndex
            ..<
            text.endIndex

        while let range =
            text.range(
                of:
                    keyword,
                options: [],
                range:
                    searchRange
            ) {

            count += 1

            searchRange =
                range.upperBound
                ..<
                text.endIndex
        }

        return count
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
            .lowercased()
    }
}
