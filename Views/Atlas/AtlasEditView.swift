import SwiftUI

struct AtlasEditValues {

    var recipientArea:
        ArchiveArea

    var sender:
        String

    var documentType:
        DocumentType

    var detectedDate:
        Date?

    var destinationURL:
        URL?

    var filename:
        String

    /// Wenn true, bestätigt der Benutzer ausdrücklich,
    /// dass die visuelle Signatur / Grafik dieses
    /// Dokuments zu diesem Absender gehört.
    var confirmVisualSender:
        Bool
}

// MARK: - Atlas Edit View

struct AtlasEditView:
    View {

    let document:
        DocumentRecord

    let availableCompanies:
        [String]

    let initialRecipientArea:
        ArchiveArea

    let initialSender:
        String

    let initialDocumentType:
        DocumentType

    let initialDate:
        Date?

    let initialFilename:
        String

    @Binding
    var destinationURL:
        URL?

    let archiveViewModel:
        ArchiveViewModel

    /// Zentraler Atlas-Vorschlag für den Speicherort.
    ///
    /// Dadurch verwendet auch das Korrekturfenster
    /// dieselbe Logik wie der normale Atlas-Workflow.
    let suggestArchiveDestination:
        (
            ArchiveArea,
            String,
            DocumentType,
            DocumentRecord
        ) -> URL?

    let visualSimilarity:
        (
            String,
            DocumentRecord
        ) -> Double?

    let visualConfirmationCount:
        (
            String
        ) -> Int

    let isWorking:
        Bool

    let onCancel:
        () -> Void

    let onSaveAndArchive:
        (AtlasEditValues) -> Void

    // MARK: - Recipient

    @State
    private var recipientArea:
        ArchiveArea

    // MARK: - Sender

    @State
    private var selectedSender =
        ""

    @State
    private var customSender =
        ""

    @State
    private var confirmVisualSender =
        false

    // Die visuelle Ähnlichkeit wird bewusst gecacht.
    // Sie darf NICHT bei jedem SwiftUI-Neuzeichnen
    // erneut berechnet werden, weil der Vergleich der
    // Vision-Feature-Vektoren relativ aufwendig ist.
    @State
    private var visualSimilarityValue:
        Double?

    @State
    private var visualConfirmationCountValue =
        0

    // MARK: - Document

    @State
    private var documentType:
        DocumentType

    @State
    private var detectedDate =
        Date()

    @State
    private var hasDate =
        false

    // MARK: - Filename

    @State
    private var filename =
        ""

    /// Sobald der Benutzer den Dateinamen
    /// selbst verändert, greift Atlas nicht
    /// mehr automatisch ein.
    @State
    private var filenameWasEditedManually =
        false

    // MARK: - Destination

    @State
    private var isShowingDestinationPicker =
        false

    /// Sobald der Benutzer einen Speicherort
    /// selbst auswählt, überschreibt Atlas ihn
    /// nicht mehr automatisch.
    @State
    private var destinationWasChosenManually =
        false

    // MARK: - Init

    init(
        document:
            DocumentRecord,
        availableCompanies:
            [String],
        initialRecipientArea:
            ArchiveArea,
        initialSender:
            String,
        initialDocumentType:
            DocumentType,
        initialDate:
            Date?,
        destinationURL:
            Binding<URL?>,
        initialFilename:
            String,
        archiveViewModel:
            ArchiveViewModel,
        suggestArchiveDestination:
            @escaping (
                ArchiveArea,
                String,
                DocumentType,
                DocumentRecord
            ) -> URL?,
        visualSimilarity:
            @escaping (
                String,
                DocumentRecord
            ) -> Double?,
        visualConfirmationCount:
            @escaping (
                String
            ) -> Int,
        isWorking:
            Bool,
        onCancel:
            @escaping () -> Void,
        onSaveAndArchive:
            @escaping (AtlasEditValues) -> Void
    ) {

        self.document =
            document

        self.availableCompanies =
            availableCompanies

        self.initialRecipientArea =
            initialRecipientArea

        self.initialSender =
            initialSender

        self.initialDocumentType =
            initialDocumentType

        self.initialDate =
            initialDate

        self._destinationURL =
            destinationURL

        self.initialFilename =
            initialFilename

        self.archiveViewModel =
            archiveViewModel

        self.suggestArchiveDestination =
            suggestArchiveDestination

        self.visualSimilarity =
            visualSimilarity

        self.visualConfirmationCount =
            visualConfirmationCount

        self.isWorking =
            isWorking

        self.onCancel =
            onCancel

        self.onSaveAndArchive =
            onSaveAndArchive

        _recipientArea =
            State(
                initialValue:
                    initialRecipientArea
            )

        _documentType =
            State(
                initialValue:
                    initialDocumentType
            )

        _detectedDate =
            State(
                initialValue:
                    initialDate
                    ?? Date()
            )

        _hasDate =
            State(
                initialValue:
                    initialDate != nil
            )

        _filename =
            State(
                initialValue:
                    initialFilename
            )
    }

    // MARK: - Body

    var body:
        some View {

        VStack(
            spacing:
                0
        ) {

            header

            Divider()

            ScrollView {

                VStack(
                    spacing:
                        14
                ) {

                    recipientCard

                    senderCard

                    documentCard

                    destinationCard

                    filenameCard
                }
                .padding(
                    16
                )
            }

            Divider()

            footer
        }
        .frame(
            minWidth:
                520,
            minHeight:
                650
        )

        // MARK: Initial Setup

        .onAppear {

            prepareSender()

            refreshVisualSenderInfo()

            if archiveViewModel
                .rootNodesByWorkspace
                .isEmpty {

                archiveViewModel.reload()

            } else {

                updateAutomaticDestination()
            }
        }

        // MARK: Archive Loaded

        .onChange(
            of:
                archiveViewModel
                    .rootNodesByWorkspace
                    .count
        ) {
            _,
            _ in

            updateAutomaticDestination()
        }

        // MARK: Recipient Changed

        .onChange(
            of:
                recipientArea
        ) {
            _,
            _ in

            updateAutomaticDestination()
        }

        // MARK: Document Type Changed

        .onChange(
            of:
                documentType
        ) {
            _,
            _ in

            updateAutomaticFilename()

            updateAutomaticDestination()
        }

        // MARK: Date Enabled / Disabled

        .onChange(
            of:
                hasDate
        ) {
            _,
            _ in

            updateAutomaticFilename()
        }

        // MARK: Date Changed

        .onChange(
            of:
                detectedDate
        ) {
            _,
            _ in

            guard
                hasDate
            else {

                return
            }

            updateAutomaticFilename()
        }

        // MARK: Sender Picker Changed

        .onChange(
            of:
                selectedSender
        ) {
            _,
            newValue in

            if !newValue.isEmpty {

                customSender =
                    ""
            }

            confirmVisualSender =
                false

            updateAutomaticFilename()

            updateAutomaticDestination()

            refreshVisualSenderInfo()
        }

        // MARK: Custom Sender Changed

        .onChange(
            of:
                customSender
        ) {
            _,
            newValue in

            let cleaned =
                newValue
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            if !cleaned.isEmpty {

                selectedSender =
                    ""
            }

            confirmVisualSender =
                false

            updateAutomaticFilename()

            updateAutomaticDestination()

            refreshVisualSenderInfo()
        }

        // MARK: Destination Picker

        .sheet(
            isPresented:
                $isShowingDestinationPicker
        ) {

            ArchiveFolderPickerSheet(
                title:
                    "Speicherort auswählen",
                subtitle:
                    document.originalFilename,
                actionTitle:
                    "Übernehmen",
                viewModel:
                    archiveViewModel,
                isWorking:
                    false,
                errorMessage:
                    archiveViewModel
                        .errorMessage,
                onCancel: {

                    isShowingDestinationPicker =
                        false
                },
                onSelect: {
                    selectedURL in

                    destinationURL =
                        selectedURL

                    destinationWasChosenManually =
                        true

                    isShowingDestinationPicker =
                        false
                }
            )
        }
    }

    // MARK: - Header

    private var header:
        some View {

        HStack(
            spacing:
                12
        ) {

            Image(
                systemName:
                    "pencil.and.list.clipboard"
            )
            .font(
                .title2
            )

            VStack(
                alignment:
                    .leading,
                spacing:
                    3
            ) {

                Text(
                    "Angaben korrigieren"
                )
                .font(
                    .title2
                        .bold()
                )

                Text(
                    document
                        .originalFilename
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
                .lineLimit(
                    1
                )
                .truncationMode(
                    .middle
                )
            }

            Spacer()
        }
        .padding(
            18
        )
    }

    // MARK: - Recipient

    private var recipientCard:
        some View {

        AtlasCard {

            VStack(
                alignment:
                    .leading,
                spacing:
                    10
            ) {

                Label(
                    "Firma / Empfänger",
                    systemImage:
                        "building.2"
                )
                .font(
                    .headline
                )

                Picker(
                    "Firma / Empfänger",
                    selection:
                        $recipientArea
                ) {

                    ForEach(
                        ArchiveArea
                            .allCases,
                        id:
                            \.self
                    ) {
                        area in

                        Text(
                            area
                                .rawValue
                        )
                        .tag(
                            area
                        )
                    }
                }
            }
        }
    }

    // MARK: - Sender

    private var senderCard:
        some View {

        AtlasCard {

            VStack(
                alignment:
                    .leading,
                spacing:
                    10
            ) {

                Label(
                    "Absender",
                    systemImage:
                        "person.text.rectangle"
                )
                .font(
                    .headline
                )

                Picker(
                    "Bekannter Absender",
                    selection:
                        $selectedSender
                ) {

                    Text(
                        "Absender auswählen …"
                    )
                    .tag(
                        ""
                    )

                    ForEach(
                        availableCompanies,
                        id:
                            \.self
                    ) {
                        company in

                        Text(
                            company
                        )
                        .tag(
                            company
                        )
                    }
                }

                Text(
                    "Oder neuen Absender eintragen"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )

                TextField(
                    "Neuer Absender",
                    text:
                        $customSender
                )
                .textFieldStyle(
                    .roundedBorder
                )

                if !cleanedSender
                    .isEmpty {

                    HStack(
                        spacing:
                            6
                    ) {

                        Image(
                            systemName:
                                "arrow.right.circle"
                        )

                        Text(
                            "Wird verwendet als:"
                        )

                        Text(
                            cleanedSender
                        )
                        .fontWeight(
                            .semibold
                        )
                    }
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    Divider()
                        .padding(
                            .vertical,
                            2
                        )

                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            8
                    ) {

                        HStack(
                            spacing:
                                6
                        ) {

                            Image(
                                systemName:
                                    "viewfinder"
                            )

                            Text(
                                "Grafische Erkennung"
                            )
                            .fontWeight(
                                .semibold
                            )

                            Spacer()
                        }
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )

                        if let similarity =
                            visualSimilarityValue {

                            HStack {

                                Text(
                                    "Ähnlichkeit mit \(cleanedSender)"
                                )

                                Spacer()

                                Text(
                                    similarity,
                                    format:
                                        .percent
                                            .precision(
                                                .fractionLength(
                                                    1
                                                )
                                            )
                                )
                                .fontWeight(
                                    .semibold
                                )
                            }
                            .font(
                                .callout
                            )

                            let count =
                                visualConfirmationCountValue

                            if count > 0 {

                                Text(
                                    count == 1
                                    ? "Bisher 1× als \(cleanedSender) bestätigt"
                                    : "Bisher \(count)× als \(cleanedSender) bestätigt"
                                )
                                .font(
                                    .caption
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                            }

                        } else {

                            Text(
                                "Für \(cleanedSender) ist noch keine vergleichbare gelernte Grafik vorhanden."
                            )
                            .font(
                                .caption
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }

                        Toggle(
                            "Grafik gehört definitiv zu \(cleanedSender)",
                            isOn:
                                $confirmVisualSender
                        )
                        .toggleStyle(
                            .checkbox
                        )

                        Text(
                            "Nur aktivieren, wenn Logo, Briefkopf bzw. das grafische Erscheinungsbild sicher zu diesem Absender gehört."
                        )
                        .font(
                            .caption2
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }
            }
        }
    }

    // MARK: - Document

    private var documentCard:
        some View {

        AtlasCard {

            VStack(
                alignment:
                    .leading,
                spacing:
                    12
            ) {

                Label(
                    "Dokument",
                    systemImage:
                        "doc.text"
                )
                .font(
                    .headline
                )

                Picker(
                    "Dokumentenart",
                    selection:
                        $documentType
                ) {

                    ForEach(
                        DocumentType
                            .allCases,
                        id:
                            \.self
                    ) {
                        type in

                        Text(
                            type
                                .rawValue
                        )
                        .tag(
                            type
                        )
                    }
                }

                Toggle(
                    "Datum verwenden",
                    isOn:
                        $hasDate
                )

                if hasDate {

                    DatePicker(
                        "Datum",
                        selection:
                            $detectedDate,
                        displayedComponents:
                            .date
                    )
                }
            }
        }
    }

    // MARK: - Destination

    private var destinationCard:
        some View {

        AtlasCard {

            VStack(
                alignment:
                    .leading,
                spacing:
                    10
            ) {

                HStack {

                    Label(
                        "Speicherort",
                        systemImage:
                            "folder"
                    )
                    .font(
                        .headline
                    )

                    Spacer()

                    if destinationURL != nil &&
                        !destinationWasChosenManually {

                        Label(
                            "Automatisch",
                            systemImage:
                                "wand.and.stars"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }

                if let destinationURL {

                    Text(
                        destinationURL
                            .path
                    )
                    .font(
                        .callout
                            .weight(
                                .semibold
                            )
                    )
                    .lineLimit(
                        3
                    )
                    .truncationMode(
                        .middle
                    )
                    .textSelection(
                        .enabled
                    )

                } else {

                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            4
                    ) {

                        Text(
                            "Noch kein passender Speicherort gefunden"
                        )
                        .font(
                            .callout
                        )
                        .foregroundStyle(
                            .secondary
                        )

                        if archiveViewModel
                            .isLoading {

                            HStack(
                                spacing:
                                    6
                            ) {

                                ProgressView()
                                    .controlSize(
                                        .small
                                    )

                                Text(
                                    "Archiv wird geprüft …"
                                )
                                .font(
                                    .caption
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                            }
                        }
                    }
                }

                Button {

                    isShowingDestinationPicker =
                        true

                } label: {

                    Label(
                        destinationURL == nil
                            ? "Speicherort auswählen …"
                            : "Speicherort ändern …",
                        systemImage:
                            "folder.badge.gearshape"
                    )
                }
                .buttonStyle(
                    .bordered
                )
                .disabled(
                    isWorking
                )
            }
        }
    }

    // MARK: - Filename

    private var filenameCard:
        some View {

        AtlasCard {

            VStack(
                alignment:
                    .leading,
                spacing:
                    10
            ) {

                HStack {

                    Label(
                        "Dateiname",
                        systemImage:
                            "pencil"
                    )
                    .font(
                        .headline
                    )

                    Spacer()

                    if !filenameWasEditedManually {

                        Label(
                            "Automatisch",
                            systemImage:
                                "wand.and.stars"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }

                TextField(
                    "Dateiname",
                    text:
                        filenameBinding
                )
                .textFieldStyle(
                    .roundedBorder
                )

                HStack {

                    Text(
                        filenameWasEditedManually
                            ? "Manuell angepasst"
                            : "Wird bei Änderungen automatisch aktualisiert"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )

                    Spacer()

                    if filenameWasEditedManually {

                        Button(
                            "Automatik"
                        ) {

                            filenameWasEditedManually =
                                false

                            updateAutomaticFilename()
                        }
                        .buttonStyle(
                            .link
                        )
                        .font(
                            .caption
                        )
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer:
        some View {

        HStack(
            spacing:
                12
        ) {

            Button(
                "Abbrechen"
            ) {

                onCancel()
            }
            .keyboardShortcut(
                .cancelAction
            )
            .disabled(
                isWorking
            )

            Spacer()

            Button {

                let values =
                    AtlasEditValues(
                        recipientArea:
                            recipientArea,
                        sender:
                            cleanedSender,
                        documentType:
                            documentType,
                        detectedDate:
                            hasDate
                            ? detectedDate
                            : nil,
                        destinationURL:
                            destinationURL,
                        filename:
                            cleanedFilename,

                        confirmVisualSender:
                            confirmVisualSender
                    )

                onSaveAndArchive(
                    values
                )

            } label: {

                if isWorking {

                    HStack(
                        spacing:
                            6
                    ) {

                        ProgressView()
                            .controlSize(
                                .small
                            )

                        Text(
                            "Speichern …"
                        )
                    }

                } else {

                    Label(
                        "Korrigieren, lernen & archivieren",
                        systemImage:
                            "checkmark.circle.fill"
                    )
                }
            }
            .buttonStyle(
                .borderedProminent
            )
            .keyboardShortcut(
                .defaultAction
            )
            .disabled(
                !canSave
                ||
                isWorking
            )
        }
        .padding(
            16
        )
    }

    // MARK: - Filename Binding

    private var filenameBinding:
        Binding<String> {

        Binding(
            get: {

                filename
            },
            set: {
                newValue in

                filename =
                    newValue

                filenameWasEditedManually =
                    true
            }
        )
    }

    // MARK: - Automatic Filename

    private func updateAutomaticFilename() {

        guard
            !filenameWasEditedManually
        else {

            return
        }

        var parts:
            [String] = []

        // Datum

        if hasDate {

            let formatter =
                DateFormatter()

            formatter.dateFormat =
                "yyyy-MM-dd"

            parts.append(
                formatter.string(
                    from:
                        detectedDate
                )
            )
        }

        // Dokumentart

        if documentType !=
            .unknown {

            let type =
                documentType
                    .rawValue
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            if !type.isEmpty {

                parts.append(
                    type
                )
            }
        }

        // Absender

        if !cleanedSender.isEmpty {

            parts.append(
                cleanedSender
            )
        }

        guard
            !parts.isEmpty
        else {

            return
        }

        filename =
            parts.joined(
                separator:
                    " "
            )
    }

    // MARK: - Automatic Destination

    private func updateAutomaticDestination() {

        guard
            !destinationWasChosenManually
        else {

            return
        }

        guard
            documentType !=
                .unknown
        else {

            destinationURL =
                nil

            return
        }

        destinationURL =
            suggestArchiveDestination(
                recipientArea,
                cleanedSender,
                documentType,
                document
            )
    }

    // MARK: - Sender Preparation

    private func prepareSender() {

        let cleanedInitial =
            initialSender
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            !cleanedInitial.isEmpty
        else {

            selectedSender =
                ""

            customSender =
                ""

            return
        }

        if let matching =
            availableCompanies
                .first(
                    where: {

                        normalize(
                            $0
                        )
                        ==
                        normalize(
                            cleanedInitial
                        )
                    }
                ) {

            selectedSender =
                matching

            customSender =
                ""

        } else {

            selectedSender =
                ""

            customSender =
                cleanedInitial
        }
    }

    // MARK: - Cleaned Sender

    private var cleanedSender:
        String {

        let custom =
            customSender
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if !custom.isEmpty {

            return custom
        }

        return selectedSender
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
    }

    // MARK: - Visual Sender Comparison

    /// Berechnet die visuelle Information nur dann neu,
    /// wenn der Absender tatsächlich geändert wurde
    /// bzw. die Ansicht geöffnet wird.
    ///
    /// Wichtig:
    /// SwiftUI wertet den Body bei jedem Toggle-Klick
    /// erneut aus. Würden wir similarity(to:) dort über
    /// eine computed property aufrufen, würde der komplette
    /// Feature-Vektor-Vergleich bei jedem Neuzeichnen erneut
    /// stattfinden und könnte die Hauptoberfläche blockieren.
    private func refreshVisualSenderInfo() {

        let sender =
            cleanedSender

        guard
            !sender.isEmpty
        else {

            visualSimilarityValue =
                nil

            visualConfirmationCountValue =
                0

            return
        }

        visualSimilarityValue =
            visualSimilarity(
                sender,
                document
            )

        visualConfirmationCountValue =
            visualConfirmationCount(
                sender
            )
    }

    // MARK: - Cleaned Filename

    private var cleanedFilename:
        String {

        var value =
            filename
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if value
            .lowercased()
            .hasSuffix(
                ".pdf"
            ) {

            value =
                String(
                    value.dropLast(
                        4
                    )
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
        }

        return value
    }

    // MARK: - Validation

    private var canSave:
        Bool {

        !cleanedSender.isEmpty
        &&
        documentType !=
            .unknown
        &&
        !cleanedFilename.isEmpty
        &&
        destinationURL != nil
    }

    // MARK: - Normalize

    private func normalize(
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

    @Previewable
    @State
    var destinationURL:
        URL?

    AtlasEditView(
        document:
            DocumentRecord(
                sourceURL:
                    URL(
                        fileURLWithPath:
                            "/tmp/Scan_4711.pdf"
                    )
            ),
        availableCompanies: [
            "MeyVa",
            "RAISA",
            "RWG",
            "Team Agrar"
        ],
        initialRecipientArea:
            .business,
        initialSender:
            "MeyVa",
        initialDocumentType:
            .deliveryNote,
        initialDate:
            Date(),
        destinationURL:
            $destinationURL,
        initialFilename:
            "2026-08-11 Lieferschein MeyVa",
        archiveViewModel:
            ArchiveViewModel(),
        suggestArchiveDestination: {
            _,
            _,
            _,
            _ in

            nil
        },
        visualSimilarity: {
            _,
            _ in

            0.972
        },
        visualConfirmationCount: {
            _ in

            2
        },
        isWorking:
            false,
        onCancel:
            {},
        onSaveAndArchive: {
            _ in
        }
    )
    .frame(
        width:
            600,
        height:
            760
    )
}
