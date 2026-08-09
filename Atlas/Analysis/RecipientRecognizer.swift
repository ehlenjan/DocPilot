import Foundation

struct RecipientRecognizer {

    func detect(
        in text: String
    ) -> ArchiveArea? {

        let normalizedText =
            normalize(text)

        // Wichtig:
        // Immer zuerst die spezifischsten Empfänger prüfen.
        //
        // Feuerwehr-Dokumente können ebenfalls
        // "Jan Ehlen" enthalten. Deshalb muss
        // "Feuerwehr Kalbe" vor "Jan Ehlen"
        // ausgewertet werden.

        if containsAny(
            [
                "Feuerwehr Kalbe",
                "Freiwillige Feuerwehr Kalbe"
            ],
            in: normalizedText
        ) {
            return .fireDepartment
        }

        // EHA KG und Betrieb haben dieselbe Adresse.
        // Deshalb ist der Firmenname hier das
        // entscheidende Merkmal.

        if containsAny(
            [
                "EHA KG"
            ],
            in: normalizedText
        ) {
            return .ehaKG
        }

        // Erst danach Jan Ehlen prüfen.
        // So wird ein Feuerwehr-Dokument mit
        // "Feuerwehr Kalbe" und "Jan Ehlen"
        // nicht versehentlich dem Betrieb zugeordnet.

        if containsAny(
            [
                "Jan Ehlen"
            ],
            in: normalizedText
        ) {
            return .business
        }

        return nil
    }

    // MARK: - Matching

    private func containsAny(
        _ values: [String],
        in normalizedText: String
    ) -> Bool {

        values.contains { value in
            normalizedText.contains(
                normalize(value)
            )
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
