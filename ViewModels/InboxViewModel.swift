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

    // MARK: - Knowledge Base

    private let knowledgeBase:
        KnowledgeBase

    private let folderSuggestionEngine:
        FolderSuggestionEngine

    // MARK: - Visual Sender

    private let senderVisualRecognizer:
        SenderVisualRecognizer

    private let visualSenderLearningManager =
        VisualSenderLearningManager()

    private let learnedCompanyStore =
        LearnedCompanyStore()

    // MARK: - Init

    init() {

        let loadedKnowledgeBase:
            KnowledgeBase

        do {

            loadedKnowledgeBase =
                try KnowledgeBase.load()

        } catch {

            print(
                "KnowledgeBase konnte nicht geladen werden: \(error.localizedDescription)"
            )

            loadedKnowledgeBase =
                KnowledgeBase(
                    companies: [],
                    documentTypes: [],
                    folderRules: []
                )
        }

        knowledgeBase =
            loadedKnowledgeBase

        folderSuggestionEngine =
            FolderSuggestionEngine(
                knowledgeBase:
                    loadedKnowledgeBase
            )

        senderVisualRecognizer =
            SenderVisualRecognizer(
                knowledgeBase:
                    loadedKnowledgeBase
            )
    }

    // MARK: - Documents

    var documents:
        [DocumentRecord] = []

    var errorMessage:
        String?

    // MARK: - Analysis

    var extractedText =
        ""

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

    // MARK: - Manual Archive Destination

    var manualArchiveDestinationURL:
        URL?

    // MARK: - Visual Sender State

    /// Absender, den Atlas anhand des
    /// Dokumentkopfs vorschlägt.
    var visualSenderSuggestion:
        String?

    /// Visuelle Signatur des aktuell
    /// ausgewählten Dokuments.
    var visualSenderSignature:
        VisualFeatureSignature?

    /// Wie oft ein ähnlicher Dokumentkopf
    /// bereits derselben Firma bestätigt wurde.
    var visualSenderConfirmationCount =
        0

    /// Bei true soll die Oberfläche den
    /// Benutzer nach dem Absender fragen.
    var visualSenderNeedsConfirmation =
        false

    /// Ähnlichkeit mit dem besten bereits
    /// gelernten visuellen Eintrag.
    var visualSenderSimilarity:
        Double?

    /// Firmen für die spätere
    /// "Absender bestätigen"-Auswahl.
    ///
    /// Enthält sowohl Firmen aus der KnowledgeBase
    /// als auch Firmen, die der Benutzer neu gelernt hat.
    var availableVisualSenderCompanies:
        [String] {

        let knowledgeCompanies =
            knowledgeBase
                .companies
                .map(\.name)

        let learnedCompanies =
            learnedCompanyStore
                .load()

        var result:
            [String] = []

        var known:
            Set<String> = []

        for company in
            knowledgeCompanies + learnedCompanies {

            let cleaned =
                company
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            guard
                !cleaned.isEmpty
            else {
                continue
            }

            let key =
                normalizeCompany(
                    cleaned
                )

            guard
                !known.contains(
                    key
                )
            else {
                continue
            }

            known.insert(
                key
            )

            result.append(
                cleaned
            )
        }

        return result.sorted {

            $0.localizedStandardCompare(
                $1
            ) == .orderedAscending
        }
    }

    // MARK: - Stored Data

    private var analysesByURL:
        [URL: AtlasAnalysis] = [:]

    private var folderSuggestionsByURL:
        [URL: FolderSuggestion] = [:]

    /// Extrahierter Text wird gespeichert,
    /// damit nach einer Absenderkorrektur der
    /// Archivvorschlag neu berechnet werden kann.
    private var extractedTextsByURL:
        [URL: String] = [:]

    // MARK: Visual State Per Document

    private var visualSignaturesByURL:
        [URL: VisualFeatureSignature] = [:]

    private var visualSenderSuggestionsByURL:
        [URL: String] = [:]

    private var visualSenderConfirmationCountsByURL:
        [URL: Int] = [:]

    private var visualSenderNeedsConfirmationByURL:
        [URL: Bool] = [:]

    private var visualSenderSimilaritiesByURL:
        [URL: Double] = [:]

    // MARK: - Folder URL

    var folderURL:
        URL? {

        folderStore.folderURL
    }

    // MARK: - Folder

    func selectFolder(
        _ url: URL
    ) {

        folderStore.saveFolder(
            url
        )

        loadDocuments()
    }

    // MARK: - Documents

    func loadDocuments() {

        errorMessage =
            nil

        guard let folderURL else {

            documents =
                []

            return
        }

        do {

            let files =
                try FileManager.default
                    .contentsOfDirectory(
                        at:
                            folderURL,
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
                            .lowercased()
                        ==
                        "pdf"
                    }
                    .sorted {

                        $0.lastPathComponent
                            .localizedStandardCompare(
                                $1.lastPathComponent
                            )
                        ==
                        .orderedAscending
                    }
                    .map {

                        DocumentRecord(
                            sourceURL:
                                $0
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

            extractedTextsByURL =
                extractedTextsByURL.filter {

                    availableURLs.contains(
                        $0.key
                    )
                }

            visualSignaturesByURL =
                visualSignaturesByURL.filter {

                    availableURLs.contains(
                        $0.key
                    )
                }

            visualSenderSuggestionsByURL =
                visualSenderSuggestionsByURL.filter {

                    availableURLs.contains(
                        $0.key
                    )
                }

            visualSenderConfirmationCountsByURL =
                visualSenderConfirmationCountsByURL.filter {

                    availableURLs.contains(
                        $0.key
                    )
                }

            visualSenderNeedsConfirmationByURL =
                visualSenderNeedsConfirmationByURL.filter {

                    availableURLs.contains(
                        $0.key
                    )
                }

            visualSenderSimilaritiesByURL =
                visualSenderSimilaritiesByURL.filter {

                    availableURLs.contains(
                        $0.key
                    )
                }

            autoAnalyzeDocuments()

        } catch {

            documents =
                []

            errorMessage =
                "Die Dateien konnten nicht gelesen werden: \(error.localizedDescription)"
        }
    }

    // MARK: - Automatic Analysis

    private func autoAnalyzeDocuments() {

        autoAnalysisService
            .analyzeIfNeeded(
                documents:
                    documents,
                alreadyAnalyzed: {
                    document in

                    self.analysis(
                        for:
                            document
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

            extractedTextsByURL[
                document.sourceURL
            ] =
                text

            let textAnalysis =
                atlasAnalyzer.analyze(
                    text:
                        text
                )

            // Zusätzlich den Dokumentkopf
            // visuell untersuchen.
            let finalAnalysis =
                await applyVisualSenderAnalysis(
                    to:
                        textAnalysis,
                    document:
                        document
                )

            let newFolderSuggestion =
                folderSuggestionEngine
                    .suggestFolder(
                        for:
                            finalAnalysis,
                        text:
                            text
                    )

            analysesByURL[
                document.sourceURL
            ] =
                finalAnalysis

            folderSuggestionsByURL[
                document.sourceURL
            ] =
                newFolderSuggestion

            // Nur übernehmen, wenn gerade noch
            // keine andere Analyse ausgewählt ist.
            if analysis == nil {

                analysis =
                    finalAnalysis

                folderSuggestion =
                    newFolderSuggestion

                restoreVisualSenderState(
                    for:
                        document.sourceURL
                )
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

        isAnalyzing =
            true

        defer {

            isAnalyzing =
                false
        }

        extractedText =
            ""

        textExtractionMessage =
            nil

        analysis =
            nil

        folderSuggestion =
            nil

        manualArchiveDestinationURL =
            nil

        clearCurrentVisualSenderState()

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

            extractedTextsByURL[
                document.sourceURL
            ] =
                text

            textExtractionMessage =
                "\(text.count) Zeichen aus dem PDF gelesen."

            let textAnalysis =
                atlasAnalyzer.analyze(
                    text:
                        text
                )

            let finalAnalysis =
                await applyVisualSenderAnalysis(
                    to:
                        textAnalysis,
                    document:
                        document
                )

            let newFolderSuggestion =
                folderSuggestionEngine
                    .suggestFolder(
                        for:
                            finalAnalysis,
                        text:
                            text
                    )

            analysis =
                finalAnalysis

            folderSuggestion =
                newFolderSuggestion

            analysesByURL[
                document.sourceURL
            ] =
                finalAnalysis

            folderSuggestionsByURL[
                document.sourceURL
            ] =
                newFolderSuggestion

            restoreVisualSenderState(
                for:
                    document.sourceURL
            )

        } catch {

            textExtractionMessage =
                error.localizedDescription
        }
    }

    // MARK: - Visual Sender Analysis

    private func applyVisualSenderAnalysis(
        to baseAnalysis: AtlasAnalysis,
        document: DocumentRecord
    ) async -> AtlasAnalysis {

        let url =
            document.sourceURL

        let visualResult =
            await senderVisualRecognizer
                .analyze(
                    pdfURL:
                        url
                )

        guard let signature =
            visualResult.signature
        else {

            clearStoredVisualSenderState(
                for:
                    url
            )

            return baseAnalysis
        }

        visualSignaturesByURL[
            url
        ] =
            signature

        // Ein anderer Manager kann inzwischen
        // neue Bestätigungen gespeichert haben.
        visualSenderLearningManager
            .reload()

        let learnedMatch =
            visualSenderLearningManager
                .matchInformation(
                    for:
                        signature
                )

        var suggestedCompany =
            visualResult.detectedCompany

        var confirmationCount =
            0

        var needsConfirmation =
            true

        var similarity:
            Double?

        var updatedAnalysis =
            baseAnalysis

        if let learnedMatch {

            suggestedCompany =
                learnedMatch
                    .entry
                    .company

            confirmationCount =
                learnedMatch
                    .entry
                    .confirmationCount

            similarity =
                learnedMatch
                    .similarity

            let ocrCompany =
                visualResult
                    .detectedCompany

            let visualSignalsConflict:
                Bool

            if let ocrCompany {

                visualSignalsConflict =
                    !sameCompany(
                        ocrCompany,
                        learnedMatch
                            .entry
                            .company
                    )

            } else {

                visualSignalsConflict =
                    false
            }

            // Erst ab 3 Bestätigungen und nur
            // ohne Widerspruch im Kopfbereich
            // wird der Absender automatisch ersetzt.
            if learnedMatch
                .entry
                .canUseAutomatically
                &&
                !visualSignalsConflict {

                needsConfirmation =
                    false

                updatedAnalysis =
                    replacingSender(
                        in:
                            baseAnalysis,
                        with:
                            learnedMatch
                                .entry
                                .company,
                        reason:
                            "Absender \(learnedMatch.entry.company) wurde visuell gelernt (\(learnedMatch.entry.confirmationCount)× bestätigt)"
                    )

            } else {

                needsConfirmation =
                    true
            }

        } else {

            // Noch unbekannter Dokumentkopf.
            // Auch wenn OCR bereits eine Firma
            // vermutet, soll sie zunächst vom
            // Benutzer bestätigt werden.
            confirmationCount =
                0

            similarity =
                nil

            needsConfirmation =
                true
        }

        if let suggestedCompany {

            visualSenderSuggestionsByURL[
                url
            ] =
                suggestedCompany

        } else {

            visualSenderSuggestionsByURL
                .removeValue(
                    forKey:
                        url
                )
        }

        visualSenderConfirmationCountsByURL[
            url
        ] =
            confirmationCount

        visualSenderNeedsConfirmationByURL[
            url
        ] =
            needsConfirmation

        if let similarity {

            visualSenderSimilaritiesByURL[
                url
            ] =
                similarity

        } else {

            visualSenderSimilaritiesByURL
                .removeValue(
                    forKey:
                        url
                )
        }

        return updatedAnalysis
    }

    // MARK: - Confirm Visual Sender

    /// Benutzer bestätigt den Absender für das
    /// aktuelle Dokument.
    ///
    /// Die Bestätigung wird sofort für dieses
    /// Dokument verwendet. Automatisch auf andere
    /// Dokumente übertragen wird sie aber erst
    /// nach drei Bestätigungen.
    @discardableResult
    func confirmVisualSender(
        company: String,
        for document: DocumentRecord
    ) -> Bool {

        let cleanedCompany =
            company
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            !cleanedCompany.isEmpty,
            let signature =
                visualSignaturesByURL[
                    document.sourceURL
                ]
        else {

            return false
        }

        // Auch frei eingegebene Firmen dauerhaft
        // in die allgemeine Firmenauswahl übernehmen.
        learnedCompanyStore.add(
            cleanedCompany
        )

        visualSenderLearningManager
            .reload()

        visualSenderLearningManager
            .confirm(
                company:
                    cleanedCompany,
                signature:
                    signature
            )

        let match =
            visualSenderLearningManager
                .matchInformation(
                    for:
                        signature
                )

        let confirmationCount =
            match?
                .entry
                .confirmationCount
            ?? 1

        visualSenderSuggestionsByURL[
            document.sourceURL
        ] =
            cleanedCompany

        visualSenderConfirmationCountsByURL[
            document.sourceURL
        ] =
            confirmationCount

        // Für DIESES Dokument hat der Benutzer
        // gerade bestätigt. Daher keine weitere
        // Rückfrage nötig.
        visualSenderNeedsConfirmationByURL[
            document.sourceURL
        ] =
            false

        if let similarity =
            match?.similarity {

            visualSenderSimilaritiesByURL[
                document.sourceURL
            ] =
                similarity
        }

        // Aktuelle Analyse holen.
        guard let currentAnalysis =
            analysesByURL[
                document.sourceURL
            ] ?? analysis
        else {

            restoreVisualSenderState(
                for:
                    document.sourceURL
            )

            return true
        }

        let correctedAnalysis =
            replacingSender(
                in:
                    currentAnalysis,
                with:
                    cleanedCompany,
                reason:
                    "Absender \(cleanedCompany) wurde vom Benutzer visuell bestätigt (\(confirmationCount)× bestätigt)"
            )

        analysesByURL[
            document.sourceURL
        ] =
            correctedAnalysis

        // Zielordner nach der Absenderkorrektur
        // sofort neu berechnen.
        if let storedText =
            extractedTextsByURL[
                document.sourceURL
            ] {

            let correctedFolderSuggestion =
                folderSuggestionEngine
                    .suggestFolder(
                        for:
                            correctedAnalysis,
                        text:
                            storedText
                    )

            folderSuggestionsByURL[
                document.sourceURL
            ] =
                correctedFolderSuggestion

            if analysisBelongsTo(
                document
            ) {

                analysis =
                    correctedAnalysis

                folderSuggestion =
                    correctedFolderSuggestion
            }

        } else if analysisBelongsTo(
            document
        ) {

            analysis =
                correctedAnalysis
        }

        restoreVisualSenderState(
            for:
                document.sourceURL
        )

        return true
    }

    // MARK: - Visual Sender Helpers

    private func replacingSender(
        in analysis: AtlasAnalysis,
        with sender: String,
        reason: String
    ) -> AtlasAnalysis {

        var reasons =
            analysis.reasons.filter {

                !$0
                    .localizedCaseInsensitiveContains(
                        "Absender "
                    )
            }

        reasons.append(
            reason
        )

        return AtlasAnalysis(
            documentType:
                analysis.documentType,
            detectedDate:
                analysis.detectedDate,
            sender:
                sender,
            recipientArea:
                analysis.recipientArea,
            keywords:
                analysis.keywords,
            confidence:
                analysis.confidence,
            reasons:
                reasons
        )
    }

    private func sameCompany(
        _ first: String,
        _ second: String
    ) -> Bool {

        normalizeCompany(
            first
        )
        ==
        normalizeCompany(
            second
        )
    }

    private func normalizeCompany(
        _ value: String
    ) -> String {

        value
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive
                ],
                locale:
                    Locale(
                        identifier:
                            "de_DE"
                    )
            )
            .lowercased()
    }

    private func restoreVisualSenderState(
        for url: URL
    ) {

        visualSenderSignature =
            visualSignaturesByURL[
                url
            ]

        visualSenderSuggestion =
            visualSenderSuggestionsByURL[
                url
            ]

        visualSenderConfirmationCount =
            visualSenderConfirmationCountsByURL[
                url
            ]
            ?? 0

        visualSenderNeedsConfirmation =
            visualSenderNeedsConfirmationByURL[
                url
            ]
            ?? false

        visualSenderSimilarity =
            visualSenderSimilaritiesByURL[
                url
            ]
    }

    private func clearCurrentVisualSenderState() {

        visualSenderSuggestion =
            nil

        visualSenderSignature =
            nil

        visualSenderConfirmationCount =
            0

        visualSenderNeedsConfirmation =
            false

        visualSenderSimilarity =
            nil
    }

    private func clearStoredVisualSenderState(
        for url: URL
    ) {

        visualSignaturesByURL
            .removeValue(
                forKey:
                    url
            )

        visualSenderSuggestionsByURL
            .removeValue(
                forKey:
                    url
            )

        visualSenderConfirmationCountsByURL
            .removeValue(
                forKey:
                    url
            )

        visualSenderNeedsConfirmationByURL
            .removeValue(
                forKey:
                    url
            )

        visualSenderSimilaritiesByURL
            .removeValue(
                forKey:
                    url
            )
    }

    private func analysisBelongsTo(
        _ document: DocumentRecord
    ) -> Bool {

        guard let storedAnalysis =
            analysesByURL[
                document.sourceURL
            ]
        else {
            return false
        }

        guard let currentAnalysis =
            analysis
        else {
            return false
        }

        return
            storedAnalysis.documentType ==
                currentAnalysis.documentType
            &&
            storedAnalysis.detectedDate ==
                currentAnalysis.detectedDate
            &&
            storedAnalysis.sender ==
                currentAnalysis.sender
            &&
            storedAnalysis.recipientArea ==
                currentAnalysis.recipientArea
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

        manualArchiveDestinationURL =
            nil

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

        extractedText =
            ""

        textExtractionMessage =
            analysis == nil
            ? nil
            : "Analyse ist für dieses Dokument bereits vorhanden."

        restoreVisualSenderState(
            for:
                document.sourceURL
        )
    }

    func clearAnalysis() {

        extractedText =
            ""

        textExtractionMessage =
            nil

        analysis =
            nil

        folderSuggestion =
            nil

        isAnalyzing =
            false

        manualArchiveDestinationURL =
            nil

        clearCurrentVisualSenderState()
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

    // MARK: - Learning From Manual Destination

    private func rememberManualArchiveDestination(
        for document: DocumentRecord,
        destinationURL: URL
    ) {

        guard let documentAnalysis =
            analysesByURL[
                document.sourceURL
            ] ?? analysis
        else {
            return
        }

        guard let destinationInfo =
            archiveDestinationInfo(
                for:
                    destinationURL
            )
        else {
            return
        }

        let learnedSuggestion =
            FolderSuggestion(
                ruleName:
                    "Manuell bestätigtes Archivziel",
                area:
                    destinationInfo.area,
                folder:
                    destinationInfo.relativePath,
                confidence:
                    1.0,
                reasons: [
                    "Archivziel wurde beim Archivieren manuell gewählt"
                ]
            )

        LearningEngine()
            .remember(
                analysis:
                    documentAnalysis,
                destination:
                    learnedSuggestion
            )
    }

    private func archiveDestinationInfo(
        for destinationURL: URL
    ) -> (
        area: ArchiveArea,
        relativePath: String
    )? {

        let destination =
            destinationURL
                .standardizedFileURL

        for area in
            ArchiveArea.allCases {

            guard let workspace =
                archiveWorkspaceStore
                    .workspace(
                        matching:
                            area
                    )
            else {
                continue
            }

            guard let rootURL =
                archiveWorkspaceStore
                    .folderURL(
                        for:
                            workspace
                    )
            else {
                continue
            }

            let root =
                rootURL
                    .standardizedFileURL

            let rootPath =
                root.path

            let destinationPath =
                destination.path

            guard
                destinationPath ==
                    rootPath
                ||
                destinationPath
                    .hasPrefix(
                        rootPath + "/"
                    )
            else {
                continue
            }

            let relativePath =
                String(
                    destinationPath
                        .dropFirst(
                            rootPath.count
                        )
                )
                .trimmingCharacters(
                    in:
                        CharacterSet(
                            charactersIn:
                                "/"
                        )
                )

            guard
                !relativePath.isEmpty
            else {
                return nil
            }

            return (
                area:
                    area,
                relativePath:
                    relativePath
            )
        }

        return nil
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

        errorMessage =
            nil

        let cleanedName =
            newFilename
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            !cleanedName.isEmpty
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

        guard
            destinationURL !=
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

            let sourceURL =
                document.sourceURL

            let previousAnalysis =
                analysesByURL[
                    sourceURL
                ]

            let previousFolderSuggestion =
                folderSuggestionsByURL[
                    sourceURL
                ]

            let previousExtractedText =
                extractedTextsByURL[
                    sourceURL
                ]

            let previousVisualSignature =
                visualSignaturesByURL[
                    sourceURL
                ]

            let previousVisualSenderSuggestion =
                visualSenderSuggestionsByURL[
                    sourceURL
                ]

            let previousConfirmationCount =
                visualSenderConfirmationCountsByURL[
                    sourceURL
                ]

            let previousNeedsConfirmation =
                visualSenderNeedsConfirmationByURL[
                    sourceURL
                ]

            let previousSimilarity =
                visualSenderSimilaritiesByURL[
                    sourceURL
                ]

            try FileManager.default
                .moveItem(
                    at:
                        sourceURL,
                    to:
                        destinationURL
                )

            analysesByURL
                .removeValue(
                    forKey:
                        sourceURL
                )

            folderSuggestionsByURL
                .removeValue(
                    forKey:
                        sourceURL
                )

            extractedTextsByURL
                .removeValue(
                    forKey:
                        sourceURL
                )

            clearStoredVisualSenderState(
                for:
                    sourceURL
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

            if let previousExtractedText {

                extractedTextsByURL[
                    destinationURL
                ] =
                    previousExtractedText
            }

            if let previousVisualSignature {

                visualSignaturesByURL[
                    destinationURL
                ] =
                    previousVisualSignature
            }

            if let previousVisualSenderSuggestion {

                visualSenderSuggestionsByURL[
                    destinationURL
                ] =
                    previousVisualSenderSuggestion
            }

            if let previousConfirmationCount {

                visualSenderConfirmationCountsByURL[
                    destinationURL
                ] =
                    previousConfirmationCount
            }

            if let previousNeedsConfirmation {

                visualSenderNeedsConfirmationByURL[
                    destinationURL
                ] =
                    previousNeedsConfirmation
            }

            if let previousSimilarity {

                visualSenderSimilaritiesByURL[
                    destinationURL
                ] =
                    previousSimilarity
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

        errorMessage =
            nil

        isArchiving =
            true

        defer {

            isArchiving =
                false
        }

        let suggestion =
            folderSuggestionsByURL[
                document.sourceURL
            ] ?? folderSuggestion

        // Wenn kein manuelles Ziel gewählt wurde,
        // brauchen wir einen Atlas-Vorschlag.
        if manualArchiveDestinationURL ==
            nil {

            guard suggestion != nil
            else {

                errorMessage =
                    "Es ist noch kein Zielordner vorhanden."

                return false
            }
        }

        do {

            let destinationFolderURL:
                URL

            if let manualArchiveDestinationURL {

                destinationFolderURL =
                    manualArchiveDestinationURL

            } else {

                guard let suggestion
                else {

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

            let manualDestinationForLearning =
                manualArchiveDestinationURL

            _ =
                try await Task.detached(
                    priority:
                        .userInitiated
                ) {

                    try fileMover.move(
                        file:
                            sourceURL,
                        to:
                            targetURL
                    )
                }
                .value

            // Nur ein erfolgreich archiviertes
            // manuell gewähltes Ziel wird gelernt.
            if let manualDestinationForLearning {

                rememberManualArchiveDestination(
                    for:
                        document,
                    destinationURL:
                        manualDestinationForLearning
                )
            }

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

            extractedTextsByURL
                .removeValue(
                    forKey:
                        document.sourceURL
                )

            clearStoredVisualSenderState(
                for:
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

        documents =
            []

        analysesByURL =
            [:]

        folderSuggestionsByURL =
            [:]

        extractedTextsByURL =
            [:]

        visualSignaturesByURL =
            [:]

        visualSenderSuggestionsByURL =
            [:]

        visualSenderConfirmationCountsByURL =
            [:]

        visualSenderNeedsConfirmationByURL =
            [:]

        visualSenderSimilaritiesByURL =
            [:]

        clearAnalysis()

        errorMessage =
            nil
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
                    from:
                        date
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
                separator:
                    " "
            )
    }
}
