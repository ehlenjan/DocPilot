import Foundation
import Observation

@Observable
final class InboxViewModel {

    private let folderStore = InboxFolderStore()
    private let filenameSuggestionService = FilenameSuggestionService()
    private let pdfTextExtractionService = PDFTextExtractionService()
    private let atlasAnalyzer = AtlasAnalyzer()
    private let autoAnalysisService = AutoAnalysisService()

    var documents: [DocumentRecord] = []
    var errorMessage: String?

    var extractedText: String = ""
    var textExtractionMessage: String?

    var analysis: AtlasAnalysis?

    private var analysesByDocumentID: [UUID: AtlasAnalysis] = [:]

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

            analysesByDocumentID = analysesByDocumentID.filter { entry in
                documents.contains { document in
                    document.id == entry.key
                }
            }

            autoAnalyzeDocuments()

        } catch {
            documents = []
            errorMessage =
                "Die Dateien konnten nicht gelesen werden: \(error.localizedDescription)"
        }
    }

    private func autoAnalyzeDocuments() {
        autoAnalysisService.analyzeIfNeeded(
            documents: documents,
            alreadyAnalyzed: { document in
                self.analysis(for: document) != nil
            },
            analyze: { document in
                self.analyzeInBackgroundStyle(document: document)
            }
        )
    }

    private func analyzeInBackgroundStyle(
        document: DocumentRecord
    ) {
        do {
            let text = try pdfTextExtractionService.extractText(
                from: document.sourceURL
            )

            let newAnalysis = atlasAnalyzer.analyze(text: text)

            analysesByDocumentID[document.id] = newAnalysis

        } catch {
            // Reine Scans ohne eingebetteten Text werden später per OCR analysiert.
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

            let newAnalysis = atlasAnalyzer.analyze(text: text)

            analysis = newAnalysis
            analysesByDocumentID[document.id] = newAnalysis

        } catch {
            textExtractionMessage = error.localizedDescription
        }
    }

    func analysis(
        for document: DocumentRecord
    ) -> AtlasAnalysis? {
        analysesByDocumentID[document.id]
    }

    func selectAnalysis(
        for document: DocumentRecord?
    ) {
        guard let document else {
            analysis = nil
            extractedText = ""
            textExtractionMessage = nil
            return
        }

        analysis = analysesByDocumentID[document.id]
        extractedText = ""

        textExtractionMessage = analysis == nil
            ? nil
            : "Analyse ist für dieses Dokument bereits vorhanden."
    }

    func clearAnalysis() {
        extractedText = ""
        textExtractionMessage = nil
        analysis = nil
    }

    func suggestFilename(
        for document: DocumentRecord
    ) -> String {
        let documentAnalysis =
            analysesByDocumentID[document.id] ?? analysis

        guard let documentAnalysis else {
            return filenameSuggestionService.suggestFilename(
                for: document
            )
        }

        return buildFilenameSuggestion(
            from: documentAnalysis,
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
            errorMessage =
                "Der neue Dateiname darf nicht leer sein."
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
            let previousAnalysis =
                analysesByDocumentID[document.id]

            try FileManager.default.moveItem(
                at: document.sourceURL,
                to: destinationURL
            )

            loadDocuments()

            guard let renamedDocument = documents.first(
                where: { $0.sourceURL == destinationURL }
            ) else {
                return nil
            }

            if let previousAnalysis {
                analysesByDocumentID[renamedDocument.id] =
                    previousAnalysis
            }

            analysesByDocumentID.removeValue(
                forKey: document.id
            )

            return renamedDocument

        } catch {
            errorMessage =
                "Die Datei konnte nicht umbenannt werden: \(error.localizedDescription)"
            return nil
        }
    }

    func removeFolder() {
        folderStore.removeFolder()
        documents = []
        analysesByDocumentID = [:]
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
            parts.append(
                formatter.string(from: date)
            )
        }

        if analysis.documentType != .unknown {
            parts.append(
                analysis.documentType.rawValue
            )
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
