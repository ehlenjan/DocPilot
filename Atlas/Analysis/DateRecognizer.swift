import Foundation

struct DateRecognizer {

    func detect(in text: String) -> Date? {

        let patterns = [
            #"\b\d{2}\.\d{2}\.\d{4}\b"#,
            #"\b\d{2}\.\d{2}\.\d{2}\b"#,
            #"\b\d{4}-\d{2}-\d{2}\b"#
        ]

        for pattern in patterns {

            guard let range = text.range(
                of: pattern,
                options: .regularExpression
            ) else {
                continue
            }

            let dateString = String(text[range])

            let formats = [
                "dd.MM.yyyy",
                "dd.MM.yy",
                "yyyy-MM-dd"
            ]

            for format in formats {

                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "de_DE")
                formatter.dateFormat = format

                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
        }

        return nil
    }
}
