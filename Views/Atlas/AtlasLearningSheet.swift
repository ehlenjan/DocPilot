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

    @State private var company = ""
    @State private var documentType: DocumentType = .unknown
    @State private var detectedDate = Date()
    @State private var hasDate = false
    @State private var keywordsText = ""

    @State private var archiveArea: ArchiveArea = .business
    @State private var selectedFolderName = ""

    private let archiveFolders: [ArchiveFolder]

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
        self.currentAnalysis = currentAnalysis
        self.currentFolderSuggestion = currentFolderSuggestion
        self.onCancel = onCancel
        self.onSave = onSave

        do {
            archiveFolders = try KnowledgeBase.load()
                .archiveFolders
        } catch {
            archiveFolders = []
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            Form {
                Section("Erkannte Informationen ergänzen") {
                    TextField(
                        "Firma",
                        text: $company
                    )

                    Picker(
                        "Dokumentart",
                        selection: $documentType
                    ) {
                        ForEach(
                            DocumentType.allCases,
                            id: \.self
                        ) { type in
                            Text(type.rawValue)
                                .tag(type)
                        }
                    }

                    Toggle(
                        "Datum verwenden",
                        isOn: $hasDate
                    )

                    if hasDate {
                        DatePicker(
                            "Datum",
                            selection: $detectedDate,
                            displayedComponents: .date
                        )
                    }

                    TextField(
                        "Schlüsselwörter, durch Komma getrennt",
                        text: $keywordsText
                    )
                }

                Section("Zielordner") {
                    Picker(
                        "Bereich",
                        selection: $archiveArea
                    ) {
                        ForEach(
                            availableAreas,
                            id: \.self
                        ) { area in
                            Text(area.rawValue)
                                .tag(area)
                        }
                    }
                    .onChange(of: archiveArea) { _, _ in
                        ensureValidFolderSelection()
                    }

                    Picker(
                        "Ordner",
                        selection: $selectedFolderName
                    ) {
                        if filteredFolders.isEmpty {
                            Text("Keine Ordner vorhanden")
                                .tag("")
                        } else {
                            ForEach(filteredFolders) { folder in
                                Text(folder.name)
                                    .tag(folder.name)
                            }
                        }
                    }
                    .disabled(filteredFolders.isEmpty)

                    if let selectedFolder {
                        Label(
                            selectedFolder.displayPath,
                            systemImage: "folder.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button(
                    "Abbrechen",
                    action: onCancel
                )

                Spacer()

                Button("Lernen") {
                    onSave(
                        cleanedCompany,
                        documentType,
                        hasDate ? detectedDate : nil,
                        cleanedKeywords,
                        archiveArea,
                        selectedFolderName
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
            .padding()
        }
        .frame(
            minWidth: 520,
            minHeight: 560
        )
        .onAppear {
            populateInitialValues()
            ensureValidFolderSelection()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.title)

            VStack(alignment: .leading, spacing: 3) {
                Text("Atlas helfen")
                    .font(.title2.bold())

                Text(
                    "Ergänze fehlende Informationen und wähle den passenden Zielordner."
                )
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    private var availableAreas: [ArchiveArea] {
        let areas = Set(
            archiveFolders.map(\.area)
        )

        return areas.sorted {
            $0.rawValue.localizedStandardCompare(
                $1.rawValue
            ) == .orderedAscending
        }
    }

    private var filteredFolders: [ArchiveFolder] {
        archiveFolders.filter {
            $0.area == archiveArea
        }
    }

    private var selectedFolder: ArchiveFolder? {
        filteredFolders.first {
            $0.name == selectedFolderName
        }
    }

    private var cleanedCompany: String? {
        let value = company.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return value.isEmpty ? nil : value
    }

    private var cleanedKeywords: [String] {
        keywordsText
            .split(separator: ",")
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }
    }

    private var canSave: Bool {
        documentType != .unknown
            && !selectedFolderName.isEmpty
    }

    private func populateInitialValues() {
        if let currentAnalysis {
            company = currentAnalysis.sender ?? ""
            documentType = currentAnalysis.documentType

            if let date = currentAnalysis.detectedDate {
                detectedDate = date
                hasDate = true
            }

            keywordsText =
                currentAnalysis.keywords.joined(
                    separator: ", "
                )
        }

        if let currentFolderSuggestion {
            archiveArea = currentFolderSuggestion.area
            selectedFolderName =
                currentFolderSuggestion.folder
        }
    }

    private func ensureValidFolderSelection() {
        guard !filteredFolders.isEmpty else {
            selectedFolderName = ""
            return
        }

        let stillValid = filteredFolders.contains {
            $0.name == selectedFolderName
        }

        if !stillValid {
            selectedFolderName =
                filteredFolders[0].name
        }
    }
}

#Preview {
    AtlasLearningSheet(
        currentAnalysis: AtlasAnalysis(
            documentType: .invoice,
            detectedDate: Date(),
            sender: nil,
            keywords: [],
            confidence: 0.35,
            reasons: []
        ),
        currentFolderSuggestion: FolderSuggestion(
            ruleName: "Betrieb Belege",
            area: .business,
            folder: "Belege",
            confidence: 0.55,
            reasons: []
        ),
        onCancel: {},
        onSave: { _, _, _, _, _, _ in }
    )
}
