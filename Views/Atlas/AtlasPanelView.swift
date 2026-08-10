import SwiftUI
import UniformTypeIdentifiers

struct AtlasPanelView: View {

    @State private var analysisExpanded =
        false

    @State private var learningExpanded =
        false

    @State private var fileExpanded =
        false

    // MARK: - Visual Sender Confirmation

    @State private var selectedVisualSender =
        ""

    @State private var customVisualSender =
        ""

    // MARK: - Visual Test

    @State private var visualTestExpanded =
        false

    @State private var visualTestComparisonURL:
        URL?

    @State private var isChoosingVisualTestPDF =
        false

    @State private var visualTestSimilarity:
        Double?

    @State private var isRunningVisualTest =
        false

    @State private var visualTestError:
        String?

    // MARK: - Document

    let document:
        DocumentRecord

    @Binding var filenameDraft:
        String

    let extractedText:
        String

    let textExtractionMessage:
        String?

    let analysis:
        AtlasAnalysis?

    let folderSuggestion:
        FolderSuggestion?

    let manualArchiveDestinationURL:
        URL?

    // MARK: - Visual Sender

    let visualSenderSuggestion:
        String?

    let visualSenderConfirmationCount:
        Int

    let visualSenderNeedsConfirmation:
        Bool

    let visualSenderSimilarity:
        Double?

    let availableVisualSenderCompanies:
        [String]

    let onConfirmVisualSender:
        (String) -> Void

    // MARK: - State

    let isAnalyzing:
        Bool

    let isArchiving:
        Bool

    // MARK: - Actions

    let onAnalyzeDocument:
        () -> Void

    let onRememberSuggestion:
        () -> Void

    let onHelpAtlas:
        () -> Void

    let onChangeArchiveDestination:
        () -> Void

    let onClearArchiveDestination:
        () -> Void

    let onRename:
        () -> Void

    let onArchive:
        () -> Void

    // MARK: - Body

    var body: some View {

        ScrollView {

            VStack(spacing: 12) {

                // MARK: Atlas Empfehlung

                AtlasRecommendationCard(
                    analysis:
                        analysis,
                    folderSuggestion:
                        folderSuggestion
                )

                // MARK: Absender bestätigen

                if visualSenderNeedsConfirmation {

                    visualSenderConfirmationCard
                }

                // MARK: Archivziel

                archiveDestinationCard

                // MARK: Dateiname / Archivieren

                AtlasRenameCard(
                    filenameDraft:
                        $filenameDraft,
                    isArchiving:
                        isArchiving,
                    canArchive:
                        folderSuggestion != nil ||
                        manualArchiveDestinationURL != nil,
                    onRename:
                        onRename,
                    onArchive:
                        onArchive
                )

                // MARK: Analyse

                ExpandableAtlasSection(
                    title:
                        "Analyse und Begründungen",
                    systemImage:
                        "text.viewfinder",
                    isExpanded:
                        $analysisExpanded
                ) {

                    analysisCard
                }

                // MARK: Lernen

                ExpandableAtlasSection(
                    title:
                        "Atlas lernen lassen",
                    systemImage:
                        "brain",
                    isExpanded:
                        $learningExpanded
                ) {

                    AtlasLearningCard(
                        analysis:
                            analysis,
                        folderSuggestion:
                            folderSuggestion,
                        onRemember:
                            onRememberSuggestion,
                        onHelpAtlas:
                            onHelpAtlas
                    )
                }

                // MARK: Aktuelle Datei

                ExpandableAtlasSection(
                    title:
                        "Aktuelle Datei",
                    systemImage:
                        "doc",
                    isExpanded:
                        $fileExpanded
                ) {

                    currentFileCard
                }

                // MARK: Visual Test

                ExpandableAtlasSection(
                    title:
                        "Visual Test",
                    systemImage:
                        "wrench.and.screwdriver",
                    isExpanded:
                        $visualTestExpanded
                ) {

                    visualTestCard
                }
            }
            .padding(12)
        }
        .frame(
            minWidth: 320,
            idealWidth: 370
        )
        .background(
            Color(
                nsColor:
                    .controlBackgroundColor
            )
        )

        // MARK: - Visual Test PDF Picker

        .fileImporter(
            isPresented:
                $isChoosingVisualTestPDF,
            allowedContentTypes: [
                .pdf
            ],
            allowsMultipleSelection:
                false
        ) { result in

            handleVisualTestSelection(
                result
            )
        }

        // MARK: - Document Change

        .onChange(
            of:
                document.sourceURL
        ) { _, _ in

            visualTestSimilarity =
                nil

            visualTestError =
                nil

            selectedVisualSender =
                ""

            customVisualSender =
                ""

            prepareVisualSenderSelection()
        }

        .onChange(
            of:
                visualSenderSuggestion
        ) { _, _ in

            customVisualSender =
                ""

            prepareVisualSenderSelection(
                force:
                    true
            )
        }

        .onAppear {

            prepareVisualSenderSelection()
        }
    }

