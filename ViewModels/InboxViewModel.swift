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

    private let learnedCompanySignatureStore =
        LearnedCompanySignatureStore()

    // MARK: - Atlas Learning

    private let atlasLearningStore =
        AtlasLearningStore()
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

    // MARK: - Archive Conflict

    var archiveConflict:
        ArchiveConflict?

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

    /// Position des per OCR im Dokumentkopf
    /// erkannten Absenders.
    ///
    /// Die Koordinaten stammen aus Vision
    /// und beziehen sich auf den oberen
    /// 30-%-Ausschnitt der ersten PDF-Seite.
    var visualSenderBoundingBox:
        CGRect?

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

    /// Ursprünglicher Atlas-Vorschlag.
    /// Dieser wird bei manuellen Korrekturen nicht überschrieben.
    private var initialAnalysesByURL:
        [URL: AtlasAnalysis] = [:]

    /// Ursprünglicher Zielordner-Vorschlag von Atlas.
    private var initialFolderSuggestionsByURL:
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

    private var visualSenderBoundingBoxesByURL:
        [URL: CGRect] = [:]

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

            initialAnalysesByURL =
                initialAnalysesByURL.filter {

                    availableURLs.contains(
                        $0.key
                    )
                }

            initialFolderSuggestionsByURL =
                initialFolderSuggestionsByURL.filter {

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

            visualSenderBoundingBoxesByURL =
                visualSenderBoundingBoxesByURL.filter {

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
            let senderAnalysis =
                await applyVisualSenderAnalysis(
                    to:
                        textAnalysis,
                    document:
                        document
                )

            // Bei bekannten Dokumentlayouts kann Atlas
            // ein Datum zusätzlich gezielt aus dem
            // vorgesehenen Datumsfeld lesen.
            //
            // Das Layout-Datum wird nur übernommen,
            // wenn die OCR-Konsensprüfung es als
            // ausreichend sicher bewertet.
            let dateAnalysis =
                await applyLayoutDateAnalysis(
                    to:
                        senderAnalysis,
                    document:
                        document,
                    text:
                        text
                )

            // Bei bekannten Layouts kann Atlas zusätzlich
            // gezielt den Empfängerbereich lesen.
            //
            // Die eigentliche Zuordnung übernimmt weiterhin
            // der zentrale RecipientRecognizer.
            let finalAnalysis =
                await applyLayoutRecipientAnalysis(
                    to:
                        dateAnalysis,
                    document:
                        document,
                    text:
                        text
                )

            // Bestätigtes Atlas-Wissen darf die
            // Analyse ergänzen bzw. bei ausreichend
            // sicherem Wiedererkennen korrigieren.
            let learnedAnalysis =
                applyLearnedAnalysis(
                    to:
                        finalAnalysis,
                    text:
                        text
                )

            let newFolderSuggestion =
                folderSuggestionEngine
                    .suggestFolder(
                        for:
                            learnedAnalysis,
                        text:
                            text
                    )

            if initialAnalysesByURL[
                document.sourceURL
            ] == nil {

                initialAnalysesByURL[
                    document.sourceURL
                ] =
                    learnedAnalysis
            }

            if initialFolderSuggestionsByURL[
                document.sourceURL
            ] == nil {

                initialFolderSuggestionsByURL[
                    document.sourceURL
                ] =
                    newFolderSuggestion
            }

            analysesByURL[
                document.sourceURL
            ] =
                learnedAnalysis

            folderSuggestionsByURL[
                document.sourceURL
            ] =
                newFolderSuggestion

            // Nur übernehmen, wenn gerade noch
            // keine andere Analyse ausgewählt ist.
            if analysis == nil {

                analysis =
                    learnedAnalysis

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

            let senderAnalysis =
                await applyVisualSenderAnalysis(
                    to:
                        textAnalysis,
                    document:
                        document
                )

            let dateAnalysis =
                await applyLayoutDateAnalysis(
                    to:
                        senderAnalysis,
                    document:
                        document,
                    text:
                        text
                )

            let finalAnalysis =
                await applyLayoutRecipientAnalysis(
                    to:
                        dateAnalysis,
                    document:
                        document,
                    text:
                        text
                )

            // Bestätigtes Atlas-Wissen darf die
            // Analyse ergänzen bzw. bei ausreichend
            // sicherem Wiedererkennen korrigieren.
            let learnedAnalysis =
                applyLearnedAnalysis(
                    to:
                        finalAnalysis,
                    text:
                        text
                )

            let newFolderSuggestion =
                folderSuggestionEngine
                    .suggestFolder(
                        for:
                            learnedAnalysis,
                        text:
                            text
                    )

            analysis =
                learnedAnalysis

            folderSuggestion =
                newFolderSuggestion

            if initialAnalysesByURL[
                document.sourceURL
            ] == nil {

                initialAnalysesByURL[
                    document.sourceURL
                ] =
                    learnedAnalysis
            }

            if initialFolderSuggestionsByURL[
                document.sourceURL
            ] == nil {

                initialFolderSuggestionsByURL[
                    document.sourceURL
                ] =
                    newFolderSuggestion
            }

            analysesByURL[
                document.sourceURL
            ] =
                learnedAnalysis

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

    // MARK: - Learned Analysis

    private func applyLearnedAnalysis(
        to baseAnalysis: AtlasAnalysis,
        text: String
    ) -> AtlasAnalysis {

        let learningManager =
            LearningManager()

        learningManager.reload()

        learningManager
            .removeInvalidEntries(
                validFolders:
                    knowledgeBase
                        .archiveFolders
            )

        var entries =
            learningManager.entries

        // Wenn der Empfänger bereits erkannt wurde,
        // vergleichen wir nur mit Erfahrungen aus
        // demselben Archivbereich.
        if let recipientArea =
            baseAnalysis.recipientArea {

            entries =
                entries.filter {

                    $0.archiveArea ==
                        recipientArea
                }
        }

        let matcher =
            LearningMatcher()

        guard
            let match =
                matcher.bestMatch(
                    for:
                        baseAnalysis,
                    entries:
                        entries,
                    documentText:
                        text
                )
        else {

            return baseAnalysis
        }

        // Erst mehrfach bestätigte und zugleich
        // textlich ähnliche Dokumente dürfen
        // die automatische Analyse verändern.
        guard
            match.canApplyToAnalysis
        else {

            return baseAnalysis
        }

        let learnedEntry =
            match.entry

        var reasons =
            baseAnalysis.reasons

        reasons.append(
            "Atlas hat dieses Dokument anhand bestätigter Erfahrungen wiedererkannt (\(match.usageCount)× bestätigt, \(match.documentSignalMatches) Textmerkmale)"
        )

        // MARK: Sender

        let learnedSender =
            learnedEntry.company?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let finalSender:
            String?

        let finalSenderDetectedText:
            String?

        if let learnedSender,
           !learnedSender.isEmpty {

            finalSender =
                learnedSender

            // Dieser Wert stammt aus dem Lernen und
            // nicht aus einer konkreten Textstelle.
            finalSenderDetectedText =
                nil

            if !sameCompany(
                learnedSender,
                baseAnalysis.sender ?? ""
            ) {

                reasons.append(
                    "Absender \(learnedSender) wurde aus bestätigtem Lernen übernommen"
                )
            }

        } else {

            finalSender =
                baseAnalysis.sender

            finalSenderDetectedText =
                baseAnalysis.senderDetectedText
        }

        // MARK: Document Type

        let finalDocumentType:
            DocumentType

        let finalDocumentTypeDetectedText:
            String?

        // Eine bereits direkt erkannte Dokumentart
        // hat Vorrang vor gelerntem Erfahrungswissen.
        //
        // Lernen ergänzt die Dokumentart nur,
        // wenn die normale Analyse nichts erkannt hat.
        if baseAnalysis.documentType !=
            .unknown {

            finalDocumentType =
                baseAnalysis.documentType

            finalDocumentTypeDetectedText =
                baseAnalysis.documentTypeDetectedText

        } else {

            finalDocumentType =
                learnedEntry.documentType

            finalDocumentTypeDetectedText =
                nil

            if learnedEntry.documentType !=
                .unknown {

                reasons.append(
                    "Dokumentenart \(learnedEntry.documentType.rawValue) wurde aus bestätigtem Lernen ergänzt"
                )
            }
        }

        // MARK: Recipient

        // Einen schon erkannten Empfänger lassen wir
        // unangetastet. Nur bei fehlender Erkennung
        // ergänzt das bestätigte Archivwissen den Bereich.
        let finalRecipientArea =
            baseAnalysis.recipientArea
            ??
            learnedEntry.archiveArea

        if baseAnalysis.recipientArea == nil {

            reasons.append(
                "Empfängerbereich \(learnedEntry.archiveArea.rawValue) wurde aus bestätigtem Lernen ergänzt"
            )
        }

        return AtlasAnalysis(
            documentType:
                finalDocumentType,

            documentTypeDetectedText:
                finalDocumentTypeDetectedText,

            detectedDate:
                baseAnalysis.detectedDate,

            detectedDateText:
                baseAnalysis.detectedDateText,

            sender:
                finalSender,

            senderDetectedText:
                finalSenderDetectedText,

            recipientArea:
                finalRecipientArea,

            recipientDetectedText:
                baseAnalysis.recipientDetectedText,

            keywords:
                baseAnalysis.keywords,

            confidence:
                max(
                    baseAnalysis.confidence,
                    0.85
                ),

            reasons:
                reasons
        )
    }

    // MARK: - Layout Date Analysis

    private func applyLayoutDateAnalysis(
        to baseAnalysis: AtlasAnalysis,
        document: DocumentRecord,
        text: String
    ) async -> AtlasAnalysis {

        guard
            let sender =
                baseAnalysis.sender
        else {

            return baseAnalysis
        }

        guard
            let profile =
                DocumentLayoutProfile
                    .bestMatching(
                        company:
                            sender,
                        documentType:
                            baseAnalysis.documentType,
                        documentText:
                            text
                    )
        else {

            return baseAnalysis
        }

        let fieldRecognizer =
            LayoutFieldRecognizer()

        guard
            let rawDateText =
                await fieldRecognizer
                    .recognize(
                        field:
                            .date,
                        in:
                            document.sourceURL,
                        profile:
                            profile
                    )
        else {

            return baseAnalysis
        }

        let layoutDateRecognizer =
            LayoutDateRecognizer()

        guard
            let result =
                layoutDateRecognizer
                    .recognize(
                        from:
                            rawDateText
                    )
        else {

            return baseAnalysis
        }

        return replacingDate(
            in:
                baseAnalysis,
            with:
                result.date,
            detectedText:
                result.matchedText,
            reason:
                "Datum \(result.matchedText) wurde im bekannten Layout \(profile.name) erkannt (\(result.confirmations)× bestätigt)"
        )
    }

    private func replacingDate(
        in analysis: AtlasAnalysis,
        with date: Date,
        detectedText: String,
        reason: String
    ) -> AtlasAnalysis {

        var reasons =
            analysis.reasons.filter {

                !$0
                    .localizedCaseInsensitiveContains(
                        "Datum "
                    )
            }

        reasons.append(
            reason
        )

        return AtlasAnalysis(
            documentType:
                analysis.documentType,
            documentTypeDetectedText:
                analysis.documentTypeDetectedText,
            detectedDate:
                date,
            detectedDateText:
                detectedText,
            sender:
                analysis.sender,
            senderDetectedText:
                analysis.senderDetectedText,
            recipientArea:
                analysis.recipientArea,
            recipientDetectedText:
                analysis.recipientDetectedText,
            keywords:
                analysis.keywords,
            confidence:
                analysis.confidence,
            reasons:
                reasons
        )
    }

    // MARK: - Layout Recipient Analysis

    private func applyLayoutRecipientAnalysis(
        to baseAnalysis: AtlasAnalysis,
        document: DocumentRecord,
        text: String
    ) async -> AtlasAnalysis {

        guard
            let sender =
                baseAnalysis.sender
        else {

            return baseAnalysis
        }

        guard
            let profile =
                DocumentLayoutProfile
                    .bestMatching(
                        company:
                            sender,
                        documentType:
                            baseAnalysis.documentType,
                        documentText:
                            text
                    )
        else {

            return baseAnalysis
        }

        // Nur Layouts mit bewusst definiertem
        // Empfängerbereich werden zusätzlich gelesen.
        guard
            profile.archiveIdentityRegion != nil
        else {

            return baseAnalysis
        }

        let fieldRecognizer =
            LayoutFieldRecognizer()

        guard
            let recipientText =
                await fieldRecognizer
                    .recognize(
                        field:
                            .recipient,
                        in:
                            document.sourceURL,
                        profile:
                            profile
                    )
        else {

            return baseAnalysis
        }

        let recipientRecognizer =
            RecipientRecognizer()

        guard
            let result =
                recipientRecognizer
                    .detectResult(
                        in:
                            recipientText
                    )
        else {

            return baseAnalysis
        }

        return replacingRecipient(
            in:
                baseAnalysis,
            with:
                result.area,
            detectedText:
                result.matchedText,
            reason:
                "Empfänger \(result.matchedText) wurde im bekannten Layout \(profile.name) erkannt"
        )
    }

    private func replacingRecipient(
        in analysis: AtlasAnalysis,
        with recipientArea: ArchiveArea,
        detectedText: String,
        reason: String
    ) -> AtlasAnalysis {

        var reasons =
            analysis.reasons.filter {

                !$0
                    .localizedCaseInsensitiveContains(
                        "Empfänger "
                    )
            }

        reasons.append(
            reason
        )

        return AtlasAnalysis(
            documentType:
                analysis.documentType,
            documentTypeDetectedText:
                analysis.documentTypeDetectedText,
            detectedDate:
                analysis.detectedDate,
            detectedDateText:
                analysis.detectedDateText,
            sender:
                analysis.sender,
            senderDetectedText:
                analysis.senderDetectedText,
            recipientArea:
                recipientArea,
            recipientDetectedText:
                detectedText,
            keywords:
                analysis.keywords,
            confidence:
                analysis.confidence,
            reasons:
                reasons
        )
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

        if let boundingBox =
            visualResult.detectedCompanyBoundingBox {

            visualSenderBoundingBoxesByURL[
                url
            ] =
                boundingBox

        } else {

            visualSenderBoundingBoxesByURL
                .removeValue(
                    forKey:
                        url
                )
        }

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
    // MARK: - Visual Sender Comparison

    /// Vergleicht die visuelle Signatur des Dokuments
    /// gezielt mit bereits gelernten Signaturen
    /// einer bestimmten Firma.
    ///
    /// Dadurch kann die Korrekturansicht anzeigen:
    /// "97,2 % Ähnlichkeit mit VzF".
    func visualSimilarity(
        company: String,
        for document: DocumentRecord
    ) -> Double? {

        let cleanedCompany =
            company.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard
            !cleanedCompany.isEmpty,
            let currentSignature =
                visualSignaturesByURL[
                    document.sourceURL
                ]
        else {

            return nil
        }

        visualSenderLearningManager
            .reload()

        let entries =
            visualSenderLearningManager
                .entries
                .filter {

                    sameCompany(
                        $0.company,
                        cleanedCompany
                    )
                }

        var bestSimilarity:
            Double?

        for entry in entries {

            guard
                let similarity =
                    currentSignature.similarity(
                        to:
                            entry.signature
                    )
            else {

                continue
            }

            if bestSimilarity == nil
                ||
                similarity >
                    bestSimilarity! {

                bestSimilarity =
                    similarity
            }
        }

        return bestSimilarity
    }


    /// Liefert die bisher höchste Bestätigungszahl
    /// für die ausgewählte Firma.
    func visualConfirmationCount(
        company: String
    ) -> Int {

        let cleanedCompany =
            company.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard
            !cleanedCompany.isEmpty
        else {

            return 0
        }

        visualSenderLearningManager
            .reload()

        return visualSenderLearningManager
            .entries
            .filter {

                sameCompany(
                    $0.company,
                    cleanedCompany
                )
            }
            .map(
                \.confirmationCount
            )
            .max()
            ?? 0
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

        let previewPNGData =
            senderVisualRecognizer
                .previewPNGData(
                    for:
                        document.sourceURL
                )

        visualSenderLearningManager
            .confirm(
                company:
                    cleanedCompany,
                signature:
                    signature,
                previewPNGData:
                    previewPNGData
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
            documentTypeDetectedText:
                analysis.documentTypeDetectedText,
            detectedDate:
                analysis.detectedDate,
            detectedDateText:
                analysis.detectedDateText,
            sender:
                sender,
            senderDetectedText:
                analysis.senderDetectedText,
            recipientArea:
                analysis.recipientArea,
            recipientDetectedText:
                analysis.recipientDetectedText,
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

        visualSenderBoundingBox =
            visualSenderBoundingBoxesByURL[
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

        visualSenderBoundingBox =
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

        visualSenderBoundingBoxesByURL
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

        let storedText =
            extractedTextsByURL[
                document.sourceURL
            ]

        LearningEngine()
            .remember(
                analysis:
                    documentAnalysis,
                destination:
                    learnedSuggestion,
                documentText:
                    storedText
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
    // MARK: - Apply Corrected Analysis

    @discardableResult
    func applyCorrection(
        analysis correctedAnalysis: AtlasAnalysis,
        destinationURL: URL,
        confirmVisualSender: Bool,
        for document: DocumentRecord
    ) -> Bool {

        guard let destinationInfo =
            archiveDestinationInfo(
                for:
                    destinationURL
            )
        else {

            errorMessage =
                "Der gewählte Speicherort gehört zu keinem bekannten Archivbereich."

            return false
        }

        // Der gewählte Archivbereich und der vom
        // Benutzer bestätigte Empfänger müssen
        // zusammenpassen.
        if let recipientArea =
            correctedAnalysis.recipientArea,
           destinationInfo.area != recipientArea {

            errorMessage =
                "Der gewählte Speicherort gehört zu \(destinationInfo.area.rawValue), als Empfänger wurde aber \(recipientArea.rawValue) gewählt."

            return false
        }

        let correctedSuggestion =
            FolderSuggestion(
                ruleName:
                    "Vom Benutzer korrigiert",
                area:
                    destinationInfo.area,
                folder:
                    destinationInfo.relativePath,
                confidence:
                    1.0,
                reasons: [
                    "Angaben wurden vom Benutzer geprüft und korrigiert",
                    "Speicherort wurde vom Benutzer bestätigt"
                ]
            )

        analysesByURL[
            document.sourceURL
        ] =
            correctedAnalysis

        folderSuggestionsByURL[
            document.sourceURL
        ] =
            correctedSuggestion

        analysis =
            correctedAnalysis

        folderSuggestion =
            correctedSuggestion

        manualArchiveDestinationURL =
            destinationURL

        // Neue bzw. bestätigte Absender dauerhaft lernen.
        if let sender =
            correctedAnalysis.sender {

            let cleanedSender =
                sender.trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

            if !cleanedSender.isEmpty {

                // Firma in der allgemeinen Firmenliste merken.
                learnedCompanyStore.add(
                    cleanedSender
                )

                // MARK: - Text-/OCR-Firmenlernen

                // Den bereits aus PDF bzw. OCR gewonnenen
                // Dokumenttext verwenden.
                if let documentText =
                    extractedTextsByURL[
                        document.sourceURL
                    ],
                   !documentText.isEmpty {

                    learnedCompanySignatureStore
                        .learn(
                            company:
                                cleanedSender,
                            documentText:
                                documentText
                        )
                }

                // MARK: - Visuelles Firmenlernen

                // Die visuelle Signatur wird nur dann
                // ausdrücklich gelernt, wenn der Benutzer
                // im Korrekturfenster bestätigt hat:
                // "Grafik gehört definitiv zu ...".
                //
                // Eine normale Absenderkorrektur lernt
                // weiterhin Text/OCR, aber nicht automatisch
                // das grafische Erscheinungsbild.
                if confirmVisualSender,
                   let signature =
                    visualSignaturesByURL[
                        document.sourceURL
                    ] {

                    let previewPNGData =
                        senderVisualRecognizer
                            .previewPNGData(
                                for:
                                    document.sourceURL
                            )

                    visualSenderLearningManager
                        .confirm(
                            company:
                                cleanedSender,
                            signature:
                                signature,
                            previewPNGData:
                                previewPNGData
                        )
                }
            }
        }

        return true
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

    // MARK: - Edit Suggestions

    func suggestFilename(
        document: DocumentRecord,
        sender: String,
        documentType: DocumentType,
        date: Date?
    ) -> String {

        let cleanedSender =
            sender.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let temporaryAnalysis =
            AtlasAnalysis(
                documentType: documentType,
                detectedDate: date,
                sender: cleanedSender.isEmpty
                    ? nil
                    : cleanedSender,
                recipientArea: analysis?.recipientArea,
                keywords: analysis?.keywords ?? [],
                confidence: 1.0,
                reasons: []
            )

        return buildFilenameSuggestion(
            from: temporaryAnalysis,
            fallbackDocument: document
        )
    }

    func suggestArchiveDestination(
        recipientArea: ArchiveArea,
        sender: String,
        documentType: DocumentType,
        for document: DocumentRecord
    ) -> FolderSuggestion? {
        
        let cleanedSender =
            sender.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let temporaryAnalysis =
            AtlasAnalysis(
                documentType: documentType,
                detectedDate: analysis?.detectedDate,
                sender: cleanedSender.isEmpty
                    ? nil
                    : cleanedSender,
                recipientArea: recipientArea,
                keywords: analysis?.keywords ?? [],
                confidence: 1.0,
                reasons: []
            )

        let text =
            extractedTextsByURL[
                document.sourceURL
            ] ?? ""

        return folderSuggestionEngine
            .suggestFolder(
                for: temporaryAnalysis,
                text: text
            )
    }


    // MARK: - Archive Destination URL

    func suggestArchiveDestinationURL(
        recipientArea: ArchiveArea,
        sender: String,
        documentType: DocumentType,
        for document: DocumentRecord
    ) -> URL? {

        guard
            let suggestion =
                suggestArchiveDestination(
                    recipientArea:
                        recipientArea,
                    sender:
                        sender,
                    documentType:
                        documentType,
                    for:
                        document
                )
        else {

            return nil
        }

        guard
            let workspace =
                archiveWorkspaceStore
                    .workspace(
                        matching:
                            suggestion.area
                    )
        else {

            return nil
        }

        guard
            let archiveRootURL =
                archiveWorkspaceStore
                    .folderURL(
                        for:
                            workspace
                    )
        else {

            return nil
        }

        do {

            return try archiveDestinationResolver
                .resolve(
                    rootURL:
                        archiveRootURL,
                    relativePath:
                        suggestion.folder
                )

        } catch {

            print(
                """
                ⚠️ Atlas konnte den vorgeschlagenen Speicherort nicht auflösen:
                \(suggestion.area.rawValue) → \(suggestion.folder)

                \(error.localizedDescription)
                """
            )

            return nil
        }
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

            let previousInitialAnalysis =
                initialAnalysesByURL[
                    sourceURL
                ]

            let previousInitialFolderSuggestion =
                initialFolderSuggestionsByURL[
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

            let previousBoundingBox =
                visualSenderBoundingBoxesByURL[
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

            initialAnalysesByURL
                .removeValue(
                    forKey:
                        sourceURL
                )

            initialFolderSuggestionsByURL
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

            if let previousInitialAnalysis {

                initialAnalysesByURL[
                    destinationURL
                ] =
                    previousInitialAnalysis
            }

            if let previousInitialFolderSuggestion {

                initialFolderSuggestionsByURL[
                    destinationURL
                ] =
                    previousInitialFolderSuggestion
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

            if let previousBoundingBox {

                visualSenderBoundingBoxesByURL[
                    destinationURL
                ] =
                    previousBoundingBox
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

    // MARK: - Atlas Learning Record

    private func saveLearningRecord(
        for document: DocumentRecord,
        finalDestinationURL: URL,
        destinationWasManual: Bool
    ) {

        let url =
            document.sourceURL

        guard
            let finalAnalysis =
                analysesByURL[
                    url
                ] ?? analysis
        else {

            return
        }

        let initialAnalysis =
            initialAnalysesByURL[
                url
            ]
            ?? finalAnalysis

        let initialFolderSuggestion =
            initialFolderSuggestionsByURL[
                url
            ]

        let finalDestinationInfo =
            archiveDestinationInfo(
                for:
                    finalDestinationURL
            )

        let record =
            AtlasLearningRecord(
                filename:
                    document.sourceURL
                        .lastPathComponent,
                suggestedSender:
                    initialAnalysis.sender,
                finalSender:
                    finalAnalysis.sender,
                suggestedRecipient:
                    initialAnalysis.recipientArea?
                        .rawValue,
                finalRecipient:
                    finalAnalysis.recipientArea?
                        .rawValue,
                suggestedDocumentType:
                    initialAnalysis.documentType
                        .rawValue,
                finalDocumentType:
                    finalAnalysis.documentType
                        .rawValue,
                suggestedDate:
                    initialAnalysis.detectedDate,
                finalDate:
                    finalAnalysis.detectedDate,
                suggestedArchiveArea:
                    initialFolderSuggestion?
                        .area
                        .rawValue,
                finalArchiveArea:
                    finalDestinationInfo?
                        .area
                        .rawValue,
                suggestedFolder:
                    initialFolderSuggestion?
                        .folder,
                finalFolder:
                    finalDestinationInfo?
                        .relativePath,
                archiveDestinationWasManual:
                    destinationWasManual
            )

        atlasLearningStore
            .append(
                record
            )

        print(
            """
            🧠 Atlas Lernprotokoll
            --------------------
            \(record.filename)
            Absender korrigiert: \(record.senderWasCorrected)
            Empfänger korrigiert: \(record.recipientWasCorrected)
            Dokumentart korrigiert: \(record.documentTypeWasCorrected)
            Datum korrigiert: \(record.dateWasCorrected)
            --------------------
            """
        )
    }

    // MARK: - Archive

    func archive(
        document: DocumentRecord
    ) async -> Bool {

        errorMessage =
            nil

        archiveConflict =
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

            let sourceURL =
                document.sourceURL

            // MARK: - Existing File Check

            let expectedTargetURL =
                destinationFolderURL
                    .appendingPathComponent(
                        sourceURL.lastPathComponent
                    )

            if FileManager.default
                .fileExists(
                    atPath:
                        expectedTargetURL.path
                ) {

                let suggestedFilename =
                    nextAvailableArchiveFilename(
                        originalFilename:
                            sourceURL.lastPathComponent,
                        destinationFolderURL:
                            destinationFolderURL
                    )

                let sourcePath =
                    sourceURL.path

                let existingPath =
                    expectedTargetURL.path

                let isIdentical =
                    await Task.detached(
                        priority:
                            .userInitiated
                    ) {

                        FileManager.default
                            .contentsEqual(
                                atPath:
                                    sourcePath,
                                andPath:
                                    existingPath
                            )
                    }
                    .value

                archiveConflict =
                    ArchiveConflict(
                        sourceURL:
                            sourceURL,
                        existingURL:
                            expectedTargetURL,
                        suggestedFilename:
                            suggestedFilename,
                        isIdentical:
                            isIdentical
                    )

                if isIdentical {

                    errorMessage =
                        """
                        Dieses Dokument ist bereits im Archiv vorhanden.

                        Die vorhandene Datei ist inhaltlich identisch.
                        """

                } else {

                    errorMessage =
                        """
                        Im Zielordner existiert bereits eine Datei mit diesem Namen.

                        Der Inhalt der beiden Dateien ist unterschiedlich.
                        """
                }

                return false
            }

            // MARK: - Move File

            let fileMover =
                archiveFileMover

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

            saveLearningRecord(
                for:
                    document,
                finalDestinationURL:
                    destinationFolderURL,
                destinationWasManual:
                    manualDestinationForLearning != nil
            )

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

            initialAnalysesByURL
                .removeValue(
                    forKey:
                        document.sourceURL
                )

            initialFolderSuggestionsByURL
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

            archiveConflict =
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

    // MARK: - Archive Conflict Helpers

    private func nextAvailableArchiveFilename(
        originalFilename: String,
        destinationFolderURL: URL
    ) -> String {

        let originalURL =
            URL(
                fileURLWithPath:
                    originalFilename
            )

        let filenameWithoutExtension =
            originalURL
                .deletingPathExtension()
                .lastPathComponent

        let fileExtension =
            originalURL
                .pathExtension

        var counter =
            1

        while true {

            let candidateName =
                "\(filenameWithoutExtension) (\(counter))"

            let candidateURL:
                URL

            if fileExtension.isEmpty {

                candidateURL =
                    destinationFolderURL
                        .appendingPathComponent(
                            candidateName
                        )

            } else {

                candidateURL =
                    destinationFolderURL
                        .appendingPathComponent(
                            candidateName
                        )
                        .appendingPathExtension(
                            fileExtension
                        )
            }

            if !FileManager.default
                .fileExists(
                    atPath:
                        candidateURL.path
                ) {

                return candidateURL
                    .lastPathComponent
            }

            counter +=
                1
        }
    }

    // MARK: - Resolve Archive Conflict

    func archiveConflictUsingSuggestedFilename() async -> Bool {

        guard let conflict =
            archiveConflict
        else {

            errorMessage =
                "Es ist kein Archivkonflikt vorhanden."

            return false
        }

        // Bei identischen Dokumenten soll keine
        // zweite Kopie angelegt werden.
        guard !conflict.isIdentical
        else {

            errorMessage =
                "Das Dokument ist bereits identisch im Archiv vorhanden."

            return false
        }

        let sourceURL =
            conflict.sourceURL

        guard let document =
            documents.first(
                where: {

                    $0.sourceURL ==
                        sourceURL
                }
            )
        else {

            errorMessage =
                "Das zu archivierende Dokument wurde nicht mehr in der Inbox gefunden."

            return false
        }

        let suggestedName =
            URL(
                fileURLWithPath:
                    conflict.suggestedFilename
            )
            .deletingPathExtension()
            .lastPathComponent

        guard let renamedDocument =
            rename(
                document:
                    document,
                to:
                    suggestedName
            )
        else {

            return false
        }

        archiveConflict =
            nil

        return await archive(
            document:
                renamedDocument
        )
    }

    // MARK: - Remove Identical Duplicate

    func removeIdenticalArchiveDuplicate() -> Bool {

        errorMessage =
            nil

        guard let conflict =
            archiveConflict
        else {

            errorMessage =
                "Es ist kein Archivkonflikt vorhanden."

            return false
        }

        guard conflict.isIdentical
        else {

            errorMessage =
                "Die beiden Dokumente sind nicht identisch."

            return false
        }

        let sourceURL =
            conflict.sourceURL

        do {

            try FileManager.default
                .removeItem(
                    at:
                        sourceURL
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

            initialAnalysesByURL
                .removeValue(
                    forKey:
                        sourceURL
                )

            initialFolderSuggestionsByURL
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

            archiveConflict =
                nil

            manualArchiveDestinationURL =
                nil

            loadDocuments()

            clearAnalysis()

            return true

        } catch {

            errorMessage =
                "Das Duplikat konnte nicht aus dem Eingang entfernt werden: \(error.localizedDescription)"

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

        initialAnalysesByURL =
            [:]

        initialFolderSuggestionsByURL =
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

        visualSenderBoundingBoxesByURL =
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

            let calendar =
                Calendar(
                    identifier:
                        .gregorian
                )

            let year =
                calendar.component(
                    .year,
                    from:
                        date
                )

            // Letzte Sicherheitsstufe:
            // Nur plausible Jahre dürfen
            // in den Dateinamen übernommen werden.
            if year >= 1900,
               year <= 2099 {

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
