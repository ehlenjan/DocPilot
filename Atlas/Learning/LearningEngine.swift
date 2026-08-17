import Foundation

struct LearningEngine {

    private let manager:
        LearningManager

    init(
        manager: LearningManager =
            LearningManager()
    ) {

        self.manager =
            manager
    }

    // MARK: - Remember

    /// Bestehende Schnittstelle.
    ///
    /// So bleiben bisherige Aufrufe weiterhin gültig.
    func remember(
        analysis: AtlasAnalysis,
        destination: FolderSuggestion
    ) {

        remember(
            analysis:
                analysis,
            destination:
                destination,
            documentText:
                nil
        )
    }

    /// Erweiterte Lernfunktion.
    ///
    /// Zusätzlich zum Analyseergebnis kann Atlas
    /// charakteristische Merkmale aus dem tatsächlichen
    /// Dokumenttext speichern.
    func remember(
        analysis: AtlasAnalysis,
        destination: FolderSuggestion,
        documentText: String?
    ) {

        let signals =
            extractDocumentSignals(
                from:
                    documentText
            )

        let entry =
            LearningEntry(
                company:
                    analysis.sender,
                documentType:
                    analysis.documentType,
                keywords:
                    analysis.keywords,
                documentSignals:
                    signals,
                archiveArea:
                    destination.area,
                folder:
                    destination.folder
            )

        manager.add(
            entry
        )
    }

    // MARK: - Document Signals

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

        // MARK: Tokenize

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

        // MARK: Ignore Common Words

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

        // MARK: Count Tokens

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

            // Reine lange Nummern oder Datumsbestandteile
            // sind für das Wiedererkennen meist wenig hilfreich.
            if token.allSatisfy(
                {
                    $0.isNumber
                }
            ) {

                continue
            }

            counts[token, default: 0] += 1
        }

        // MARK: Rank Signals

        let ranked =
            counts
                .sorted {
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

        // Nicht den kompletten Dokumentinhalt speichern.
        //
        // Für das Matching reichen einige charakteristische
        // Textmerkmale vollkommen aus.
        let maximumSignalCount =
            24

        return Array(
            ranked
                .prefix(
                    maximumSignalCount
                )
                .map {
                    $0.key
                }
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
    }
}
