import SwiftUI

struct AtlasLearningSheet: View {

    let currentAnalysis: AtlasAnalysis?
    let currentFolderSuggestion: FolderSuggestion?

    let onCancel: () -> Void

    let onSave: (
        String?,
        DocumentType,
        Date?,
        [String],
        ArchiveArea,
        String
    ) -> Void

    // MARK: - Company

    @State private var selectedCompany =
        ""

    @State private var customCompany =
        ""

    // MARK: - Document Analysis

    @State private var documentType:
        DocumentType = .unknown

    @State private var detectedDate =
        Date()

    @State private var hasDate =
        false

    @State private var keywordsText =
        ""

    // MARK: - Archive

    @State private var archiveArea:
        ArchiveArea = .business

    @State private var selectedFolderName =
        ""

    // MARK: - Knowledge

    private let archiveFolders:
        [ArchiveFolder]

    private let knownCompanies:
        [String]

    // MARK: - Init

    init(
        currentAnalysis: AtlasAnalysis?,
        currentFolderSuggestion: FolderSuggestion?,
        onCancel: @escaping () -> Void,
        onSave: @escaping (
            String?,
            DocumentType,
            Date?,
            [String],
            ArchiveArea,
            String
        ) -> Void
    ) {

        self.currentAnalysis =
            currentAnalysis

        self.currentFolderSuggestion =
            currentFolderSuggestion

        self.onCancel =
            onCancel

        self.onSave =
            onSave

        // MARK: Knowledge Base

        let knowledgeBase:
            KnowledgeBase?

        do {

            knowledgeBase =
                try KnowledgeBase.load()

        } catch {

            print(
                "KnowledgeBase konnte in AtlasLearningSheet nicht geladen werden: \(error.localizedDescription)"
            )

            knowledgeBase =
                nil
        }

        archiveFolders =
            knowledgeBase?
                .archiveFolders
            ?? []

        // MARK: Built-in Companies

        let builtInCompanies =
            knowledgeBase?
                .companies
                .map(
                    \.name
                )
            ?? []

        // MARK: Learned Companies

        let learnedCompanies =
            LearnedCompanyStore()
                .load()

        // Beide Quellen zusammenführen.

        knownCompanies =
            Self.mergeCompanies(
                builtInCompanies
                +
                learnedCompanies
            )
    }

    // MARK: - Body

