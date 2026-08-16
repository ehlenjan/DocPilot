import Foundation

struct LayoutDateRecognizer {

    // MARK: - Result

    struct Result {

        let date: Date
        let matchedText: String
        let confirmations: Int
    }

    // MARK: - Recognize

    func recognize(
        from text: String
    ) -> Result? {

        let candidates =
            extractDates(
                from: text
            )

        guard
            !candidates.isEmpty
        else {
            return nil
        }

        let grouped =
            Dictionary(
                grouping:
                    candidates,
                by: {
                    dateKey(
                        $0.date
                    )
                }
            )

        guard
            let bestGroup =
                grouped.values.max(
                    by: {
                        $0.count <
                            $1.count
                    }
                ),
            let first =
                bestGroup.first
        else {
            return nil
        }

        // Sicherheitsregel:
        // Mindestens zwei unabhängige
        // OCR-Varianten müssen dasselbe
        // vollständige Datum liefern.
        guard
            bestGroup.count >= 2
        else {
            return nil
        }

        return Result(
            date:
                first.date,
            matchedText:
                first.text,
            confirmations:
                bestGroup.count
        )
    }

    // MARK: - Extract Dates

    private func extractDates(
        from text: String
    ) -> [DateCandidate] {

        let patterns = [

            // 15.7.24
            // 15.07.24
            #"\b([0-3]?\d)\s*\.\s*([01]?\d)\s*\.\s*(\d{2})\b"#,

            // 15.7.2024
            // 15.07.2024
            #"\b([0-3]?\d)\s*\.\s*([01]?\d)\s*\.\s*(20\d{2})\b"#,

            // 15/7/24
            #"\b([0-3]?\d)\s*/\s*([01]?\d)\s*/\s*(\d{2})\b"#,

            // 15/7/2024
            #"\b([0-3]?\d)\s*/\s*([01]?\d)\s*/\s*(20\d{2})\b"#,

            // 15-7-24
            #"\b([0-3]?\d)\s*-\s*([01]?\d)\s*-\s*(\d{2})\b"#,

            // 15-7-2024
            #"\b([0-3]?\d)\s*-\s*([01]?\d)\s*-\s*(20\d{2})\b"#
        ]

        var results:
            [DateCandidate] = []

        for pattern in patterns {

            guard
                let regex =
                    try? NSRegularExpression(
                        pattern:
                            pattern
                    )
            else {
                continue
            }

            let range =
                NSRange(
                    text.startIndex...,
                    in:
                        text
                )

            let matches =
                regex.matches(
                    in:
                        text,
                    range:
                        range
                )

            for match in matches {

                guard
                    match.numberOfRanges >= 4,
                    let fullRange =
                        Range(
                            match.range(
                                at: 0
                            ),
                            in:
                                text
                        ),
                    let dayRange =
                        Range(
                            match.range(
                                at: 1
                            ),
                            in:
                                text
                        ),
                    let monthRange =
                        Range(
                            match.range(
                                at: 2
                            ),
                            in:
                                text
                        ),
                    let yearRange =
                        Range(
                            match.range(
                                at: 3
                            ),
                            in:
                                text
                        )
                else {
                    continue
                }

                guard
                    let day =
                        Int(
                            text[
                                dayRange
                            ]
                        ),
                    let month =
                        Int(
                            text[
                                monthRange
                            ]
                        ),
                    var year =
                        Int(
                            text[
                                yearRange
                            ]
                        )
                else {
                    continue
                }

                if year < 100 {
                    year += 2000
                }

                guard
                    let date =
                        makeDate(
                            day:
                                day,
                            month:
                                month,
                            year:
                                year
                        )
                else {
                    continue
                }

                results.append(
                    DateCandidate(
                        date:
                            date,
                        text:
                            String(
                                text[
                                    fullRange
                                ]
                            )
                    )
                )
            }
        }

        return results
    }

    // MARK: - Date Validation

    private func makeDate(
        day: Int,
        month: Int,
        year: Int
    ) -> Date? {

        guard
            year >= 2000,
            year <= 2100,
            month >= 1,
            month <= 12,
            day >= 1,
            day <= 31
        else {
            return nil
        }

        var calendar =
            Calendar(
                identifier:
                    .gregorian
            )

        calendar.timeZone =
            TimeZone(
                secondsFromGMT:
                    0
            )!

        var components =
            DateComponents()

        components.year =
            year

        components.month =
            month

        components.day =
            day

        guard
            let date =
                calendar.date(
                    from:
                        components
                )
        else {
            return nil
        }

        let check =
            calendar.dateComponents(
                [
                    .year,
                    .month,
                    .day
                ],
                from:
                    date
            )

        guard
            check.year == year,
            check.month == month,
            check.day == day
        else {
            return nil
        }

        return date
    }

    // MARK: - Date Key

    private func dateKey(
        _ date: Date
    ) -> String {

        var calendar =
            Calendar(
                identifier:
                    .gregorian
            )

        calendar.timeZone =
            TimeZone(
                secondsFromGMT:
                    0
            )!

        let components =
            calendar.dateComponents(
                [
                    .year,
                    .month,
                    .day
                ],
                from:
                    date
            )

        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

// MARK: - Candidate

private struct DateCandidate {

    let date:
        Date

    let text:
        String
}
