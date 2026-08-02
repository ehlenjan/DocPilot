import Foundation
import Observation

@Observable
final class InboxViewModel {

    private let folderStore = InboxFolderStore()
    private let filenameSuggestionService = FilenameSuggestionService()
    private let pdfTextExtractionService = PDFTextExtractionService()

    var documents: [DocumentRecord] = []
    var errorMessage: String?

    var extractedText: String = ""
    var textExtractionMessage: String?

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

    func extractText(from document: DocumentRecord) {
        extractedText = ""
        textExtractionMessage = nil

        do {
            extractedText = try pdfTextExtractionService.extractText(
                from: document.sourceURL
            )

            textExtractionMessage =
                "\(extractedText.count) Zeichen aus dem PDF gelesen."

        } catch {
            textExtractionMessage = error.localizedDescription
        }
    }

    func clearExtractedText() {
        extractedText = ""
        textExtractionMessage = nil
    }

    func suggestFilename(
        for document: DocumentRecord
    ) -> String {
        filenameSuggestionService.suggestFilename(
            for: document
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
        extractedText = ""
        textExtractionMessage = nil
        errorMessage = nil
    }
}
