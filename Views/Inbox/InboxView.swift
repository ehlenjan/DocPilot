import SwiftUI
import UniformTypeIdentifiers

struct InboxView: View {

    @State private var viewModel =
        InboxViewModel()

    @State private var archiveViewModel =
        ArchiveViewModel()

    @State private var isChoosingFolder =
        false

    @State private var selectedDocument:
        DocumentRecord?

    @State private var filenameDraft =
        ""

    @State private var lastAutomaticFilenameSuggestion =
        ""

    // MARK: - Atlas Edit

    /// Echte URL des im Korrekturfenster
    /// verwendeten Archivziels.
    @State private var atlasEditDestinationURL:
        URL?

    // MARK: - Persistent Split Widths

    /// Wird dauerhaft in UserDefaults gespeichert.
    /// Dadurch bleiben die Spaltenbreiten auch nach
    /// einem Programmneustart erhalten.
    @AppStorage("docpilot.inbox.leftPaneWidth.v3")
    private var leftPaneWidth:
        Double = 300

    @AppStorage("docpilot.inbox.rightPaneWidth.v3")
    private var rightPaneWidth:
        Double = 340

    /// Startwerte während eines laufenden Ziehvorgangs.
    @State private var leftDragStartWidth:
        Double?

    @State private var rightDragStartWidth:
        Double?

    // MARK: - Body

    var body: some View {

        Group {

            if let folderURL =
                viewModel.folderURL {

                inboxContent(
                    folderURL:
                        folderURL
                )

            } else {

                EmptyInboxView(
                    errorMessage:
                        viewModel.errorMessage,
                    onChooseFolder: {

                        isChoosingFolder =
                            true
                    }
                )
            }
        }
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity,
            alignment:
                .topLeading
        )

        // MARK: - Inbox Folder Picker

        .fileImporter(
            isPresented:
                $isChoosingFolder,
            allowedContentTypes: [
                .folder
            ],
            allowsMultipleSelection:
                false
        ) { result in

            handleFolderSelection(
                result
            )
        }

        // MARK: - Initial Load

        .onAppear {

            viewModel.loadDocuments()

            archiveViewModel.reload()
        }

        // MARK: - Document Selection

        .onChange(
            of:
                selectedDocument
        ) { _, newDocument in

            // Falls noch ein Korrekturfenster
            // für das vorherige Dokument offen ist,
            // schließen wir es.
            AtlasEditPanelController
                .shared
                .close()

            filenameDraft =
                newDocument?
                    .sourceURL
                    .deletingPathExtension()
                    .lastPathComponent
                ?? ""

            lastAutomaticFilenameSuggestion =
                ""

            atlasEditDestinationURL =
                nil

            viewModel.selectAnalysis(
                for:
                    newDocument
            )

            if let newDocument {

                applyAutomaticFilenameSuggestion(
                    for:
                        newDocument
                )
            }
        }

        // MARK: - Automatic Filename Suggestion

        .onChange(
            of:
                selectedAnalysisSignature
        ) { _, newSignature in

            guard
                !newSignature.isEmpty,
                let document =
                    selectedDocument
            else {

                return
            }

            applyAutomaticFilenameSuggestion(
                for:
                    document
            )
        }
        // MARK: - Archive Conflict

