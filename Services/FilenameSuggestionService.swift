import Foundation

struct FilenameSuggestionService {

    func suggestFilename(for document: DocumentRecord) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let date = dateFormatter.string(from: Date())

        let originalName = document.sourceURL
            .deletingPathExtension()
            .lastPathComponent

        let cleanedName = clean(originalName)

        if cleanedName.isEmpty || isGenericScanName(cleanedName) {
            return "\(date) Dokument"
        }

        return "\(date) \(cleanedName)"
    }

    private func clean(_ filename: String) -> String {
        filename
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isGenericScanName(_ filename: String) -> Bool {
        let normalized = filename.lowercased()

        let genericPrefixes = [
            "scan",
            "scann",
            "document",
            "dokument",
            "img",
            "image"
        ]

        return genericPrefixes.contains {
            normalized.hasPrefix($0)
        }
    }
}
