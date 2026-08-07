import Foundation
import Observation

@MainActor
@Observable
final class InboxViewModel {

    private let folderStore = InboxFolderStore()
    private let filenameSuggestionService = FilenameSuggestionService()
    private let pdfTextExtractionService = PDFTextExtractionService()
    private let atlasAnalyzer = AtlasAnalyzer()
    private let autoAnalysisService = AutoAnalysisService()
    private let archiveLocationsStore = ArchiveLocationsStore()
    private let documentMoveService = DocumentMoveService()
    private let archiveScanner = ArchiveScanner()

    private let folderSuggestionEngine: FolderSuggestionEngine = {
        let knowledgeBase: KnowledgeBase

        do {
            knowledgeBase = try KnowledgeBase.load()
        } catch {
            print(
                "KnowledgeBase konnte für Ordnervorschläge nicht geladen werden: \(error.localizedDescription)"
            )

            knowledgeBase = KnowledgeBase(
                companies: [],
                documentTypes: [],
                folderRules: []
            )
        }

        return FolderSuggestionEngine(
            knowledgeBase: knowledgeBase
        )
    }()

    var documents: [DocumentRecord] = []
    var errorMessage: String?

    var extractedText = ""
    var textExtractionMessage: String?

    var analysis: AtlasAnalysis?
    var folderSuggestion: FolderSuggestion?

    var isAnalyzing = false
    var isArchiving = false

    private var analysesByURL: [URL: AtlasAnalysis] = [:]
    private var folderSuggestionsByURL: [URL: FolderSuggestion] = [:]

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

            let availableURLs = Set(
                documents.map(\.sourceURL)
            )

            analysesByURL = analysesByURL.filter {
                availableURLs.contains($0.key)
            }

