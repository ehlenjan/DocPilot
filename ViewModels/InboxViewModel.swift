import Foundation
import Observation

@MainActor
@Observable
final class InboxViewModel {

    private let folderStore =
        InboxFolderStore()

    private let filenameSuggestionService =
        FilenameSuggestionService()

    private let pdfTextExtractionService =
        PDFTextExtractionService()

    private let atlasAnalyzer =
        AtlasAnalyzer()

    private let autoAnalysisService =
        AutoAnalysisService()

    private let archiveWorkspaceStore =
        ArchiveWorkspaceStore()

    private let archiveDestinationResolver =
        ArchiveDestinationResolver()

    private let archiveFileMover =
        ArchiveFileMover()

    private let folderSuggestionEngine:
        FolderSuggestionEngine = {

        let knowledgeBase:
            KnowledgeBase

        do {
            knowledgeBase =
                try KnowledgeBase.load()
        } catch {

            print(
                "KnowledgeBase konnte für Ordnervorschläge nicht geladen werden: \(error.localizedDescription)"
            )

            knowledgeBase =
                KnowledgeBase(
                    companies: [],
                    documentTypes: [],
                    folderRules: []
                )
        }

        return FolderSuggestionEngine(
            knowledgeBase: knowledgeBase
        )
    }()

    var documents:
        [DocumentRecord] = []

    var errorMessage:
        String?

    var extractedText = ""

    var textExtractionMessage:
        String?

    var analysis:
        AtlasAnalysis?

    var folderSuggestion:
        FolderSuggestion?

    var isAnalyzing =
        false

    var isArchiving =
        false

    // Manuell gewähltes Archivziel
    var manualArchiveDestinationURL:
        URL?

    private var analysesByURL:
        [URL: AtlasAnalysis] = [:]

    private var folderSuggestionsByURL:
        [URL: FolderSuggestion] = [:]

    var folderURL: URL? {
        folderStore.folderURL
    }

    // MARK: - Folder

    func selectFolder(
        _ url: URL
    ) {
        folderStore.saveFolder(url)
        loadDocuments()
    }

    // MARK: - Documents

    func loadDocuments() {

        errorMessage = nil

        guard let folderURL else {
            documents = []
            return
        }

        do {

            let files =
                try FileManager.default
                    .contentsOfDirectory(
                        at: folderURL,
                        includingPropertiesForKeys: [
                            .isRegularFileKey
                        ],
                        options: [
                            .skipsHiddenFiles
                        ]
                    )

            documents =
                files
                    .filter {
                        $0.pathExtension
                            .lowercased() == "pdf"
                    }
                    .sorted {
                        $0.lastPathComponent
                            .localizedStandardCompare(
                                $1.lastPathComponent
                            ) == .orderedAscending
                    }
                    .map {
                        DocumentRecord(
                            sourceURL: $0
                        )
                    }

            let availableURLs =
                Set(
                    documents.map(
                        \.sourceURL
                    )
                )

            analysesByURL =
                analysesByURL.filter {
                    availableURLs.contains(
                        $0.key
                    )
                }

            folderSuggestionsByURL =
                folderSuggestionsByURL.filter {
                    availableURLs.contains(
                        $0.key
                    )
                }

            autoAnalyzeDocuments()

        } catch {

            documents = []

            errorMessage =
                "Die Dateien konnten nicht gelesen werden: \(error.localizedDescription)"
        }
    }

    // MARK: - Automatic Analysis

    private func autoAnalyzeDocuments() {

        autoAnalysisService
            .analyzeIfNeeded(
                documents: documents,
                alreadyAnalyzed: {
                    document in

                    self.analysis(
                        for: document
                    ) != nil
                },
                analyze: {
                    document in

                    Task {
                        await self
                            .analyzeSilently(
                                document:
                                    document
                            )
                    }
                }
            )
    }

    private func analyzeSilently(
        document: DocumentRecord
    ) async {

        do {

            let text =
                try await
                    pdfTextExtractionService
                        .extractText(
                            from:
                                document.sourceURL
                        )

            let newAnalysis =
                atlasAnalyzer.analyze(
                    text: text
                )

            let newFolderSuggestion =
                folderSuggestionEngine
                    .suggestFolder(
                        for:
                            newAnalysis,
                        text:
                            text
                    )

            analysesByURL[
                document.sourceURL
            ] = newAnalysis

            folderSuggestionsByURL[
                document.sourceURL
            ] = newFolderSuggestion

            if analysis == nil {
                analysis =
                    newAnalysis

                folderSuggestion =
                    newFolderSuggestion
            }

        } catch {

            // Reine Bildscans oder nicht lesbare PDFs
            // können später genauer protokolliert werden.
        }
    }

