import Foundation

struct DocumentClassifier {

    private let knowledgeBase:
        KnowledgeBase

    init(
        knowledgeBase: KnowledgeBase
    ) {
        self.knowledgeBase =
            knowledgeBase
    }

    // MARK: - Detection

    func detect(
        in text: String
    ) -> DocumentType {

        let normalizedText =
            normalize(
                text
            )

        guard
            !normalizedText.isEmpty
        else {
            return .unknown
        }

        let normalizedLines =
            text
                .components(
                    separatedBy:
                        .newlines
                )
                .map {
                    normalize(
                        $0
                    )
                }
                .filter {
                    !$0.isEmpty
                }

        // Die ersten Zeilen entsprechen bei
        // PDF-Textextraktion meistens ungefähr
        // dem Dokumentkopf.
        let headerLines =
            Array(
                normalizedLines
                    .prefix(15)
            )

        let results =
            knowledgeBase
                .documentTypes
                .compactMap {
                    rule in

                    score(
                        rule:
                            rule,
                        normalizedText:
                            normalizedText,
                        normalizedLines:
                            normalizedLines,
                        headerLines:
                            headerLines
                    )
                }
                .sorted {

                    $0.score >
                        $1.score
                }

        guard let best =
            results.first
        else {

            return .unknown
        }

        // Ein einzelner sehr schwacher Treffer
        // soll noch keine Dokumentart bestimmen.
        guard
            best.score >= 2.0
        else {

            return .unknown
        }

        // Wenn zwei Dokumentarten beinahe gleichauf
        // liegen, soll Atlas lieber Unsicherheit
        // zeigen als falsch entscheiden.
        if results.count > 1 {

            let second =
                results[1]

            let difference =
                best.score -
                second.score

            if difference < 0.75 {

                return .unknown
            }
        }

        return best.documentType
    }

    // MARK: - Rule Scoring

    private func score(
        rule: DocumentTypeRule,
        normalizedText: String,
        normalizedLines: [String],
        headerLines: [String]
    ) -> ClassificationResult? {

        var totalScore =
            0.0

        var matchedKeywords:
            Set<String> = []

        for keyword in
            rule.keywords {

            let normalizedKeyword =
                normalize(
                    keyword
                )

            guard
                !normalizedKeyword.isEmpty
            else {
                continue
            }

            guard
                normalizedText.contains(
                    normalizedKeyword
                )
            else {
                continue
            }

            // Dasselbe Keyword nur einmal als
            // Hauptmerkmal zählen.
            guard
                !matchedKeywords.contains(
                    normalizedKeyword
                )
            else {
                continue
            }

            matchedKeywords.insert(
                normalizedKeyword
            )

            var keywordScore =
                baseScore(
                    for:
                        normalizedKeyword
                )

            // MARK: Header Bonus

            if headerLines.contains(
                where: {
                    $0.contains(
                        normalizedKeyword
                    )
                }
            ) {

                keywordScore +=
                    2.5
            }

            // MARK: Heading Bonus

            // Ist eine Zeile praktisch nur
            // "Rechnung", "Lieferschein" usw.,
            // ist das ein sehr starkes Signal.
            if normalizedLines.contains(
                where: {
                    isHeadingMatch(
                        line:
                            $0,
                        keyword:
                            normalizedKeyword
                    )
                }
            ) {

                keywordScore +=
                    3.0
            }

            // MARK: Identifier Bonus

            // Begriffe wie Rechnungsnummer,
            // Lieferscheinnummer usw. sind
            // wesentlich aussagekräftiger als
            // beiläufige Erwähnungen.
            if looksLikeIdentifierKeyword(
                normalizedKeyword
            ) {

                keywordScore +=
                    1.5
            }

            // MARK: Repetition Bonus

            let occurrenceCount =
                countOccurrences(
                    of:
                        normalizedKeyword,
                    in:
                        normalizedText
                )

            if occurrenceCount > 1 {

                keywordScore +=
                    min(
                        Double(
                            occurrenceCount - 1
                        ) * 0.30,
                        0.90
                    )
            }

            totalScore +=
                keywordScore
        }

        guard
            !matchedKeywords.isEmpty
        else {

            return nil
        }

        // Mehrere unterschiedliche Merkmale derselben
        // Dokumentart bestätigen sich gegenseitig.
        if matchedKeywords.count >= 2 {

            totalScore +=
                Double(
                    matchedKeywords.count - 1
                ) * 0.75
        }

        return ClassificationResult(
            documentType:
                rule.documentType,
            score:
                totalScore
        )
    }

    // MARK: - Base Score

    private func baseScore(
        for keyword: String
    ) -> Double {

        switch keyword.count {

        case 14...:
            return 2.0

        case 9..<14:
            return 1.6

        case 5..<9:
            return 1.2

        default:
            return 0.8
        }
    }

    // MARK: - Heading Detection

    private func isHeadingMatch(
        line: String,
        keyword: String
    ) -> Bool {

        if line ==
            keyword {

            return true
        }

        // Beispiele:
        //
        // Rechnung 4711
        // Lieferschein Nr. 1234
        // Gutschrift #987
        //
        // Aber ein langer Fließtext soll dadurch
        // keinen Überschriftenbonus bekommen.
        guard
            line.count <= 80
        else {

            return false
        }

        if line.hasPrefix(
            keyword + " "
        ) {

            return true
        }

        if line.hasPrefix(
            keyword + ":"
        ) {

            return true
        }

        if line.hasPrefix(
            keyword + "-"
        ) {

            return true
        }

        return false
    }

    // MARK: - Identifier Keyword

    private func looksLikeIdentifierKeyword(
        _ keyword: String
    ) -> Bool {

        let indicators = [
            "nummer",
            "nr.",
            " nr ",
            "belegnummer",
            "rechnungsnummer",
            "rechnungsnr",
            "lieferscheinnummer",
            "lieferscheinnr",
            "auftragsnummer",
            "auftragsnr",
            "gutschriftsnummer",
            "gutschriftsnr"
        ]

        return indicators.contains {
            indicator in

            keyword.contains(
                indicator
            )
        }
    }

    // MARK: - Occurrences

    private func countOccurrences(
        of keyword: String,
        in text: String
    ) -> Int {

        guard
            !keyword.isEmpty
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

            guard
                range.upperBound <
                    text.endIndex
            else {

                break
            }

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
            .replacingOccurrences(
                of:
                    "\\s+",
                with:
                    " ",
                options:
                    .regularExpression
            )
    }
}

// MARK: - Classification Result

private struct ClassificationResult {

    let documentType:
        DocumentType

    let score:
        Double
}
