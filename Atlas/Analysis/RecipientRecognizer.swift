import Foundation

struct RecipientRecognitionResult {

    let area:
        ArchiveArea

    // Exakter Begriff bzw. die Evidenz,
    // über die Atlas den Archivbereich erkannt hat.
    let matchedText:
        String
}

struct RecipientRecognizer {

    // MARK: - Existing Interface

    func detect(
        in text: String
    ) -> ArchiveArea? {

        detectResult(
            in:
                text
        )?
        .area
    }

    // MARK: - Detailed Result

    func detectResult(
        in text: String
    ) -> RecipientRecognitionResult? {

        let normalizedText =
            normalize(
                text
            )

        guard
            !normalizedText.isEmpty
        else {

            return nil
        }

        // MARK: 1. Exakte Erkennung

        // Immer zuerst die spezifischsten
        // Empfänger prüfen.

        if let matchedText =
            firstMatch(
                [
                    "Freiwillige Feuerwehr Kalbe",
                    "Feuerwehr Kalbe"
                ],
                in:
                    normalizedText
            ) {

            return RecipientRecognitionResult(
                area:
                    .fireDepartment,
                matchedText:
                    matchedText
            )
        }

        if let matchedText =
            firstMatch(
                [
                    "EHA KG"
                ],
                in:
                    normalizedText
            ) {

            return RecipientRecognitionResult(
                area:
                    .ehaKG,
                matchedText:
                    matchedText
            )
        }

        if let matchedText =
            firstMatch(
                [
                    "Jan Ehlen"
                ],
                in:
                    normalizedText
            ) {

            return RecipientRecognitionResult(
                area:
                    .business,
                matchedText:
                    matchedText
            )
        }

        // MARK: 2. Fragment-Erkennung

        return detectFromFragments(
            in:
                normalizedText
        )
    }

    // MARK: - Fragment Recognition

    private func detectFromFragments(
        in normalizedText: String
    ) -> RecipientRecognitionResult? {

        // EHA und Ehlen sind unterschiedliche
        // Archividentitäten.
        //
        // Wenn OCR ausnahmsweise beide erkennt,
        // entscheidet Atlas bewusst nicht automatisch.

        let hasEHA =
            containsWord(
                "eha",
                in:
                    normalizedText
            )

        let hasEhlen =
            normalizedText.contains(
                "ehlen"
            )

        if hasEHA && hasEhlen {

            return nil
        }

        // MARK: EHA KG

        // Innerhalb einer gezielt gelesenen
        // archiveIdentityRegion ist "EHA"
        // bereits ein starkes Merkmal.
        //
        // Das vollständige "EHA KG" wurde
        // oben bereits bevorzugt erkannt.

        if hasEHA {

            return RecipientRecognitionResult(
                area:
                    .ehaKG,
                matchedText:
                    "EHA"
            )
        }

        // MARK: Betrieb / Jan Ehlen

        // "Ehlen" allein reicht noch nicht.
        // Es muss mindestens ein weiteres
        // Standortmerkmal vorhanden sein.

        let hasPostalCode =
            normalizedText.contains(
                "27419"
            )

        let hasKalbe =
            normalizedText.contains(
                "kalbe"
            )

        let hasStreet =
            containsStreetFragment(
                in:
                    normalizedText
            )

        if hasEhlen {

            var evidence:
                [String] = [
                    "Ehlen"
                ]

            if hasPostalCode {
                evidence.append(
                    "27419"
                )
            }

            if hasKalbe {
                evidence.append(
                    "Kalbe"
                )
            }

            if hasStreet {
                evidence.append(
                    "Adresse"
                )
            }

            // Ehlen + mindestens ein weiteres
            // passendes Merkmal erforderlich.

            guard
                evidence.count >= 2
            else {

                return nil
            }

            return RecipientRecognitionResult(
                area:
                    .business,
                matchedText:
                    evidence.joined(
                        separator:
                            " + "
                    )
            )
        }

        return nil
    }

    // MARK: - Street Fragments

    private func containsStreetFragment(
        in normalizedText: String
    ) -> Bool {

        let fragments = [
            "dorfstr",
            "dorf str",
            "dorfstraße",
            "dorfstrasse"
        ]

        return fragments.contains {
            fragment in

            normalizedText.contains(
                normalize(
                    fragment
                )
            )
        }
    }

    // MARK: - Whole Word Matching

    private func containsWord(
        _ word: String,
        in normalizedText: String
    ) -> Bool {

        let escaped =
            NSRegularExpression
                .escapedPattern(
                    for:
                        normalize(
                            word
                        )
                )

        let pattern =
            #"(?<![\p{L}\p{N}])"# +
            escaped +
            #"(?![\p{L}\p{N}])"#

        guard
            let regex =
                try? NSRegularExpression(
                    pattern:
                        pattern,
                    options: []
                )
        else {

            return false
        }

        let range =
            NSRange(
                normalizedText.startIndex...,
                in:
                    normalizedText
            )

        return regex.firstMatch(
            in:
                normalizedText,
            options: [],
            range:
                range
        ) != nil
    }

    // MARK: - Matching

    private func firstMatch(
        _ values: [String],
        in normalizedText: String
    ) -> String? {

        for value in values {

            let normalizedValue =
                normalize(
                    value
                )

            guard
                !normalizedValue.isEmpty
            else {

                continue
            }

            if normalizedText.contains(
                normalizedValue
            ) {

                return value
            }
        }

        return nil
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