        .onChange(
            of:
                viewModel.archiveConflict
        ) { _, newConflict in

            guard let conflict =
                newConflict
            else {

                ArchiveConflictPanelController
                    .shared
                    .close()

                return
            }

            ArchiveConflictPanelController
                .shared
                .show(
                    conflict:
                        conflict,

                    onUseSuggestedFilename: {

                        Task {

                            let preferredIndex =
                                indexForDocument(
                                    sourceURL:
                                        conflict.sourceURL
                                )

                            let success:
                                Bool

                            if conflict.isIdentical {

                                success =
                                    viewModel
                                        .removeIdenticalArchiveDuplicate()

                            } else {

                                success =
                                    await viewModel
                                        .archiveConflictUsingSuggestedFilename()
                            }

                            guard success
                            else {

                                return
                            }

                            AtlasEditPanelController
                                .shared
                                .close()

                            ArchiveConflictPanelController
                                .shared
                                .close()

                            atlasEditDestinationURL =
                                nil

                            selectNextDocument(
                                preferredIndex:
                                    preferredIndex
                            )
                        }
                    },

                    onChangeFilename: {

                        // Das Korrekturfenster bleibt
                        // weiterhin geöffnet.
                        // Dort kann der Dateiname geändert
                        // und erneut archiviert werden.

                        viewModel.archiveConflict =
                            nil
                    },

                    onCancel: {

                        viewModel.archiveConflict =
                            nil
                    }
                )
        }
    }

    // MARK: - Analysis Signature

    private var selectedAnalysisSignature:
        String {

        guard
            let document =
                selectedDocument,
            let analysis =
                viewModel.analysis(
                    for:
                        document
                )
        else {

            return ""
        }

        let dateValue =
            analysis.detectedDate?
                .timeIntervalSince1970
            ?? 0

        let senderValue =
            analysis.sender
            ?? ""

        let recipientValue =
            analysis.recipientArea?
                .rawValue
            ?? ""

        let keywordValue =
            analysis.keywords
                .joined(
                    separator:
                        "|"
                )

        return [
            document.sourceURL.path,
            analysis.documentType.rawValue,
            String(
                dateValue
            ),
            senderValue,
            recipientValue,
            keywordValue,
            String(
                analysis.confidence
            )
        ]
        .joined(
            separator:
                "§"
        )
    }

    // MARK: - Preferred Edit Sender

    /// Wenn Text- und Grafikerkennung
    /// unterschiedliche Absender erkennen,
    /// wird beim Öffnen der Korrektur zunächst
    /// der visuelle Vorschlag verwendet.
    private var preferredEditSender:
        String {

        let textSender =
            viewModel.analysis?
                .sender?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        let visualSender =
            viewModel
                .visualSenderSuggestion?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        guard
            !visualSender.isEmpty
        else {

            return textSender
        }

        guard
            !textSender.isEmpty
        else {

            return visualSender
        }

        let normalizedText =
            normalizeCompany(
                textSender
            )

        let normalizedVisual =
            normalizeCompany(
                visualSender
            )

        if normalizedText !=
            normalizedVisual {

            return visualSender
        }

        return textSender
    }

    // MARK: - Automatic Filename

    private func applyAutomaticFilenameSuggestion(
        for document: DocumentRecord
    ) {

        guard
            viewModel.analysis(
                for: document
            ) != nil
        else {
            return
        }

        let suggestion =
            viewModel
                .suggestFilename(
                    for: document
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard !suggestion.isEmpty
        else {
            return
        }

        filenameDraft =
            suggestion

        lastAutomaticFilenameSuggestion =
            suggestion
    }
    // MARK: - Content

    private func inboxContent(
        folderURL:
            URL
    ) -> some View {

        VStack(spacing: 0) {

            InboxHeaderView(
                folderURL:
                    folderURL,

                documentCount:
                    viewModel
                        .documents
                        .count,

                onReload: {

                    reloadDocuments()
                },

                onChooseFolder: {

                    isChoosingFolder =
                        true
                }
            )

            Divider()

            if let errorMessage =
                viewModel.errorMessage {

                ContentUnavailableView(
                    "Aktion fehlgeschlagen",
                    systemImage:
                        "exclamationmark.triangle",
                    description:
                        Text(
                            errorMessage
                        )
                )
                .frame(
                    maxWidth:
                        .infinity,
                    maxHeight:
                        .infinity
                )

            } else if
                viewModel.documents.isEmpty {

                EmptyDocumentListView()
                    .frame(
                        maxWidth:
                            .infinity,
                        maxHeight:
                            .infinity
                    )

            } else {

                documentBrowser
            }
        }
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity,
            alignment:
                .topLeading
        )
    }

    // MARK: - Document Browser

    private var documentBrowser:
        some View {

        GeometryReader {
            geometry in

            HStack(
                spacing: 0
            ) {

                // MARK: Dokumentliste

                DocumentListView(
                    documents:
                        viewModel.documents,

                    analysisForDocument: {
                        document in

                        viewModel.analysis(
                            for:
                                document
                        )
                    },

                    selection:
                        $selectedDocument
                )
                .frame(
                    width:
                        CGFloat(
                            leftPaneWidth
                        )
                )
                .frame(
                    maxHeight:
                        .infinity,
                    alignment:
                        .top
                )

                leftSplitDivider

                // MARK: PDF-Vorschau

                documentPreview
                    .frame(
                        minWidth:
                            420,
                        maxWidth:
                            .infinity,
                        maxHeight:
                            .infinity,
                        alignment:
                            .top
                    )

                rightSplitDivider

                // MARK: Atlas

                atlasReview
                    .frame(
                        width:
                            CGFloat(
                                rightPaneWidth
                            )
                    )
                    .frame(
                        maxHeight:
                            .infinity,
                        alignment:
                            .top
                    )
            }
            .frame(
                width:
                    geometry.size.width,
                height:
                    geometry.size.height,
                alignment:
                    .topLeading
            )
            .onAppear {

                normalizeSplitWidths(
                    totalWidth:
                        geometry.size.width
                )
            }
            .onChange(
                of:
                    geometry.size.width
            ) { _, newWidth in

                normalizeSplitWidths(
                    totalWidth:
                        newWidth
                )
            }
        }
    }

    // MARK: - Split Dividers

    private var leftSplitDivider:
        some View {

        splitDivider
            .gesture(
                DragGesture()
                    .onChanged {
                        value in

                        if leftDragStartWidth ==
                            nil {

                            leftDragStartWidth =
                                leftPaneWidth
                        }

                        let start =
                            leftDragStartWidth
                            ?? leftPaneWidth

                        let proposed =
                            start +
                            Double(
                                value.translation.width
                            )

                        leftPaneWidth =
                            min(
                                max(
                                    proposed,
                                    240
                                ),
                                420
                            )
                    }
                    .onEnded { _ in

                        leftDragStartWidth =
                            nil
                    }
            )
            .help(
                "Breite der Dokumentliste ändern"
            )
    }

    private var rightSplitDivider:
        some View {

        splitDivider
            .gesture(
                DragGesture()
                    .onChanged {
                        value in

                        if rightDragStartWidth ==
                            nil {

                            rightDragStartWidth =
                                rightPaneWidth
                        }

                        let start =
                            rightDragStartWidth
                            ?? rightPaneWidth

                        // Ziehen nach rechts:
                        // Atlas-Bereich wird schmaler.
                        let proposed =
                            start -
                            Double(
                                value.translation.width
                            )

                        rightPaneWidth =
                            min(
                                max(
                                    proposed,
                                    340
                                ),
                                520
                            )
                    }
                    .onEnded { _ in

                        rightDragStartWidth =
                            nil
                    }
            )
            .help(
                "Breite des Atlas-Bereichs ändern"
            )
    }

    private var splitDivider:
        some View {

        Rectangle()
            .fill(
                Color.clear
            )
            .frame(
                width: 8
            )
            .overlay {

                Rectangle()
                    .fill(
                        Color(
                            nsColor:
                                .separatorColor
                        )
                    )
                    .frame(
                        width: 1
                    )
            }
            .contentShape(
                Rectangle()
            )
    }

    // MARK: - Split Width Validation

    private func normalizeSplitWidths(
        totalWidth: CGFloat
    ) {

        // Normale Grenzen unabhängig von
        // Dokumentwechseln oder Archivierung.
        leftPaneWidth =
            min(
                max(
                    leftPaneWidth,
                    240
                ),
                420
            )

        rightPaneWidth =
            min(
                max(
                    rightPaneWidth,
                    340
                ),
                520
            )

        // Bei einem sehr schmalen Fenster muss
        // die PDF-Mitte mindestens 420 pt behalten.
        let dividerSpace:
            Double = 16

        let minimumPDFWidth:
            Double = 360

        let availableForSides =
            max(
                0,
                Double(
                    totalWidth
                )
                -
                minimumPDFWidth
                -
                dividerSpace
            )

        let currentSides =
            leftPaneWidth +
            rightPaneWidth

        guard
            currentSides >
                availableForSides,
            availableForSides >
                0
        else {

            return
        }

        // Zuerst die linke Liste reduzieren,
        // da dort am ehesten Platz eingespart
        // werden kann.
        let excess =
            currentSides -
            availableForSides

        let reducibleLeft =
            max(
                0,
                leftPaneWidth -
                240
            )

        let leftReduction =
            min(
                excess,
                reducibleLeft
            )

        leftPaneWidth -=
            leftReduction

        let remainingExcess =
            excess -
            leftReduction

        if remainingExcess >
            0 {

            rightPaneWidth =
                max(
                    340,
                    rightPaneWidth -
                    remainingExcess
                )
        }
    }

    // MARK: - PDF Evidence

    private func pdfEvidence(
        for document: DocumentRecord
    ) -> [PDFEvidence] {

        guard
            let analysis =
                viewModel.analysis(
                    for: document
                )
        else {

            return []
        }

        var result:
            [PDFEvidence] = []

        // MARK: Datum

        if let detectedDateText =
            analysis.detectedDateText?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
           !detectedDateText.isEmpty {

            result.append(
                PDFEvidence(
                    text:
                        detectedDateText,
                    kind:
                        .date
                )
            )
        }

        // MARK: Absender

        if let senderDetectedText =
            analysis.senderDetectedText?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
           !senderDetectedText.isEmpty {

            result.append(
                PDFEvidence(
                    text:
                        senderDetectedText,
                    kind:
                        .sender
                )
            )
        }
        
        // MARK: Empfänger

        if let recipientDetectedText =
            analysis.recipientDetectedText?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
           !recipientDetectedText.isEmpty {

            result.append(
                PDFEvidence(
                    text:
                        recipientDetectedText,
                    kind:
                        .recipient
                )
            )
        }
        
        // MARK: Dokumentenart

        if let documentTypeDetectedText =
            analysis.documentTypeDetectedText?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
           !documentTypeDetectedText.isEmpty {

            result.append(
                PDFEvidence(
                    text:
                        documentTypeDetectedText,
                    kind:
                        .documentType
                )
            )
        }
        return result
    }
    // MARK: - PDF Preview

    @ViewBuilder
    private var documentPreview:
        some View {

        if let document =
            selectedDocument {

            PDFPreviewView(
                url:
                    document.sourceURL,
                evidence:
                    pdfEvidence(
                        for:
                            document
                    ),
                visualSenderBoundingBox:
                    viewModel.visualSenderBoundingBox
            )
            .frame(
                minWidth:
                    420,
                maxWidth:
                    .infinity,
                maxHeight:
                    .infinity
            )

        } else {

            EmptySelectionView(
                title:
                    "Kein Dokument ausgewählt",
                systemImage:
                    "doc.text.magnifyingglass",
                description:
                    "Wähle links eine PDF-Datei aus, um sie anzuzeigen."
            )
            .frame(
                minWidth:
                    420,
                maxWidth:
                    .infinity,
                maxHeight:
                    .infinity
            )
        }
    }
    // MARK: - Atlas Review

    @ViewBuilder
    private var atlasReview:
        some View {

        if let document =
            selectedDocument {

            AtlasReviewView(
                document:
                    document,

                analysis:
                    viewModel.analysis,

                folderSuggestion:
                    viewModel.folderSuggestion,

                filenameDraft:
                    filenameDraft,

                // MARK: Visuelle Absendererkennung

                visualSenderSuggestion:
                    viewModel
                        .visualSenderSuggestion,

                visualSenderSimilarity:
                    viewModel
                        .visualSenderSimilarity,

                visualSenderConfirmationCount:
                    viewModel
                        .visualSenderConfirmationCount,

                isArchiving:
                    viewModel.isArchiving,

                // MARK: Alles stimmt

                onArchive: {

                    archiveReviewedDocument(
                        document
                    )
                },

                // MARK: Angaben korrigieren

                onEdit: {

                    openAtlasEditPanel(
                        for:
                            document
                    )
                }
            )
            .frame(
                minWidth:
                    360,
                idealWidth:
                    430,
                maxWidth:
                    520,
                maxHeight:
                    .infinity,
                alignment:
                    .top
            )

        } else {

            EmptySelectionView(
                title:
                    "Atlas wartet",
                systemImage:
                    "brain.head.profile",
                description:
                    "Wähle ein Dokument aus, damit Atlas es analysieren kann."
            )
            .frame(
                minWidth:
                    360,
                idealWidth:
                    430,
                maxWidth:
                    520,
                maxHeight:
                    .infinity
            )
        }
    }

    // MARK: - Open Atlas Edit Panel

    private func openAtlasEditPanel(
        for document:
            DocumentRecord
    ) {

        // Wenn bereits ein manuelles Ziel
        // existiert, verwenden wir dieses.
        //
        // Ansonsten startet AtlasEditView ohne
        // festgelegte URL und kann mit seiner
        // neuen Automatik selbst einen real
        // vorhandenen Zielordner finden.
        if let manualURL =
            viewModel
                .manualArchiveDestinationURL {

            atlasEditDestinationURL =
                manualURL

        } else {

            atlasEditDestinationURL =
                nil
        }

        AtlasEditPanelController
            .shared
            .show(
                document:
                    document,

                availableCompanies:
                    viewModel
                        .availableVisualSenderCompanies,

                initialRecipientArea:
                    viewModel.analysis?
                        .recipientArea
                    ?? .business,

                initialSender:
                    preferredEditSender,

                initialDocumentType:
                    viewModel.analysis?
                        .documentType
                    ?? .unknown,

                initialDate:
                    viewModel.analysis?
                        .detectedDate,

                destinationURL:
                    $atlasEditDestinationURL,

                initialFilename:
                    filenameDraft,

                archiveViewModel:
                    archiveViewModel,

                suggestArchiveDestination: {
                    recipientArea,
                    sender,
                    documentType,
                    document in

                    viewModel
                        .suggestArchiveDestinationURL(
                            recipientArea:
                                recipientArea,
                            sender:
                                sender,
                            documentType:
                                documentType,
                            for:
                                document
                        )
                },
                visualSimilarity: {
                    company,
                    document in

                    viewModel
                        .visualSimilarity(
                            company:
                                company,
                            for:
                                document
                        )
                },

                visualConfirmationCount: {
                    company in

                    viewModel
                        .visualConfirmationCount(
                            company:
                                company
                        )
                },

                isWorking:
                    viewModel.isArchiving,

                onSaveAndArchive: {
                    values in

                    saveCorrectionAndArchive(
                        values:
                            values,
                        document:
                            document
                    )
                }
            )
    }

    // MARK: - Save Correction + Archive

    private func saveCorrectionAndArchive(
        values:
            AtlasEditValues,
        document:
            DocumentRecord
    ) {

        guard let destinationURL =
            values.destinationURL
        else {

            viewModel.errorMessage =
                "Bitte wähle einen Speicherort aus."

            return
        }

        // Schlüsselwörter werden weiterhin
        // automatisch von Atlas verwaltet.
        let existingKeywords =
            viewModel
                .analysis(
                    for:
                        document
                )?
                .keywords
            ?? []

        let correctedAnalysis =
            AtlasAnalysis(
                documentType:
                    values.documentType,

                detectedDate:
                    values.detectedDate,

                sender:
                    values.sender,

                recipientArea:
                    values.recipientArea,

                keywords:
                    existingKeywords,

                confidence:
                    1.0,

                reasons: [
                    "Angaben wurden vom Benutzer geprüft und korrigiert",
                    "Empfänger wurde vom Benutzer bestätigt",
                    "Absender wurde vom Benutzer bestätigt",
                    "Dokumentart wurde vom Benutzer bestätigt",
                    "Speicherort wurde vom Benutzer bestätigt"
                ]
            )

        // Korrigierte Analyse und echten
        // Speicherort im ViewModel speichern.
        let applied =
            viewModel.applyCorrection(
                analysis:
                    correctedAnalysis,
                destinationURL:
                    destinationURL,
                confirmVisualSender:
                    values.confirmVisualSender,
                for:
                    document
            )

        guard applied
        else {

            return
        }

        let correctedFilename =
            values.filename
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        filenameDraft =
            correctedFilename

        // Benutzer hat diesen Dateinamen
        // ausdrücklich bestätigt.
        lastAutomaticFilenameSuggestion =
            correctedFilename

        Task {

            let preferredIndex =
                indexForDocument(
                    sourceURL:
                        document.sourceURL
                )

            var documentToArchive =
                document

            let currentFilename =
                document
                    .sourceURL
                    .deletingPathExtension()
                    .lastPathComponent

            // MARK: Rename

            if !correctedFilename.isEmpty &&
                correctedFilename !=
                    currentFilename {

                guard let renamedDocument =
                    viewModel.rename(
                        document:
                            document,
                        to:
                            correctedFilename
                    )
                else {

                    return
                }

                documentToArchive =
                    renamedDocument
            }

            // MARK: Archive

            let success =
                await viewModel.archive(
                    document:
                        documentToArchive
                )

            guard success
            else {

                return
            }

            // MARK: Cleanup

            atlasEditDestinationURL =
                nil

            selectNextDocument(
                preferredIndex:
                    preferredIndex
            )
        }
    }

    // MARK: - Archive Reviewed Document

    private func archiveReviewedDocument(
        _ document:
            DocumentRecord
    ) {

        Task {

            let preferredIndex =
                indexForDocument(
                    sourceURL:
                        document.sourceURL
                )

            var documentToArchive =
                document

            let currentFilename =
                document
                    .sourceURL
                    .deletingPathExtension()
                    .lastPathComponent

            let cleanedDraft =
                filenameDraft
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            // Den Atlas-Dateinamen zuerst
            // auf die PDF anwenden.
            if !cleanedDraft.isEmpty &&
                cleanedDraft !=
                    currentFilename {

                guard let renamedDocument =
                    viewModel.rename(
                        document:
                            document,
                        to:
                            cleanedDraft
                    )
                else {

                    return
                }

                documentToArchive =
                    renamedDocument
            }

            let success =
                await viewModel.archive(
                    document:
                        documentToArchive
                )

            if success {

                AtlasEditPanelController
                    .shared
                    .close()

                atlasEditDestinationURL =
                    nil

                selectNextDocument(
                    preferredIndex:
                        preferredIndex
                )
            }
        }
    }

    // MARK: - Next Document

    private func indexForDocument(
        sourceURL: URL
    ) -> Int {

        viewModel.documents
            .firstIndex(
                where: {

                    $0.sourceURL ==
                        sourceURL
                }
            )
        ?? 0
    }

    private func selectNextDocument(
        preferredIndex: Int
    ) {

        guard
            !viewModel.documents.isEmpty
        else {

            selectedDocument =
                nil

            filenameDraft =
                ""

            lastAutomaticFilenameSuggestion =
                ""

            atlasEditDestinationURL =
                nil

            return
        }

        let nextIndex =
            min(
                preferredIndex,
                viewModel.documents.count - 1
            )

        let nextDocument =
            viewModel.documents[
                nextIndex
            ]

        // Die Dokumentliste wurde beim Archivieren
        // bereits neu geladen. Zuerst die alte, nun
        // nicht mehr vorhandene Auswahl lösen.
        selectedDocument =
            nil

        // SwiftUI einen UI-Zyklus geben, damit die
        // erneuerte Liste die neue Auswahl sicher
        // übernehmen kann.
        Task { @MainActor in

            await Task.yield()

            selectedDocument =
                nextDocument
        }
    }

    // MARK: - Folder Selection

    private func handleFolderSelection(
        _ result:
            Result<[URL], Error>
    ) {

        switch result {

        case .success(let urls):

            guard let selectedFolder =
                urls.first
            else {

                return
            }

            AtlasEditPanelController
                .shared
                .close()

            selectedDocument =
                nil

            filenameDraft =
                ""

            lastAutomaticFilenameSuggestion =
                ""

            atlasEditDestinationURL =
                nil

            viewModel.clearAnalysis()

            viewModel.selectFolder(
                selectedFolder
            )

        case .failure(let error):

            viewModel.errorMessage =
                "Ordner konnte nicht ausgewählt werden: \(error.localizedDescription)"
        }
    }

    // MARK: - Reload

    private func reloadDocuments() {

        let previousURL =
            selectedDocument?
                .sourceURL

        AtlasEditPanelController
            .shared
            .close()

        viewModel.loadDocuments()

        if let previousURL,
           let refreshedDocument =
            viewModel.documents.first(
                where: {

                    $0.sourceURL ==
                        previousURL
                }
            ) {

            selectedDocument =
                refreshedDocument

            viewModel.selectAnalysis(
                for:
                    refreshedDocument
            )

            applyAutomaticFilenameSuggestion(
                for:
                    refreshedDocument
            )

        } else {

            selectedDocument =
                nil

            filenameDraft =
                ""

            lastAutomaticFilenameSuggestion =
                ""

            atlasEditDestinationURL =
                nil

            viewModel.clearAnalysis()
        }
    }
   
    // MARK: - Normalize Company

    private func normalizeCompany(
        _ value:
            String
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
}

// MARK: - Preview

#Preview {

    InboxView()
        .frame(
            width:
                1400,
            height:
                800
        )
}
