import Foundation

struct LearningMatch {

    let entry:
        LearningEntry

    let score:
        Int

    let companyMatched:
        Bool

    let documentTypeMatched:
        Bool

    let keywordMatches:
        Int

    let documentSignalMatches:
        Int

    let usageCount:
        Int

    /// Ein gelernter Treffer darf erst dann
    /// aktiv in die Dokumentanalyse eingreifen,
    /// wenn er mehrfach bestätigt wurde und
    /// genügend Dokumentmerkmale übereinstimmen.
    var canApplyToAnalysis:
        Bool {

        usageCount >= 3
        &&
        documentSignalMatches >= 3
        &&
        score >= 45
    }
}

// MARK: - Learning Matcher

struct LearningMatcher {

    func bestMatch(
        for analysis: AtlasAnalysis,
        entries: [LearningEntry],
        documentText: String? = nil
    ) -> LearningMatch? {

        let currentDocumentSignals =
            extractDocumentSignals(
                from:
                    documentText
            )

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

            let documentSignalMatches =
                matchingDocumentSignalCount(
                    currentSignals:
                        currentDocumentSignals,
                    learnedSignals:
                        entry.documentSignals
                )

            // MARK: Mindestähnlichkeit

            // Gleiche Dokumentart allein reicht nicht.
            //
            // Es muss entweder
            // - dieselbe Firma,
            // - mindestens ein Keyword
            // - oder ein deutlicher Dokument-Signal-Treffer
            // vorhanden sein.
            guard
                companyMatched
                ||
                keywordMatches > 0
                ||
                documentSignalMatches >= 2
            else {

                continue
            }

            var score =
                0

            // Firma bleibt stark.
            if companyMatched {

                score +=
                    60
            }

            // Dokumenttyp verstärkt einen
            // bereits plausiblen Treffer.
            if documentTypeMatched {

                score +=
                    20
            }

            // Bekannte Atlas-Schlüsselwörter.
            score +=
                min(
                    keywordMatches * 8,
                    32
                )

            // Gelernte Textmerkmale.
            score +=
                min(
                    documentSignalMatches * 7,
                    49
                )

            // Mehrfach bestätigtes Lernen.
            score +=
                experienceBonus(
                    for:
                        entry.usageCount
                )

            guard
                score >= 35
            else {

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
                    documentSignalMatches:
                        documentSignalMatches,
                    usageCount:
                        entry.usageCount
                )

            if bestMatch == nil
                ||
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

        return normalize(
            analysisSender
        )
        ==
        normalize(
            learnedCompany
        )
    }

    // MARK: - Keywords

    private func matchingKeywordCount(
        analysisKeywords: [String],
        learnedKeywords: [String]
    ) -> Int {

        let learned =
            Set(
                learnedKeywords.map {
                    normalize(
                        $0
                    )
                }
            )

        return analysisKeywords.reduce(
            into:
                0
        ) {
            count,
            keyword in

            if learned.contains(
                normalize(
                    keyword
                )
            ) {

                count +=
                    1
            }
        }
    }

    // MARK: - Document Signals

    private func matchingDocumentSignalCount(
        currentSignals: [String],
        learnedSignals: [String]
    ) -> Int {

        guard
            !currentSignals.isEmpty,
            !learnedSignals.isEmpty
        else {

            return 0
        }

        let learned =
            Set(
                learnedSignals.map {
                    normalize(
                        $0
                    )
                }
            )

        var matches =
            0

        for signal in currentSignals {

            if learned.contains(
                normalize(
                    signal
                )
            ) {

                matches +=
                    1
            }
        }

        return matches
    }

    // MARK: - Extract Signals

    private func extractDocumentSignals(
        from text: String?
    ) -> [String] {

        guard
            let text
        else {

            return []
        }

        let normalizedText =
            normalize(
                text
            )

        guard
            !normalizedText.isEmpty
        else {

            return []
        }

        let rawTokens =
            normalizedText
                .components(
                    separatedBy:
                        CharacterSet
                            .alphanumerics
                            .inverted
                )
                .filter {
                    !$0.isEmpty
                }

        let ignoredWords:
            Set<String> = [

                "der",
                "die",
                "das",
                "den",
                "dem",
                "des",

                "ein",
                "eine",
                "einer",
                "einem",
                "einen",

                "und",
                "oder",
                "von",
                "vom",
                "für",
                "mit",
                "auf",
                "aus",
                "bei",
                "zur",
                "zum",
                "im",
                "in",

                "ist",
                "sind",
                "wird",
                "werden",

                "seite",
                "datum",
                "name",
                "anschrift",

                "ja",
                "nein",

                "nr",
                "nummer"
            ]

        var counts:
            [String: Int] = [:]

        for token in rawTokens {

            guard
                token.count >= 4
            else {

                continue
            }

            guard
                !ignoredWords.contains(
                    token
                )
            else {

                continue
            }

            if token.allSatisfy(
                {
                    $0.isNumber
                }
            ) {

                continue
            }

            counts[
                token,
                default:
                    0
            ] +=
                1
        }

        let ranked =
            counts.sorted {
                first,
                second in

                if first.value !=
                    second.value {

                    return first.value >
                        second.value
                }

                if first.key.count !=
                    second.key.count {

                    return first.key.count >
                        second.key.count
                }

                return first.key <
                    second.key
            }

        return Array(
            ranked
                .prefix(
                    24
                )
                .map {
                    $0.key
                }
        )
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
            return 7

        case 3..<5:
            return 5

        case 2:
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
            .lowercased()
    }
}
