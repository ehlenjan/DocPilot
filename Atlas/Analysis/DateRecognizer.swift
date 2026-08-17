import Foundation

struct DateRecognitionResult {

    let date:
        Date

    let matchedText:
        String
}

struct DateRecognizer {

    // MARK: - Existing Interface

    func detect(
        in text: String
    ) -> Date? {

        detectResult(
            in:
                text
        )?
        .date
    }

    // MARK: - Detailed Result

    func detectResult(
        in text: String
    ) -> DateRecognitionResult? {

        let candidates: [
            (
                pattern: String,
                formats: [String]
            )
        ] = [

            // Numerische Schreibweisen
            (
                #"\b\d{1,2}\.\d{1,2}\.\d{4}\b"#,
                [
                    "d.M.yyyy",
                    "dd.MM.yyyy"
                ]
            ),
            (
                #"\b\d{1,2}\.\d{1,2}\.\d{2}\b"#,
                [
                    "d.M.yy",
                    "dd.MM.yy"
                ]
            ),
            (
                #"\b\d{1,2}-\d{1,2}-\d{4}\b"#,
                [
                    "d-M-yyyy",
                    "dd-MM-yyyy"
                ]
            ),
            (
                #"\b\d{4}-\d{1,2}-\d{1,2}\b"#,
                [
                    "yyyy-M-d",
                    "yyyy-MM-dd"
                ]
            ),

            // Deutsche ausgeschriebene Monatsnamen:
            // 17. August 2026
            // 17 August 2026
            // 4. Mai 2025
            (
                #"(?i)\b\d{1,2}\.?\s+(?:Januar|Februar|März|Maerz|April|Mai|Juni|Juli|August|September|Oktober|November|Dezember)\s+(?:19|20)\d{2}\b"#,
                [
                    "d. MMMM yyyy",
                    "d MMMM yyyy"
                ]
            ),

            // Übliche deutsche Kurzformen:
            // 17. Aug. 2026
            // 17 Aug 2026
            // 3. Sept. 2025
            (
                #"(?i)\b\d{1,2}\.?\s+(?:Jan\.?|Feb\.?|Mär\.?|Mrz\.?|Apr\.?|Mai|Jun\.?|Jul\.?|Aug\.?|Sep\.?|Sept\.?|Okt\.?|Nov\.?|Dez\.?)\s+(?:19|20)\d{2}\b"#,
                [
                    "d. MMM yyyy",
                    "d MMM yyyy"
                ]
            )
        ]

        for candidate in candidates {

            guard
                let range =
                    text.range(
                        of:
                            candidate.pattern,
                        options:
                            .regularExpression
                    )
            else {

                continue
            }

            let dateString =
                String(
                    text[
                        range
                    ]
                )

            let normalizedDateString =
                normalizeGermanDateText(
                    dateString
                )

            for format in
                candidate.formats {

                let formatter =
                    DateFormatter()

                formatter.locale =
                    Locale(
                        identifier:
                            "de_DE"
                    )

                formatter.calendar =
                    Calendar(
                        identifier:
                            .gregorian
                    )

                formatter.dateFormat =
                    format

                formatter.isLenient =
                    false

                guard
                    let date =
                        formatter.date(
                            from:
                                normalizedDateString
                        )
                else {

                    continue
                }

                // MARK: - Year Plausibility

                let calendar =
                    Calendar(
                        identifier:
                            .gregorian
                    )

                let year =
                    calendar.component(
                        .year,
                        from:
                            date
                    )

                // Atlas akzeptiert nur Jahre,
                // die mit 19 oder 20 beginnen.
                //
                // Dadurch werden OCR-Fehler wie
                // 0022, 0224 oder 2204 nicht als
                // Dokumentdatum übernommen.
                guard
                    year >= 1900,
                    year <= 2099
                else {

                    continue
                }

                return DateRecognitionResult(
                    date:
                        date,
                    matchedText:
                        dateString
                )
            }
        }

        return nil
    }

    // MARK: - German Month Normalization

    /// DateFormatter mit de_DE versteht die normalen
    /// deutschen Monatsnamen. Einige OCR-Varianten
    /// normalisieren wir vorher.
    private func normalizeGermanDateText(
        _ value: String
    ) -> String {

        var result =
            value.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        result =
            result.replacingOccurrences(
                of:
                    "Maerz",
                with:
                    "März",
                options:
                    .caseInsensitive
            )

        result =
            result.replacingOccurrences(
                of:
                    "Mrz.",
                with:
                    "Mär.",
                options:
                    .caseInsensitive
            )

        result =
            result.replacingOccurrences(
                of:
                    "Mrz",
                with:
                    "Mär",
                options:
                    .caseInsensitive
            )

        result =
            result.replacingOccurrences(
                of:
                    "Sept.",
                with:
                    "Sep.",
                options:
                    .caseInsensitive
            )

        result =
            result.replacingOccurrences(
                of:
                    "Sept",
                with:
                    "Sep",
                options:
                    .caseInsensitive
            )

        return result
    }
}