    // MARK: - Visual Sender Confirmation

    private var visualSenderConfirmationCard:
        some View {

        AtlasCard {

            VStack(
                alignment: .leading,
                spacing: 14
            ) {

                HStack(spacing: 10) {

                    Image(
                        systemName:
                            "building.2"
                    )
                    .font(.title2)

                    VStack(
                        alignment: .leading,
                        spacing: 2
                    ) {

                        Text(
                            "Absender bestätigen"
                        )
                        .font(.headline)

                        Text(
                            "Atlas lernt den Dokumentkopf"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Spacer()

                    Image(
                        systemName:
                            "questionmark.circle.fill"
                    )
                    .foregroundStyle(
                        .orange
                    )
                }

                if let visualSenderSuggestion {

                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {

                        Text(
                            "Atlas vermutet"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )

                        Text(
                            visualSenderSuggestion
                        )
                        .font(
                            .title3.bold()
                        )
                    }

                } else {

                    Text(
                        "Atlas konnte den Absender noch nicht sicher erkennen."
                    )
                    .font(.callout)
                    .foregroundStyle(
                        .secondary
                    )
                }

                // MARK: Similarity

                if let visualSenderSimilarity {

                    HStack {

                        Label(
                            "Visuelle Ähnlichkeit",
                            systemImage:
                                "eye"
                        )
                        .font(.callout)

                        Spacer()

                        Text(
                            String(
                                format:
                                    "%.1f %%",
                                visualSenderSimilarity
                                    * 100
                            )
                        )
                        .font(
                            .callout.bold()
                        )
                    }
                }

                // MARK: Confirmations

                HStack {

                    Label(
                        "Bestätigungen",
                        systemImage:
                            "checkmark.circle"
                    )
                    .font(.callout)

                    Spacer()

                    Text(
                        "\(min(visualSenderConfirmationCount, 3)) / 3"
                    )
                    .font(
                        .callout.bold()
                    )
                }

                ProgressView(
                    value:
                        Double(
                            min(
                                visualSenderConfirmationCount,
                                3
                            )
                        ),
                    total:
                        3
                )

                Text(
                    confirmationExplanation
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

                Divider()

                // MARK: Known Sender

                VStack(
                    alignment: .leading,
                    spacing: 6
                ) {

                    Text(
                        "Bekannter Absender"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                    Picker(
                        "Bekannter Absender",
                        selection:
                            $selectedVisualSender
                    ) {

                        Text(
                            "Firma auswählen …"
                        )
                        .tag("")

                        ForEach(
                            availableVisualSenderCompanies,
                            id:
                                \.self
                        ) { company in

                            Text(
                                company
                            )
                            .tag(
                                company
                            )
                        }
                    }
                    .labelsHidden()
                }

                // MARK: New Sender

                VStack(
                    alignment: .leading,
                    spacing: 6
                ) {

                    Text(
                        "Oder neuen Absender eintragen"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                    TextField(
                        "Neuer Absender",
                        text:
                            $customVisualSender
                    )
                    .textFieldStyle(
                        .roundedBorder
                    )
                }

                // MARK: Sender To Learn

                if !senderToConfirm.isEmpty {

                    HStack(
                        spacing: 6
                    ) {

                        Image(
                            systemName:
                                "arrow.right.circle"
                        )

                        Text(
                            "Wird gelernt als:"
                        )

                        Text(
                            senderToConfirm
                        )
                        .fontWeight(
                            .semibold
                        )
                    }
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }

                // MARK: Confirm Button

                Button {

                    let sender =
                        senderToConfirm

                    guard
                        !sender.isEmpty
                    else {
                        return
                    }

                    onConfirmVisualSender(
                        sender
                    )

                    // Falls ein neuer Firmenname
                    // eingegeben wurde, behalten wir
                    // ihn nach dem Bestätigen sichtbar.
                    selectedVisualSender =
                        sender

                    customVisualSender =
                        ""

                } label: {

                    Label(
                        "Absender bestätigen",
                        systemImage:
                            "checkmark.circle.fill"
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .disabled(
                    senderToConfirm.isEmpty
                    ||
                    isAnalyzing
                    ||
                    isArchiving
                )
            }
        }
    }

    // MARK: - Sender To Confirm

    private var senderToConfirm:
        String {

        let custom =
            customVisualSender
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        // Freie Eingabe hat Vorrang.
        if !custom.isEmpty {

            return custom
        }

        return
            selectedVisualSender
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
    }

    // MARK: - Confirmation Explanation

    private var confirmationExplanation:
        String {

        switch visualSenderConfirmationCount {

        case 2...:

            return
                "Noch einmal bestätigen. Danach kann Atlas diesen Dokumentkopf automatisch zuordnen."

        case 1:

            return
                "Atlas hat diese Zuordnung einmal gelernt. Zwei weitere Bestätigungen machen sie automatisch."

        default:

            return
                "Bestätige den Absender. Nach drei Bestätigungen kann Atlas ähnliche Dokumentköpfe automatisch zuordnen."
        }
    }

    // MARK: - Prepare Sender Selection

    private func prepareVisualSenderSelection(
        force: Bool = false
    ) {

        if !force &&
            !selectedVisualSender.isEmpty {

            return
        }

        guard let visualSenderSuggestion
        else {

            selectedVisualSender =
                ""

            return
        }

        if availableVisualSenderCompanies
            .contains(
                visualSenderSuggestion
            ) {

            selectedVisualSender =
                visualSenderSuggestion

        } else {

            // Wichtig:
            // Auch ein bereits visuell gelernter,
            // aber noch nicht in knowledge.json
            // vorhandener Firmenname soll sichtbar
            // sein.
            customVisualSender =
                visualSenderSuggestion

            selectedVisualSender =
                ""
        }
    }

    // MARK: - Archive Destination

    private var archiveDestinationCard:
        some View {

        AtlasCard {

            VStack(
                alignment: .leading,
                spacing: 10
            ) {

                Label(
                    "Archivziel",
                    systemImage:
                        "folder.badge.arrow.forward"
                )
                .font(.headline)

                if let manualArchiveDestinationURL {

                    Text(
                        "Manuell gewählt"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                    Text(
                        manualArchiveDestinationURL
                            .lastPathComponent
                    )
                    .font(
                        .callout.bold()
                    )

                    Text(
                        manualArchiveDestinationURL
                            .path
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(2)
                    .truncationMode(
                        .middle
                    )

                } else if let folderSuggestion {

                    Text(
                        "Atlas-Vorschlag"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                    Text(
                        folderSuggestion
                            .displayPath
                    )
                    .font(
                        .callout.bold()
                    )

                } else {

                    Text(
                        "Noch kein Ziel vorhanden."
                    )
                    .font(.callout)
                    .foregroundStyle(
                        .secondary
                    )
                }

                HStack {

                    Button {

                        onChangeArchiveDestination()

                    } label: {

                        Label(
                            "Ziel ändern …",
                            systemImage:
                                "folder"
                        )
                    }
                    .buttonStyle(
                        .bordered
                    )
                    .disabled(
                        isArchiving
                    )

                    if manualArchiveDestinationURL != nil {

                        Button {

                            onClearArchiveDestination()

                        } label: {

                            Text(
                                "Atlas-Ziel verwenden"
                            )
                        }
                        .buttonStyle(
                            .borderless
                        )
                        .disabled(
                            isArchiving
                        )
                    }
                }
            }
        }
    }

    // MARK: - Analysis

    private var analysisCard:
        some View {

        AtlasCard {

            VStack(
                alignment: .leading,
                spacing: 12
            ) {

                Label(
                    "Dokumentanalyse",
                    systemImage:
                        "text.viewfinder"
                )
                .font(.headline)

                Button(
                    action:
                        onAnalyzeDocument
                ) {

                    Label(
                        isAnalyzing
                            ? "Analyse läuft …"
                            : "Dokument analysieren",
                        systemImage:
                            "text.viewfinder"
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                }
                .buttonStyle(
                    .bordered
                )
                .disabled(
                    isAnalyzing ||
                    isArchiving
                )

                if let textExtractionMessage {

                    Text(
                        textExtractionMessage
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }

                if !extractedText.isEmpty {

                    Text(
                        "Erkannter Text"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                    ScrollView {

                        Text(
                            extractedText
                        )
                        .font(.caption)
                        .textSelection(
                            .enabled
                        )
                        .frame(
                            maxWidth:
                                .infinity,
                            alignment:
                                .leading
                        )
                    }
                    .frame(
                        minHeight: 100,
                        maxHeight: 200
                    )
                }

                if let analysis,
                   !analysis.reasons.isEmpty {

                    Divider()

                    Text(
                        "Warum?"
                    )
                    .font(.headline)

                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {

                        ForEach(
                            analysis.reasons,
                            id:
                                \.self
                        ) { reason in

                            Label(
                                reason,
                                systemImage:
                                    "checkmark.circle"
                            )
                            .font(.caption)
                        }
                    }
                }

                if let folderSuggestion,
                   !folderSuggestion
                    .reasons
                    .isEmpty {

                    Divider()

                    Text(
                        "Warum dieses Archivziel?"
                    )
                    .font(.headline)

                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {

                        ForEach(
                            folderSuggestion.reasons,
                            id:
                                \.self
                        ) { reason in

                            Label(
                                reason,
                                systemImage:
                                    "folder.badge.checkmark"
                            )
                            .font(.caption)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Current File

    private var currentFileCard:
        some View {

        AtlasCard {

            VStack(
                alignment: .leading,
                spacing: 10
            ) {

                Label(
                    "Aktuelle Datei",
                    systemImage:
                        "doc"
                )
                .font(.headline)

                Text(
                    document
                        .originalFilename
                )
                .font(.callout)
                .textSelection(
                    .enabled
                )
                .lineLimit(3)

                Text(
                    document
                        .sourceURL
                        .path
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                .textSelection(
                    .enabled
                )
                .lineLimit(2)
                .truncationMode(
                    .middle
                )
            }
        }
    }

    // MARK: - Visual Test

    private var visualTestCard:
        some View {

        AtlasCard {

            VStack(
                alignment: .leading,
                spacing: 14
            ) {

                Label(
                    "Visueller Dokumentvergleich",
                    systemImage:
                        "eye"
                )
                .font(.headline)

                Text(
                    "Vergleicht den Kopfbereich der aktuellen Datei mit einem zweiten PDF."
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

                Divider()

                // MARK: Datei 1

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {

                    Text(
                        "Aktuelle Datei"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                    Text(
                        document
                            .sourceURL
                            .lastPathComponent
                    )
                    .font(
                        .callout.bold()
                    )
                    .lineLimit(2)
                    .truncationMode(
                        .middle
                    )
                }

                // MARK: Datei 2

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {

                    Text(
                        "Vergleichsdatei"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                    if let visualTestComparisonURL {

                        Text(
                            visualTestComparisonURL
                                .lastPathComponent
                        )
                        .font(
                            .callout.bold()
                        )
                        .lineLimit(2)
                        .truncationMode(
                            .middle
                        )

                    } else {

                        Text(
                            "Noch keine Datei ausgewählt"
                        )
                        .font(.callout)
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }

                Button {

                    isChoosingVisualTestPDF =
                        true

                } label: {

                    Label(
                        visualTestComparisonURL == nil
                            ? "Vergleichsdatei auswählen …"
                            : "Andere Datei auswählen …",
                        systemImage:
                            "doc.badge.plus"
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                }
                .buttonStyle(
                    .bordered
                )
                .disabled(
                    isRunningVisualTest
                )

                // MARK: Compare

                Button {

                    runVisualTest()

                } label: {

                    Label(
                        isRunningVisualTest
                            ? "Vergleich läuft …"
                            : "Dokumente vergleichen",
                        systemImage:
                            isRunningVisualTest
                            ? "hourglass"
                            : "eye"
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .disabled(
                    visualTestComparisonURL == nil ||
                    isRunningVisualTest
                )

                // MARK: Result

                if let similarity =
                    visualTestSimilarity {

                    Divider()

                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {

                        Text(
                            "Similarity"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )

                        HStack(
                            alignment:
                                .firstTextBaseline
                        ) {

                            Text(
                                similarityPercentage(
                                    similarity
                                )
                            )
                            .font(
                                .title.bold()
                            )

                            Spacer()

                            Label(
                                similarityDescription(
                                    similarity
                                ),
                                systemImage:
                                    similarityIcon(
                                        similarity
                                    )
                            )
                            .font(
                                .callout.bold()
                            )
                        }

                        ProgressView(
                            value:
                                similarity,
                            total:
                                1.0
                        )

                        Text(
                            "Rohwert: \(String(format: "%.4f", similarity))"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                        .textSelection(
                            .enabled
                        )
                    }
                }

                if let visualTestError {

                    Divider()

                    Label(
                        visualTestError,
                        systemImage:
                            "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
        }
    }

    // MARK: - Visual Test Selection

    private func handleVisualTestSelection(
        _ result:
            Result<[URL], Error>
    ) {

        switch result {

        case .success(let urls):

            guard let url =
                urls.first
            else {

                return
            }

            visualTestComparisonURL =
                url

            visualTestSimilarity =
                nil

            visualTestError =
                nil

        case .failure(let error):

            visualTestError =
                "Vergleichsdatei konnte nicht geöffnet werden: \(error.localizedDescription)"
        }
    }

    // MARK: - Run Visual Test

    private func runVisualTest() {

        guard let comparisonURL =
            visualTestComparisonURL
        else {

            return
        }

        isRunningVisualTest =
            true

        visualTestSimilarity =
            nil

        visualTestError =
            nil

        let firstURL =
            document.sourceURL

        Task {

            let knowledgeBase:
                KnowledgeBase

            do {

                knowledgeBase =
                    try KnowledgeBase.load()

            } catch {

                await MainActor.run {

                    visualTestError =
                        "KnowledgeBase konnte nicht geladen werden: \(error.localizedDescription)"

                    isRunningVisualTest =
                        false
                }

                return
            }

            let recognizer =
                SenderVisualRecognizer(
                    knowledgeBase:
                        knowledgeBase
                )

            let firstSignature =
                await recognizer.signature(
                    for:
                        firstURL
                )

            let secondSignature =
                await recognizer.signature(
                    for:
                        comparisonURL
                )

            guard
                let firstSignature,
                let secondSignature
            else {

                await MainActor.run {

                    visualTestError =
                        "Für mindestens eine Datei konnte keine visuelle Signatur erzeugt werden."

                    isRunningVisualTest =
                        false
                }

                return
            }

            guard let similarity =
                firstSignature.similarity(
                    to:
                        secondSignature
                )
            else {

                await MainActor.run {

                    visualTestError =
                        "Die visuellen Signaturen konnten nicht miteinander verglichen werden."

                    isRunningVisualTest =
                        false
                }

                return
            }

            await MainActor.run {

                visualTestSimilarity =
                    similarity

                isRunningVisualTest =
                    false
            }

            print(
                """

                🧠 Atlas Visual Test
                --------------------
                Datei 1: \(firstURL.lastPathComponent)
                Datei 2: \(comparisonURL.lastPathComponent)
                Similarity: \(String(format: "%.4f", similarity))
                Prozent: \(String(format: "%.1f", similarity * 100)) %
                --------------------

                """
            )
        }
    }

    // MARK: - Similarity Presentation

    private func similarityPercentage(
        _ similarity: Double
    ) -> String {

        String(
            format:
                "%.1f %%",
            similarity * 100
        )
    }

    private func similarityDescription(
        _ similarity: Double
    ) -> String {

        switch similarity {

        case 0.97...:

            return
                "Sehr ähnlich"

        case 0.94..<0.97:

            return
                "Ähnlich"

        case 0.85..<0.94:

            return
                "Teilweise ähnlich"

        default:

            return
                "Unterschiedlich"
        }
    }

    private func similarityIcon(
        _ similarity: Double
    ) -> String {

        switch similarity {

        case 0.97...:

            return
                "checkmark.circle.fill"

        case 0.94..<0.97:

            return
                "checkmark.circle"

        case 0.85..<0.94:

            return
                "questionmark.circle"

        default:

            return
                "xmark.circle"
        }
    }
}

// MARK: - Expandable Section

private struct ExpandableAtlasSection<
    Content: View
>: View {

    let title:
        String

    let systemImage:
        String

    @Binding var isExpanded:
        Bool

    @ViewBuilder
    let content:
        () -> Content

    var body: some View {

        VStack(spacing: 0) {

            Button {

                withAnimation(
                    .easeInOut(
                        duration:
                            0.2
                    )
                ) {

                    isExpanded.toggle()
                }

            } label: {

                HStack(spacing: 10) {

                    Image(
                        systemName:
                            isExpanded
                            ? "chevron.down"
                            : "chevron.right"
                    )
                    .font(.caption)
                    .frame(
                        width:
                            12
                    )

                    Label(
                        title,
                        systemImage:
                            systemImage
                    )
                    .font(.headline)

                    Spacer()
                }
                .contentShape(
                    Rectangle()
                )
                .padding(
                    .vertical,
                    10
                )
                .padding(
                    .horizontal,
                    12
                )
            }
            .buttonStyle(
                .plain
            )

            if isExpanded {

                content()
                    .padding(
                        .top,
                        8
                    )
                    .transition(
                        .opacity
                            .combined(
                                with:
                                    .move(
                                        edge:
                                            .top
                                    )
                            )
                    )
            }
        }
        .frame(
            maxWidth:
                .infinity,
            alignment:
                .leading
        )
    }
}

// MARK: - Preview

#Preview {

    @Previewable @State
    var filename =
        "2026-08-06 Rechnung RAISA"

    let previewAnalysis =
        AtlasAnalysis(
            documentType:
                .invoice,
            detectedDate:
                Date(),
            sender:
                "RAISA",
            recipientArea:
                .business,
            keywords: [
                "Rechnung",
                "Futtermittel",
                "VzF"
            ],
            confidence:
                0.95,
            reasons: [
                "Dokumentart Rechnung erkannt",
                "Absender RAISA erkannt",
                "Empfänger Betrieb erkannt",
                "Datum erkannt",
                "3 relevante Schlüsselwörter gefunden"
            ]
        )

    let previewFolderSuggestion =
        FolderSuggestion(
            ruleName:
                "Betrieb Belege",
            area:
                .business,
            folder:
                "Belege",
            confidence:
                0.95,
            reasons: [
                "Empfänger Betrieb passt zum Archivbereich",
                "Atlas hat ähnliche Dokumente gefunden",
                "Dieses Ziel wurde bereits 4× bestätigt",
                "Gelernte Zuordnung bestätigt den Regelvorschlag"
            ]
        )

    AtlasPanelView(
        document:
            DocumentRecord(
                sourceURL:
                    URL(
                        fileURLWithPath:
                            "/tmp/scan001.pdf"
                    )
            ),
        filenameDraft:
            $filename,
        extractedText:
            "Beispieltext aus dem PDF",
        textExtractionMessage:
            "28 Zeichen aus dem PDF gelesen.",
        analysis:
            previewAnalysis,
        folderSuggestion:
            previewFolderSuggestion,
        manualArchiveDestinationURL:
            nil,

        visualSenderSuggestion:
            "RAISA",
        visualSenderConfirmationCount:
            1,
        visualSenderNeedsConfirmation:
            true,
        visualSenderSimilarity:
            0.941,
        availableVisualSenderCompanies: [
            "RAISA",
            "RWG",
            "Team Agrar",
            "Trede & von Pein"
        ],
        onConfirmVisualSender: {
            _ in
        },

        isAnalyzing:
            false,
        isArchiving:
            false,
        onAnalyzeDocument: {},
        onRememberSuggestion: {},
        onHelpAtlas: {},
        onChangeArchiveDestination: {},
        onClearArchiveDestination: {},
        onRename: {},
        onArchive: {}
    )
    .frame(
        width:
            420,
        height:
            1100
    )
}