            folderSuggestionsByURL =
                folderSuggestionsByURL.filter {
                    availableURLs.contains($0.key)
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
                Task {
                    await self.analyzeSilently(
                        document: document
                    )
                }
            }
        )
    }

    private func analyzeSilently(
        document: DocumentRecord
    ) async {
        do {
            let text = try await pdfTextExtractionService.extractText(
                from: document.sourceURL
            )

            let newAnalysis = atlasAnalyzer.analyze(
                text: text
            )

            let newFolderSuggestion =
                folderSuggestionEngine.suggestFolder(
                    for: newAnalysis,
                    text: text
                )

            analysesByURL[document.sourceURL] =
                newAnalysis

            folderSuggestionsByURL[document.sourceURL] =
                newFolderSuggestion

            if analysis == nil {
                analysis = newAnalysis
                folderSuggestion = newFolderSuggestion
            }

        } catch {
            // Reine Bildscans oder nicht lesbare PDFs
            // können später genauer protokolliert werden.
        }
    }

    func analyze(document: DocumentRecord) {
        Task {
            await analyzeAsync(
                document: document
            )
        }
    }

    private func analyzeAsync(
        document: DocumentRecord
    ) async {
        isAnalyzing = true

        defer {
            isAnalyzing = false
        }

        extractedText = ""
        textExtractionMessage = nil
        analysis = nil
        folderSuggestion = nil

        do {
            let text = try await pdfTextExtractionService.extractText(
                from: document.sourceURL
            )

            extractedText = text

            textExtractionMessage =
                "\(text.count) Zeichen aus dem PDF gelesen."

            let newAnalysis = atlasAnalyzer.analyze(
                text: text
            )

            let newFolderSuggestion =
                folderSuggestionEngine.suggestFolder(
                    for: newAnalysis,
                    text: text
                )

            analysis = newAnalysis
            folderSuggestion = newFolderSuggestion

            analysesByURL[document.sourceURL] =
                newAnalysis

            folderSuggestionsByURL[document.sourceURL] =
                newFolderSuggestion

        } catch {
            textExtractionMessage =
                error.localizedDescription
        }
    }

    func analysis(
        for document: DocumentRecord
    ) -> AtlasAnalysis? {
        analysesByURL[document.sourceURL]
    }

    func folderSuggestion(
        for document: DocumentRecord
    ) -> FolderSuggestion? {
        folderSuggestionsByURL[document.sourceURL]
    }

    func selectAnalysis(
        for document: DocumentRecord?
    ) {
        guard let document else {
            clearAnalysis()
            return
        }

        analysis = analysesByURL[document.sourceURL]

        folderSuggestion =
            folderSuggestionsByURL[document.sourceURL]

        extractedText = ""

        textExtractionMessage = analysis == nil
            ? nil
            : "Analyse ist für dieses Dokument bereits vorhanden."
    }

    func clearAnalysis() {
        extractedText = ""
        textExtractionMessage = nil
        analysis = nil
        folderSuggestion = nil
        isAnalyzing = false
    }

    func suggestFilename(
        for document: DocumentRecord
    ) -> String {
        let documentAnalysis =
            analysesByURL[document.sourceURL] ?? analysis

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
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

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
                analysesByURL[document.sourceURL]

            let previousFolderSuggestion =
                folderSuggestionsByURL[document.sourceURL]

            try FileManager.default.moveItem(
                at: document.sourceURL,
                to: destinationURL
            )

            analysesByURL.removeValue(
                forKey: document.sourceURL
            )

            folderSuggestionsByURL.removeValue(
                forKey: document.sourceURL
            )

            if let previousAnalysis {
                analysesByURL[destinationURL] =
                    previousAnalysis
            }

            if let previousFolderSuggestion {
                folderSuggestionsByURL[destinationURL] =
                    previousFolderSuggestion
            }

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

    func archive(
        document: DocumentRecord
    ) -> Bool {
        errorMessage = nil
        isArchiving = true

        defer {
            isArchiving = false
        }

        let suggestion =
            folderSuggestionsByURL[document.sourceURL]
            ?? folderSuggestion

        guard let suggestion else {
            errorMessage =
                "Es ist noch kein Zielordner vorhanden."
            return false
        }

        guard let archiveRootURL =
            archiveLocationsStore.folderURL(
                for: suggestion.area
            )
        else {
            errorMessage =
                "Für \(suggestion.area.rawValue) wurde noch kein Archivort ausgewählt."
            return false
        }

        do {
            let rootNode = try archiveScanner.scan(
                rootURL: archiveRootURL
            )

            guard let targetNode = findArchiveNode(
                in: rootNode,
                area: suggestion.area,
                folder: suggestion.folder
            ) else {
                errorMessage =
                    "Der vorgeschlagene Zielordner \(suggestion.displayPath) wurde im Archiv nicht gefunden."
                return false
            }

            _ = try documentMoveService.move(
                document: document,
                to: targetNode
            )

            analysesByURL.removeValue(
                forKey: document.sourceURL
            )

            folderSuggestionsByURL.removeValue(
                forKey: document.sourceURL
            )

            loadDocuments()
            clearAnalysis()

            return true

        } catch {
            errorMessage =
                error.localizedDescription
            return false
        }
    }
    func removeFolder() {
        folderStore.removeFolder()

        documents = []
        analysesByURL = [:]
        folderSuggestionsByURL = [:]

        clearAnalysis()

        errorMessage = nil
    }
    private func findArchiveNode(
        in node: ArchiveNode,
        area: ArchiveArea,
        folder: String
    ) -> ArchiveNode? {

        let normalizedArea = normalize(area.rawValue)
        let normalizedFolder = normalize(folder)

        for areaNode in node.children {

            guard normalize(areaNode.name) == normalizedArea else {
                continue
            }

            if normalize(areaNode.name) == normalizedFolder {
                return areaNode
            }

            if let folderNode = areaNode.children.first(
                where: {
                    normalize($0.name) == normalizedFolder
                }
            ) {
                return folderNode
            }

            if let nested = findNode(
                named: normalizedFolder,
                in: areaNode
            ) {
                return nested
            }
        }

        return nil
    }

    private func findNode(
        named normalizedName: String,
        in node: ArchiveNode
    ) -> ArchiveNode? {

        for child in node.children {

            if normalize(child.name) == normalizedName {
                return child
            }

            if let nested = findNode(
                named: normalizedName,
                in: child
            ) {
                return nested
            }
        }

        return nil
    }

    private func normalize(
        _ value: String
    ) -> String {

        value
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive
                ],
                locale: Locale(identifier: "de_DE")
            )
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