    var body: some View {

        VStack(spacing: 0) {

            header

            Divider()

            Form {

                // MARK: Recognized Information

                Section(
                    "Erkannte Informationen ergänzen"
                ) {

                    companySection

                    Picker(
                        "Dokumentart",
                        selection:
                            $documentType
                    ) {

                        ForEach(
                            DocumentType.allCases,
                            id:
                                \.self
                        ) { type in

                            Text(
                                type.rawValue
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

                    TextField(
                        "Schlüsselwörter, durch Komma getrennt",
                        text:
                            $keywordsText
                    )
                }

                // MARK: Destination

                Section(
                    "Zielordner"
                ) {

                    Picker(
                        "Bereich",
                        selection:
                            $archiveArea
                    ) {

                        ForEach(
                            availableAreas,
                            id:
                                \.self
                        ) { area in

                            Text(
                                area.rawValue
                            )
                            .tag(
                                area
                            )
                        }
                    }
                    .onChange(
                        of:
                            archiveArea
                    ) { _, _ in

                        ensureValidFolderSelection()
                    }

                    Picker(
                        "Ordner",
                        selection:
                            $selectedFolderName
                    ) {

                        if filteredFolders.isEmpty {

                            Text(
                                "Keine Ordner vorhanden"
                            )
                            .tag("")

                        } else {

                            ForEach(
                                filteredFolders
                            ) { folder in

                                Text(
                                    folder.name
                                )
                                .tag(
                                    folder.name
                                )
                            }
                        }
                    }
                    .disabled(
                        filteredFolders.isEmpty
                    )

                    if let selectedFolder {

                        Label(
                            selectedFolder
                                .displayPath,
                            systemImage:
                                "folder.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }
            }
            .formStyle(
                .grouped
            )

            Divider()

            footer
        }
        .frame(
            minWidth:
                520,
            minHeight:
                620
        )
        .onAppear {

            populateInitialValues()

            ensureValidFolderSelection()
        }
    }

    // MARK: - Company Section

    private var companySection:
        some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            Text(
                "Firma"
            )
            .font(.headline)

            Picker(
                "Bekannte Firma",
                selection:
                    $selectedCompany
            ) {

                Text(
                    "Firma auswählen …"
                )
                .tag("")

                ForEach(
                    knownCompanies,
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

            // Wenn der Benutzer eine bekannte
            // Firma auswählt, löschen wir eine
            // eventuell vorhandene freie Eingabe.
            .onChange(
                of:
                    selectedCompany
            ) { _, newValue in

                guard
                    !newValue.isEmpty
                else {
                    return
                }

                customCompany =
                    ""
            }

            Text(
                "Oder neue Firma eintragen"
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )

            TextField(
                "Neue Firma",
                text:
                    $customCompany
            )
            .textFieldStyle(
                .roundedBorder
            )

            // Sobald der Benutzer frei tippt,
            // soll eindeutig diese Eingabe gelten.
            .onChange(
                of:
                    customCompany
            ) { _, newValue in

                let cleaned =
                    newValue
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )

                if !cleaned.isEmpty {

                    selectedCompany =
                        ""
                }
            }

            if let company =
                cleanedCompany {

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
                        company
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
        }
        .padding(
            .vertical,
            4
        )
    }

    // MARK: - Header

    private var header:
        some View {

        HStack(spacing: 12) {

            Image(
                systemName:
                    "brain.head.profile"
            )
            .font(.title)

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text(
                    "Atlas helfen"
                )
                .font(
                    .title2.bold()
                )

                Text(
                    "Ergänze fehlende Informationen und wähle den passenden Zielordner."
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Footer

    private var footer:
        some View {

        HStack {

            Button(
                "Abbrechen",
                action:
                    onCancel
            )

            Spacer()

            Button(
                "Lernen"
            ) {

                // Eine neu eingegebene Firma
                // zusätzlich dauerhaft in unserer
                // Firmenliste speichern.
                if let company =
                    cleanedCompany {

                    LearnedCompanyStore()
                        .add(
                            company
                        )
                }

                onSave(
                    cleanedCompany,
                    documentType,
                    hasDate
                        ? detectedDate
                        : nil,
                    cleanedKeywords,
                    archiveArea,
                    selectedFolderName
                )
            }
            .buttonStyle(
                .borderedProminent
            )
            .disabled(
                !canSave
            )
        }
        .padding()
    }

    // MARK: - Areas

    private var availableAreas:
        [ArchiveArea] {

        let areas =
            Set(
                archiveFolders.map(
                    \.area
                )
            )

        return areas.sorted {

            $0.rawValue
                .localizedStandardCompare(
                    $1.rawValue
                ) == .orderedAscending
        }
    }

    // MARK: - Folders

    private var filteredFolders:
        [ArchiveFolder] {

        archiveFolders.filter {

            $0.area ==
                archiveArea
        }
    }

    private var selectedFolder:
        ArchiveFolder? {

        filteredFolders.first {

            $0.name ==
                selectedFolderName
        }
    }

    // MARK: - Company

    private var cleanedCompany:
        String? {

        let custom =
            customCompany
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if !custom.isEmpty {

            return custom
        }

        let selected =
            selectedCompany
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return selected.isEmpty
            ? nil
            : selected
    }

    // MARK: - Keywords

    private var cleanedKeywords:
        [String] {

        keywordsText
            .split(
                separator:
                    ","
            )
            .map {

                $0.trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            }
            .filter {

                !$0.isEmpty
            }
    }

    // MARK: - Validation

    private var canSave:
        Bool {

        documentType !=
            .unknown
        &&
        !selectedFolderName.isEmpty
    }

    // MARK: - Initial Values

    private func populateInitialValues() {

        if let currentAnalysis {

            let currentCompany =
                currentAnalysis.sender?
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                ?? ""

            if let knownCompany =
                matchingKnownCompany(
                    for:
                        currentCompany
                ) {

                selectedCompany =
                    knownCompany

                customCompany =
                    ""

            } else {

                selectedCompany =
                    ""

                customCompany =
                    currentCompany
            }

            documentType =
                currentAnalysis
                    .documentType

            if let date =
                currentAnalysis
                    .detectedDate {

                detectedDate =
                    date

                hasDate =
                    true

            } else {

                hasDate =
                    false
            }

            keywordsText =
                currentAnalysis
                    .keywords
                    .joined(
                        separator:
                            ", "
                    )
        }

        if let currentFolderSuggestion {

            archiveArea =
                currentFolderSuggestion
                    .area

            selectedFolderName =
                currentFolderSuggestion
                    .folder
        }
    }

    // MARK: - Known Company Match

    private func matchingKnownCompany(
        for value: String
    ) -> String? {

        let normalizedValue =
            Self.normalizeCompany(
                value
            )

        guard
            !normalizedValue.isEmpty
        else {

            return nil
        }

        return knownCompanies.first {

            Self.normalizeCompany(
                $0
            ) == normalizedValue
        }
    }

    // MARK: - Folder Validation

    private func ensureValidFolderSelection() {

        guard
            !filteredFolders.isEmpty
        else {

            selectedFolderName =
                ""

            return
        }

        let stillValid =
            filteredFolders.contains {

                $0.name ==
                    selectedFolderName
            }

        if !stillValid {

            selectedFolderName =
                filteredFolders[0]
                    .name
        }
    }

    // MARK: - Merge Companies

    private static func mergeCompanies(
        _ companies: [String]
    ) -> [String] {

        var result:
            [String] = []

        var knownKeys:
            Set<String> = []

        for company in companies {

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
                !knownKeys.contains(
                    key
                )
            else {

                continue
            }

            knownKeys.insert(
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

    // MARK: - Normalize Company

    private static func normalizeCompany(
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
}

// MARK: - Preview

#Preview {

    AtlasLearningSheet(
        currentAnalysis:
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
                    "Futtermittel"
                ],
                confidence:
                    0.75,
                reasons: []
            ),
        currentFolderSuggestion:
            FolderSuggestion(
                ruleName:
                    "Betrieb Belege",
                area:
                    .business,
                folder:
                    "Belege",
                confidence:
                    0.55,
                reasons: []
            ),
        onCancel: {},
        onSave: {
            _,
            _,
            _,
            _,
            _,
            _ in
        }
    )
}
