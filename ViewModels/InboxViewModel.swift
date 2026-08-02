import Foundation
import Observation

@Observable
final class InboxViewModel {

    private let folderStore = InboxFolderStore()
    private let filenameSuggestionService = FilenameSuggestionService()
    private let pdfTextExtractionService = PDFTextExtractionService()
    private let atlasAnalyzer = AtlasAnalyzer()

    var documents: [DocumentRecord] = []
    var errorMessage: String?

    var extractedText: String = ""
    var textExtractionMessage: String?

    var analysis: AtlasAnalysis?

    var folderURL: URL? {
        folderStore.folderURL
    }

    func selectFolder(_ url: URL) {
        folderStore.saveFolder(url)
        loadDocuments()
    }

    func loadDocuments() {
        errorMessage = nil

        guard let folderURL else {
            documents = []
            return
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            documents = files
                .filter {
                    $0.pathExtension.lowercased() == "pdf"
                }
                .sorted {
                    $0.lastPathComponent.localizedStandardCompare(
                        $1.lastPathComponent
                    ) == .orderedAscending
                }
                .map {
                    DocumentRecord(sourceURL: $0)
                }

        } catch {
            documents = []
            errorMessage =
                "Die Dateien konnten nicht gelesen werden: \(error.localizedDescription)"
        }
    }

    func analyze(document: DocumentRecord) {
        extractedText = ""
        textExtractionMessage = nil
        analysis = nil

        do {
            let text = try pdfTextExtractionService.extractText(
                from: document.sourceURL
            )

            extractedText = text
            textExtractionMessage =
                "\(text.count) Zeichen aus dem PDF gelesen."

            analysis = atlasAnalyzer.analyze(text: text)

        } catch {
            textExtractionMessage = error.localizedDescription
        }
    }

    func clearAnalysis() {
        extractedText = ""
        textExtractionMessage = nil
        analysis = nil
    }

    func suggestFilename(
        for document: DocumentRecord
    ) -> String {
        guard let analysis else {
            return filenameSuggestionService.suggestFilename(
                for: document
            )
        }

        return buildFilenameSuggestion(
            from: analysis,
            fallbackDocument: document
        )
    }

    func rename(
        document: DocumentRecord,
        to newFilename: String
    ) -> DocumentRecord? {
        errorMessage = nil

        let cleanedName = newFilename
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedName.isEmpty else {
            errorMessage = "Der neue Dateiname darf nicht leer sein."
            return nil
        }

        let destinationURL = document.sourceURL
            .deletingLastPathComponent()
            .appendingPathComponent(cleanedName)
            .appendingPathExtension("pdf")

        guard destinationURL != document.sourceURL else {
            return document
        }

        guard !FileManager.default.fileExists(
            atPath: destinationURL.path
        ) else {
            errorMessage =
                "Eine Datei mit diesem Namen existiert bereits."
            return nil
        }

        do {
            try FileManager.default.moveItem(
                at: document.sourceURL,
                to: destinationURL
            )

            loadDocuments()

            return documents.first {
                $0.sourceURL == destinationURL
            }

        } catch {
            errorMessage =
                "Die Datei konnte nicht umbenannt werden: \(error.localizedDescription)"
            return nil
        }
    }

    func removeFolder() {
        folderStore.removeFolder()
        documents = []
        clearAnalysis()
        errorMessage = nil
    }

    private func buildFilenameSuggestion(
        from analysis: AtlasAnalysis,
        fallbackDocument: DocumentRecord
    ) -> String {
        var parts: [String] = []

        if let date = analysis.detectedDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            parts.append(formatter.string(from: date))
        }

        if analysis.documentType != .unknown {
            parts.append(analysis.documentType.rawValue)
        }

        if let sender = analysis.sender {
            parts.append(sender)
        }

        if parts.isEmpty {
            return filenameSuggestionService.suggestFilename(
                for: fallbackDocument
            )
        }

        return parts.joined(separator: " ")
    }
}
