import Foundation

// MARK: - Document Classification Result

struct DocumentClassificationResult {

    let documentType:
        DocumentType

    // Der Begriff, der den stärksten
    // Einzelbeitrag zur Erkennung geleistet hat.
    let matchedText:
        String
}

// MARK: - Document Classifier

struct DocumentClassifier {

    private let knowledgeBase:
        KnowledgeBase

    init(
        knowledgeBase: KnowledgeBase
    ) {

        self.knowledgeBase =
            knowledgeBase
    }

    // MARK: - Existing Detection

    func detect(
        in text: String
    ) -> DocumentType {

        detectResult(
            in:
                text
        )?
        .documentType
        ?? .unknown
    }

    // MARK: - Detailed Detection

    func detectResult(
        in text: String
    ) -> DocumentClassificationResult? {

        let normalizedText =
            normalize(
                text
            )

        guard
            !normalizedText.isEmpty
        else {

            return nil
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
        // MARK: - Explicit Document Heading

        // Eine eindeutige Dokumentbezeichnung hat Vorrang
        // vor dem späteren Keyword-Scoring.
        //
        // Das ist besonders wichtig bei OCR-Fehlern wie:
        // "Rech n u ng" -> "Rechnung"
        //
        // Begriffe wie "Lieferdatum" dürfen eine solche
        // eindeutige Überschrift nicht überstimmen.
        if let explicitHeading =
            detectExplicitDocumentHeading(
                in:
                    normalizedLines
            ) {

            return explicitHeading
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

        guard
            let best =
                results.first
        else {

            return nil
        }

        // Ein einzelner sehr schwacher Treffer
        // soll noch keine Dokumentart bestimmen.
        guard
            best.score >= 2.0
        else {

            return nil
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

                return nil
            }
        }

        guard
            let strongestKeyword =
                best.strongestKeyword
        else {

            return nil
        }

        return DocumentClassificationResult(
            documentType:
                best.documentType,
            matchedText:
                strongestKeyword
        )
    }
    // MARK: - Explicit Document Heading Detection

    private func detectExplicitDocumentHeading(
        in lines: [String]
    ) -> DocumentClassificationResult? {

        // Nur eindeutige Dokumentbezeichnungen.
        //
        // Hier bewusst KEINE Begriffe wie
        // "Lieferdatum", "Belegnummer" usw.
        let explicitHeadings:
            [(keyword: String, type: DocumentType)] = [

                (
                    "rechnung",
                    .invoice
                ),

                (
                    "gutschrift",
                    .creditNote
                ),

                (
                    "lieferschein",
                    .deliveryNote
                ),

                (
                    "schlachtprotokoll",
                    .slaughterReport
                ),

                (
                    "wiegeprotokoll",
                    .weighingReport
                ),

                (
                    "vertrag",
                    .contract
                ),

                (
                    "einladung",
                    .invitation
                ),

                (
                    "untersuchungsbericht",
                    .examination
                )
            ]

        // Dokumentüberschriften befinden sich normalerweise
        // relativ weit oben. Wir begrenzen die Suche deshalb,
        // damit beispielsweise eine beiläufige Erwähnung von
        // "Rechnung" am Seitenende keinen Vorrang bekommt.
        let candidateLines =
            Array(
                lines.prefix(
                    30
                )
            )

        for line in candidateLines {

            // Sehr lange Textzeilen sind keine Überschriften.
            guard
                line.count <= 80
            else {

                continue
            }

            let compactLine =
                compactText(
                    line
                )

            for heading in explicitHeadings {

                let compactKeyword =
                    compactText(
                        heading.keyword
                    )

                // MARK: Exact Heading

                if compactLine ==
                    compactKeyword {

                    return DocumentClassificationResult(
                        documentType:
                            heading.type,
                        matchedText:
                            heading.keyword
                    )
                }

                // MARK: Heading with Number / Addition

                // Beispiele:
                //
                // Rechnung 4711
                // Rechnung: 4711
                // Lieferschein Nr. 123
                //
                // Auch OCR-zerhackte Schreibweisen wie
                // "Rech n u ng" funktionieren durch
                // compactText().
                if compactLine.hasPrefix(
                    compactKeyword
                ) {

                    let remainingText =
                        String(
                            compactLine.dropFirst(
                                compactKeyword.count
                            )
                        )

                    // Nur kurze Ergänzungen zulassen.
                    // Dadurch vermeiden wir Treffer in
                    // normalen Sätzen.
                    if remainingText.count <= 30 {

                        return DocumentClassificationResult(
                            documentType:
                                heading.type,
                            matchedText:
                                heading.keyword
                        )
                    }
                }
            }
        }

        return nil
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

        // Wir merken uns zusätzlich den
        // stärksten Einzelbegriff.
        var strongestKeyword:
            String?

        var strongestKeywordScore =
            0.0

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

            let normalMatch =
                normalizedText.contains(
                    normalizedKeyword
                )

            let ocrTolerantMatch =
                isStrongDocumentKeyword(
                    normalizedKeyword
                )
                &&
                compactText(
                    normalizedText
                )
                .contains(
                    compactText(
                        normalizedKeyword
                    )
                )

            guard
                normalMatch
                ||
                ocrTolerantMatch
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
            // MARK: - OCR Tolerant Bonus

            // Wenn eine starke Dokumentbezeichnung nur
            // wegen OCR-Leerzeichen erkannt wurde,
            // ist sie trotzdem ein sehr starkes Signal.
            //
            // Beispiel:
            // "Rech n u ng" -> "Rechnung"
            if !normalMatch,
               ocrTolerantMatch {

                keywordScore +=
                    8.0
            }

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
                    10.0
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

            // Stärkstes einzelnes Merkmal
            // dieser Dokumentart merken.
            if strongestKeyword == nil ||
                keywordScore >
                    strongestKeywordScore {

                strongestKeyword =
                    keyword

                strongestKeywordScore =
                    keywordScore
            }
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
                totalScore,
            strongestKeyword:
                strongestKeyword
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
    // MARK: - OCR Tolerant Document Keywords

    private func isStrongDocumentKeyword(
        _ keyword: String
    ) -> Bool {

        let strongKeywords:
            Set<String> = [
                "rechnung",
                "gutschrift",
                "lieferschein",
                "vertrag",
                "einladung",
                "untersuchung",
                "untersuchungsbericht",
                "schlachtprotokoll",
                "wiegeprotokoll"
            ]

        return strongKeywords.contains(
            keyword
        )
    }

    // MARK: - Compact OCR Text

    private func compactText(
        _ value: String
    ) -> String {

        value
            .replacingOccurrences(
                of:
                    "\\s+",
                with:
                    "",
                options:
                    .regularExpression
            )
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

// MARK: - Internal Classification Result

private struct ClassificationResult {

    let documentType:
        DocumentType

    let score:
        Double

    let strongestKeyword:
        String?
}