    // MARK: - Manual Analysis

    func analyze(
        document: DocumentRecord
    ) {

        Task {
            await analyzeAsync(
                document:
                    document
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
        manualArchiveDestinationURL = nil

        do {

            let text =
                try await
                    pdfTextExtractionService
                        .extractText(
                            from:
                                document.sourceURL
                        )

            extractedText =
                text

            textExtractionMessage =
                "\(text.count) Zeichen aus dem PDF gelesen."

            let newAnalysis =
                atlasAnalyzer.analyze(
                    text: text
                )

            let newFolderSuggestion =
                folderSuggestionEngine
                    .suggestFolder(
                        for:
                            newAnalysis,
                        text:
                            text
                    )

            analysis =
                newAnalysis

            folderSuggestion =
                newFolderSuggestion

            analysesByURL[
                document.sourceURL
            ] = newAnalysis

            folderSuggestionsByURL[
                document.sourceURL
            ] = newFolderSuggestion

        } catch {

            textExtractionMessage =
                error.localizedDescription
        }
    }

    // MARK: - Stored Analysis

    func analysis(
        for document: DocumentRecord
    ) -> AtlasAnalysis? {

        analysesByURL[
            document.sourceURL
        ]
    }

    func folderSuggestion(
        for document: DocumentRecord
    ) -> FolderSuggestion? {

        folderSuggestionsByURL[
            document.sourceURL
        ]
    }

    func selectAnalysis(
        for document:
            DocumentRecord?
    ) {

        manualArchiveDestinationURL = nil

        guard let document else {
            clearAnalysis()
            return
        }

        analysis =
            analysesByURL[
                document.sourceURL
            ]

        folderSuggestion =
            folderSuggestionsByURL[
                document.sourceURL
            ]

        extractedText = ""

        textExtractionMessage =
            analysis == nil
            ? nil
            : "Analyse ist für dieses Dokument bereits vorhanden."
    }

    func clearAnalysis() {

        extractedText = ""
        textExtractionMessage = nil
        analysis = nil
        folderSuggestion = nil
        isAnalyzing = false
        manualArchiveDestinationURL = nil
    }

    // MARK: - Manual Archive Destination

    func setManualArchiveDestination(
        _ url: URL
    ) {
        manualArchiveDestinationURL =
            url
    }

    func clearManualArchiveDestination() {
        manualArchiveDestinationURL =
            nil
    }

    // MARK: - Filename Suggestion

    func suggestFilename(
        for document:
            DocumentRecord
    ) -> String {

        let documentAnalysis =
            analysesByURL[
                document.sourceURL
            ] ?? analysis

        guard let documentAnalysis
        else {
            return
                filenameSuggestionService
                    .suggestFilename(
                        for:
                            document
                    )
        }

        return
            buildFilenameSuggestion(
                from:
                    documentAnalysis,
                fallbackDocument:
                    document
            )
    }

    // MARK: - Rename

    func rename(
        document: DocumentRecord,
        to newFilename: String
    ) -> DocumentRecord? {

        errorMessage = nil

        let cleanedName =
            newFilename
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard !cleanedName.isEmpty
        else {

            errorMessage =
                "Der neue Dateiname darf nicht leer sein."

            return nil
        }

        let destinationURL =
            document.sourceURL
                .deletingLastPathComponent()
                .appendingPathComponent(
                    cleanedName
                )
                .appendingPathExtension(
                    "pdf"
                )

        guard destinationURL !=
                document.sourceURL
        else {
            return document
        }

        guard
            !FileManager.default
                .fileExists(
                    atPath:
                        destinationURL.path
                )
        else {

            errorMessage =
                "Eine Datei mit diesem Namen existiert bereits."

            return nil
        }

        do {

            let previousAnalysis =
                analysesByURL[
                    document.sourceURL
                ]

            let previousFolderSuggestion =
                folderSuggestionsByURL[
                    document.sourceURL
                ]

            try FileManager.default
                .moveItem(
                    at:
                        document.sourceURL,
                    to:
                        destinationURL
                )

            analysesByURL
                .removeValue(
                    forKey:
                        document.sourceURL
                )

            folderSuggestionsByURL
                .removeValue(
                    forKey:
                        document.sourceURL
                )

            if let previousAnalysis {

                analysesByURL[
                    destinationURL
                ] =
                    previousAnalysis
            }

            if let previousFolderSuggestion {

                folderSuggestionsByURL[
                    destinationURL
                ] =
                    previousFolderSuggestion
            }

            loadDocuments()

            return
                documents.first {
                    $0.sourceURL ==
                        destinationURL
                }

        } catch {

            errorMessage =
                "Die Datei konnte nicht umbenannt werden: \(error.localizedDescription)"

            return nil
        }
    }

    // MARK: - Archive

    func archive(
        document: DocumentRecord
    ) async -> Bool {

        errorMessage = nil
        isArchiving = true

        defer {
            isArchiving = false
        }

        let suggestion =
            folderSuggestionsByURL[
                document.sourceURL
            ] ?? folderSuggestion

        // Wenn kein manuelles Ziel gewählt wurde,
        // brauchen wir weiterhin einen Atlas-Vorschlag.
        if manualArchiveDestinationURL == nil {

            guard suggestion != nil else {

                errorMessage =
                    "Es ist noch kein Zielordner vorhanden."

                return false
            }
        }

        do {

            let destinationFolderURL:
                URL

            if let manualArchiveDestinationURL {

                // Benutzer hat das Atlas-Ziel
                // für dieses Dokument überschrieben.
                destinationFolderURL =
                    manualArchiveDestinationURL

            } else {

                guard let suggestion else {

                    errorMessage =
                        "Es ist noch kein Zielordner vorhanden."

                    return false
                }

                guard let workspace =
                    archiveWorkspaceStore
                        .workspace(
                            matching:
                                suggestion.area
                        )
                else {

                    errorMessage =
                        "Für \(suggestion.area.rawValue) wurde kein Arbeitsbereich gefunden."

                    return false
                }

                guard let archiveRootURL =
                    archiveWorkspaceStore
                        .folderURL(
                            for:
                                workspace
                        )
                else {

                    errorMessage =
                        "Für \(workspace.name) wurde noch kein Archivort ausgewählt."

                    return false
                }

                destinationFolderURL =
                    try archiveDestinationResolver
                        .resolve(
                            rootURL:
                                archiveRootURL,
                            relativePath:
                                suggestion.folder
                        )
            }

            let fileMover =
                archiveFileMover

            let sourceURL =
                document.sourceURL

            let targetURL =
                destinationFolderURL

            _ = try await Task.detached(
                priority: .userInitiated
            ) {
                try fileMover.move(
                    file:
                        sourceURL,
                    to:
                        targetURL
                )
            }
            .value

            analysesByURL
                .removeValue(
                    forKey:
                        document.sourceURL
                )

            folderSuggestionsByURL
                .removeValue(
                    forKey:
                        document.sourceURL
                )

            manualArchiveDestinationURL =
                nil

            loadDocuments()
            clearAnalysis()

            return true

        } catch {

            errorMessage =
                error.localizedDescription

            return false
        }
    }

    // MARK: - Remove Inbox Folder

    func removeFolder() {

        folderStore.removeFolder()

        documents = []
        analysesByURL = [:]
        folderSuggestionsByURL = [:]

        clearAnalysis()

        errorMessage = nil
    }

    // MARK: - Filename Builder

    private func buildFilenameSuggestion(
        from analysis:
            AtlasAnalysis,
        fallbackDocument:
            DocumentRecord
    ) -> String {

        var parts:
            [String] = []

        if let date =
            analysis.detectedDate {

            let formatter =
                DateFormatter()

            formatter.dateFormat =
                "yyyy-MM-dd"

            parts.append(
                formatter.string(
                    from: date
                )
            )
        }

        if analysis.documentType !=
            .unknown {

            parts.append(
                analysis
                    .documentType
                    .rawValue
            )
        }

        if let sender =
            analysis.sender {

            parts.append(
                sender
            )
        }

        if parts.isEmpty {

            return
                filenameSuggestionService
                    .suggestFilename(
                        for:
                            fallbackDocument
                    )
        }

        return
            parts.joined(
                separator: " "
            )
    }
}
