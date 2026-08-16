import Foundation

struct DateRecognitionResult {

    let date: Date
    let matchedText: String
}

struct DateRecognizer {

    // MARK: - Existing Interface

    func detect(
        in text: String
    ) -> Date? {

        detectResult(
            in: text
        )?
        .date
    }

    // MARK: - Detailed Result

    func detectResult(
        in text: String
    ) -> DateRecognitionResult? {

        let patterns = [
            #"\b\d{2}\.\d{2}\.\d{4}\b"#,
            #"\b\d{2}\.\d{2}\.\d{2}\b"#,
            #"\b\d{2}-\d{2}-\d{4}\b"#,
            #"\b\d{4}-\d{2}-\d{2}\b"#
        ]

        let formats = [
            "dd.MM.yyyy",
            "dd.MM.yy",
            "dd-MM-yyyy",
            "yyyy-MM-dd"
        ]

        for pattern in patterns {

            guard let range =
                text.range(
                    of: pattern,
                    options: .regularExpression
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

            for format in formats {

                let formatter =
                    DateFormatter()

                formatter.locale =
                    Locale(
                        identifier:
                            "de_DE"
                    )

                formatter.dateFormat =
                    format

                formatter.isLenient =
                    false

                if let date =
                    formatter.date(
                        from:
                            dateString
                    ) {

                    return DateRecognitionResult(
                        date:
                            date,
                        matchedText:
                            dateString
                    )
                }
            }
        }

        return nil
    }
}
