import SwiftUI
import AppKit

struct LearningSettingsView: View {

    @Bindable var settingsManager: SettingsManager

    @State private var learningManager =
        LearningManager()

    @State private var visualLearningManager =
        VisualSenderLearningManager()

    @State private var selectedVisualEntry:
        VisualSenderLearningEntry?

    @State private var reassignmentCompany =
        ""

    @State private var showLearnedAssignments =
        false

    @State private var showLearnedGraphics =
        false

    @State private var expandedVisualCompanies:
        Set<String> = []

    @State private var previewVisualEntry:
        VisualSenderLearningEntry?

    private let visualLearningStore =
        VisualSenderLearningStore()

    private let learnedCompanyStore =
        LearnedCompanyStore()

    @State private var learningRecords:
        [AtlasLearningRecord] = []

    @State private var showLearningProgress =
        false

    private let learningStore =
        AtlasLearningStore()

    var body: some View {

        Form {

            // MARK: - Lernfortschritt

            Section("Lernfortschritt") {

                if learningRecords.isEmpty {

                    VStack(
                        alignment: .leading,
                        spacing: 5
                    ) {

                        Text(
                            "Noch keine Auswertung verfügbar"
                        )
                        .font(.headline)

                        Text(
                            "Sobald Dokumente archiviert wurden, zeigt Atlas hier seine Erkennungsgenauigkeit."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                } else {

                    VStack(
                        alignment: .leading,
                        spacing: 12
                    ) {

                        HStack {

                            VStack(
                                alignment: .leading,
                                spacing: 3
                            ) {

                                Text(
                                    "\(statistics.totalCount) Dokumente ausgewertet"
                                )
                                .font(.headline)

                                Text(
                                    "\(statistics.completelyCorrectCount) vollständig ohne Korrektur"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(
                                percentage(
                                    statistics
                                        .completelyCorrectAccuracy
                                )
                            )
                            .font(
                                .title2.bold()
                            )
                        }

                        Divider()

                        HStack(
                            spacing: 20
                        ) {

                            progressValue(
                                title: "Absender",
                                value:
                                    statistics
                                        .senderAccuracy
                            )

                            progressValue(
                                title: "Dokumentenart",
                                value:
                                    statistics
                                        .documentTypeAccuracy
                            )

                            progressValue(
                                title: "Datum",
                                value:
                                    statistics
                                        .dateAccuracy
                            )

                            progressValue(
                                title: "Ablage",
                                value:
                                    statistics
                                        .archiveDestinationAccuracy
                            )
                        }

                        Divider()

                        Button {

                            showLearningProgress =
                                true

                        } label: {

                            Label(
                                "Details anzeigen",
                                systemImage:
                                    "chart.bar.xaxis"
                            )
                        }
                    }
                }
            }

            // MARK: - Lernfunktion

            Section("Lernfunktion") {

                Toggle(
                    "Learning aktivieren",
                    isOn:
                        Binding(
                            get: {

                                settingsManager
                                    .settings
                                    .learningEnabled
                            },

                            set: {
                                newValue in

                                settingsManager.update {

                                    $0.learningEnabled =
                                        newValue
                                }
                            }
                        )
                )

                Text(
                    "Atlas kann bestätigte Zuordnungen speichern und später für bessere Vorschläge verwenden."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // MARK: - Gelernte Zuordnungen

            Section {

                DisclosureGroup(
                    isExpanded:
                        $showLearnedAssignments
                ) {

                                if learningManager
                                    .entries
                                    .isEmpty {

                                    Text(
                                        "Atlas hat bisher noch nichts gelernt."
                                    )
                                    .foregroundStyle(
                                        .secondary
                                    )

                                } else {

                                    ForEach(
                                        learningManager
                                            .entries
                                            .sorted {
                                                ($0.company ?? "")
                                                    .localizedStandardCompare(
                                                        $1.company ?? ""
                                                    ) ==
                                                    .orderedAscending
                                            }
                                    ) {
                                        entry in

                                        HStack {

                                            VStack(
                                                alignment: .leading,
                                                spacing: 3
                                            ) {

                                                Text(
                                                    entry.company
                                                    ??
                                                    "Unbekannter Absender"
                                                )
                                                .font(.headline)

                                                Text(
                                                    "\(entry.archiveArea.rawValue) → \(entry.folder)"
                                                )
                                                .foregroundStyle(
                                                    .secondary
                                                )

                                                Text(
                                                    entry.documentType
                                                        .rawValue
                                                )
                                                .font(.caption)
                                                .foregroundStyle(
                                                    .secondary
                                                )
                                            }

                                            Spacer()

                                            Button {

                                                learningManager
                                                    .remove(
                                                        entry
                                                    )

                                            } label: {

                                                Image(
                                                    systemName:
                                                        "trash"
                                                )
                                            }
                                            .buttonStyle(
                                                .borderless
                                            )
                                            .help(
                                                "Zuordnung löschen"
                                            )
                                        }
                                    }
                                }


                } label: {

                    HStack {

                        Label(
                            "Gelernte Zuordnungen",
                            systemImage:
                                "tray.full"
                        )

                        Spacer()

                        Text(
                            "\(learningManager.entries.count)"
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                    .font(
                        .headline
                    )
                }
            }

            // MARK: - Gelernte Grafiken

            Section {

                DisclosureGroup(
                    isExpanded:
                        $showLearnedGraphics
                ) {

                    if visualLearningManager
                        .entries
                        .isEmpty {

                        VStack(
                            alignment:
                                .leading,
                            spacing:
                                5
                        ) {

                            Text(
                                "Noch keine Grafiken gelernt"
                            )
                            .font(
                                .headline
                            )

                            Text(
                                "Sobald du im Korrekturfenster „Grafik gehört definitiv zu …“ bestätigst, erscheint die visuelle Zuordnung hier."
                            )
                            .font(
                                .caption
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }
                        .padding(
                            .top,
                            8
                        )

                    } else {

                        VStack(
                            alignment:
                                .leading,
                            spacing:
                                8
                        ) {

                            ForEach(
                                visualCompanyGroups,
                                id:
                                    \.company
                            ) {
                                group in

                                DisclosureGroup(
                                    isExpanded:
                                        visualCompanyBinding(
                                            for:
                                                group.company
                                        )
                                ) {

                                    VStack(
                                        spacing:
                                            0
                                    ) {

                                        ForEach(
                                            group.entries
                                        ) {
                                            entry in

                                            visualEntryRow(
                                                entry
                                            )

                                            if entry.id !=
                                                group.entries.last?.id {

                                                Divider()
                                            }
                                        }
                                    }
                                    .padding(
                                        .leading,
                                        22
                                    )
                                    .padding(
                                        .top,
                                        4
                                    )

                                } label: {

                                    HStack {

                                        Text(
                                            group.company
                                        )
                                        .fontWeight(
                                            .semibold
                                        )

                                        Spacer()

                                        Text(
                                            group.entries.count == 1
                                            ? "1 Grafik"
                                            : "\(group.entries.count) Grafiken"
                                        )
                                        .font(
                                            .caption
                                        )
                                        .foregroundStyle(
                                            .secondary
                                        )
                                    }
                                }
                                .padding(
                                    .vertical,
                                    3
                                )
                            }

                            Text(
                                "Neue visuelle Bestätigungen zeigen den tatsächlich von Atlas verwendeten Dokumentkopf als Vorschau. Ältere Einträge besitzen noch kein Bild."
                            )
                            .font(
                                .caption
                            )
                            .foregroundStyle(
                                .secondary
                            )
                            .padding(
                                .top,
                                6
                            )
                        }
                        .padding(
                            .top,
                            8
                        )
                    }

                } label: {

                    HStack {

                        Label(
                            "Gelernte Grafiken",
                            systemImage:
                                "viewfinder"
                        )

                        Spacer()

                        Text(
                            "\(visualLearningManager.entries.count) · \(visualCompanyGroups.count) Firmen"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                    .font(
                        .headline
                    )
                }
            }

            // MARK: - Zurücksetzen

            Section("Zurücksetzen") {

                Button(
                    "Alle gelernten Zuordnungen löschen",
                    role:
                        .destructive
                ) {

                    learningManager
                        .clear()
                }
                .disabled(
                    learningManager
                        .entries
                        .isEmpty
                )

                Button(
                    "Alle gelernten Grafiken löschen",
                    role:
                        .destructive
                ) {

                    visualLearningManager
                        .clear()
                }
                .disabled(
                    visualLearningManager
                        .entries
                        .isEmpty
                )
            }
        }
        .formStyle(
            .grouped
        )
        .navigationTitle(
            "Lernen"
        )
        .onAppear {

            reload()
        }
        .sheet(
            isPresented:
                $showLearningProgress
        ) {

            AtlasLearningView()
        }
        .sheet(
            item:
                $selectedVisualEntry
        ) {
            entry in

            visualReassignmentSheet(
                entry
            )
        }
        .sheet(
            item:
                $previewVisualEntry
        ) {
            entry in

            visualPreviewSheet(
                entry
            )
        }
    }

    // MARK: - Visual Graphics Groups

    private struct VisualCompanyGroup {

        let company:
            String

        let entries:
            [VisualSenderLearningEntry]
    }

    private var visualCompanyGroups:
        [VisualCompanyGroup] {

        let grouped =
            Dictionary(
                grouping:
                    visualLearningManager
                        .entries
            ) {
                entry in

                entry.company
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
            }

        return grouped
            .map {
                company,
                entries in

                VisualCompanyGroup(
                    company:
                        company,
                    entries:
                        entries.sorted {

                            if $0.confirmationCount !=
                                $1.confirmationCount {

                                return $0.confirmationCount >
                                    $1.confirmationCount
                            }

                            return $0.lastConfirmedAt >
                                $1.lastConfirmedAt
                        }
                )
            }
            .sorted {

                $0.company
                    .localizedStandardCompare(
                        $1.company
                    ) ==
                    .orderedAscending
            }
    }

    private func visualCompanyBinding(
        for company:
            String
    ) -> Binding<Bool> {

        Binding(
            get: {

                expandedVisualCompanies
                    .contains(
                        company
                    )
            },
            set: {
                isExpanded in

                if isExpanded {

                    expandedVisualCompanies
                        .insert(
                            company
                        )

                } else {

                    expandedVisualCompanies
                        .remove(
                            company
                        )
                }
            }
        )
    }

    @ViewBuilder
    private func visualEntryRow(
        _ entry:
            VisualSenderLearningEntry
    ) -> some View {

        HStack(
            spacing:
                12
        ) {

            if let previewImage =
                previewImage(
                    for:
                        entry
                ) {

                Button {

                    previewVisualEntry =
                        entry

                } label: {

                    Image(
                        nsImage:
                            previewImage
                    )
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width:
                            92,
                        height:
                            54
                    )
                    .background(
                        Color.white
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius:
                                6
                        )
                    )
                    .overlay {

                        RoundedRectangle(
                            cornerRadius:
                                6
                        )
                        .stroke(
                            Color.secondary
                                .opacity(
                                    0.25
                                ),
                            lineWidth:
                                1
                        )
                    }
                }
                .buttonStyle(
                    .plain
                )
                .help(
                    "Grafik groß anzeigen"
                )

            } else {

                Image(
                    systemName:
                        "viewfinder"
                )
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    width:
                        92,
                    height:
                        54
                )
            }

            VStack(
                alignment:
                    .leading,
                spacing:
                    3
            ) {

                HStack(
                    spacing:
                        8
                ) {

                    Text(
                        entry.confirmationCount == 1
                        ? "1× bestätigt"
                        : "\(entry.confirmationCount)× bestätigt"
                    )
                    .fontWeight(
                        .medium
                    )

                    Text(
                        "·"
                    )

                    Text(
                        entry.lastConfirmedAt
                            .formatted(
                                date:
                                    .abbreviated,
                                time:
                                    .omitted
                            )
                    )
                }
                .font(
                    .caption
                )

                if entry
                    .canUseAutomatically {

                    Text(
                        "Automatische Verwendung aktiv"
                    )
                    .font(
                        .caption2
                    )
                    .foregroundStyle(
                        .secondary
                    )

                } else {

                    Text(
                        "Noch nicht automatisch – ab 3 Bestätigungen"
                    )
                    .font(
                        .caption2
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            Spacer()

            Button {

                reassignmentCompany =
                    entry.company

                selectedVisualEntry =
                    entry

            } label: {

                Image(
                    systemName:
                        "pencil"
                )
            }
            .buttonStyle(
                .borderless
            )
            .help(
                "Grafik einer anderen Firma zuordnen"
            )

            Button(
                role:
                    .destructive
            ) {

                visualLearningManager
                    .remove(
                        entry
                    )

            } label: {

                Image(
                    systemName:
                        "trash"
                )
            }
            .buttonStyle(
                .borderless
            )
            .help(
                "Gelernte Grafik löschen"
            )
        }
        .padding(
            .vertical,
            7
        )
    }

    // MARK: - Visual Preview

    private func previewImage(
        for entry:
            VisualSenderLearningEntry
    ) -> NSImage? {

        guard
            let url =
                visualLearningStore
                    .previewURL(
                        for:
                            entry.previewFilename
                    )
        else {

            return nil
        }

        return NSImage(
            contentsOf:
                url
        )
    }

    private func visualPreviewSheet(
        _ entry:
            VisualSenderLearningEntry
    ) -> some View {

        NavigationStack {

            VStack(
                alignment:
                    .leading,
                spacing:
                    16
            ) {

                HStack {

                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            3
                    ) {

                        Text(
                            entry.company
                        )
                        .font(
                            .headline
                        )

                        Text(
                            entry.confirmationCount == 1
                            ? "1× bestätigt"
                            : "\(entry.confirmationCount)× bestätigt"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Spacer()

                    Button(
                        "Schließen"
                    ) {

                        previewVisualEntry =
                            nil
                    }
                }

                Divider()

                if let image =
                    previewImage(
                        for:
                            entry
                    ) {

                    ScrollView(
                        [
                            .horizontal,
                            .vertical
                        ]
                    ) {

                        Image(
                            nsImage:
                                image
                        )
                        .resizable()
                        .scaledToFit()
                        .frame(
                            maxWidth:
                                1100
                        )
                        .background(
                            Color.white
                        )
                    }

                } else {

                    ContentUnavailableView(
                        "Keine Vorschau vorhanden",
                        systemImage:
                            "photo.badge.exclamationmark",
                        description:
                            Text(
                                "Dieser ältere Lerneintrag besitzt noch kein gespeichertes Vorschaubild."
                            )
                    )
                }
            }
            .padding(
                20
            )
            .navigationTitle(
                "Gelernte Grafik"
            )
        }
        .frame(
            minWidth:
                760,
            minHeight:
                520
        )
    }

    // MARK: - Visual Reassignment

    private func visualReassignmentSheet(
        _ entry:
            VisualSenderLearningEntry
    ) -> some View {

        NavigationStack {

            Form {

                Section(
                    "Aktuelle Zuordnung"
                ) {

                    LabeledContent(
                        "Firma",
                        value:
                            entry.company
                    )

                    LabeledContent(
                        "Bestätigungen",
                        value:
                            "\(entry.confirmationCount)×"
                    )
                }

                Section(
                    "Neue Zuordnung"
                ) {

                    TextField(
                        "Firmenname",
                        text:
                            $reassignmentCompany
                    )

                    if !availableCompanies
                        .isEmpty {

                        Menu(
                            "Bekannte Firma auswählen"
                        ) {

                            ForEach(
                                availableCompanies,
                                id:
                                    \.self
                            ) {
                                company in

                                Button(
                                    company
                                ) {

                                    reassignmentCompany =
                                        company
                                }
                            }
                        }
                    }

                    Text(
                        "Die bestehende visuelle Signatur und ihre Bestätigungszahl bleiben erhalten. Nur der Firmenname wird geändert."
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
            .formStyle(
                .grouped
            )
            .navigationTitle(
                "Grafik neu zuordnen"
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {

                    Button(
                        "Abbrechen"
                    ) {

                        selectedVisualEntry =
                            nil
                    }
                }

                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {

                    Button(
                        "Übernehmen"
                    ) {

                        let cleaned =
                            reassignmentCompany
                                .trimmingCharacters(
                                    in:
                                        .whitespacesAndNewlines
                                )

                        guard
                            !cleaned.isEmpty
                        else {

                            return
                        }

                        _ =
                            visualLearningManager
                                .reassign(
                                    entry,
                                    to:
                                        cleaned
                                )

                        // Frei eingetragene Firma auch für
                        // künftige Auswahllisten merken.
                        learnedCompanyStore
                            .add(
                                cleaned
                            )

                        selectedVisualEntry =
                            nil
                    }
                    .disabled(
                        reassignmentCompany
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .isEmpty
                    )
                }
            }
        }
        .frame(
            minWidth:
                480,
            minHeight:
                320
        )
    }

    private var availableCompanies:
        [String] {

        var names:
            [String] = []

        if let knowledgeBase =
            try? KnowledgeBase.load() {

            names +=
                knowledgeBase
                    .companies
                    .map(
                        \.name
                    )
        }

        names +=
            learnedCompanyStore
                .load()

        names +=
            visualLearningManager
                .entries
                .map(
                    \.company
                )

        var result:
            [String] = []

        var known:
            Set<String> = []

        for name in names {

            let cleaned =
                name.trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

            guard
                !cleaned.isEmpty
            else {

                continue
            }

            let key =
                cleaned
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

    // MARK: - Statistics

    private var statistics:
        AtlasLearningStatistics {

        AtlasLearningStatistics(
            records:
                learningRecords
        )
    }

    // MARK: - Progress Value

    private func progressValue(
        title: String,
        value: Double
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 3
        ) {

            Text(
                title
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )

            Text(
                percentage(
                    value
                )
            )
            .font(
                .headline
            )
        }
        .frame(
            maxWidth:
                .infinity,
            alignment:
                .leading
        )
    }

    // MARK: - Percentage

    private func percentage(
        _ value: Double
    ) -> String {

        "\(Int((value * 100).rounded())) %"
    }

    // MARK: - Reload

    private func reload() {

        learningManager.reload()

        visualLearningManager
            .reload()

        learningRecords =
            learningStore.load()
    }
}

// MARK: - Preview

#Preview {

    NavigationStack {

        LearningSettingsView(
            settingsManager:
                SettingsManager()
        )
    }
}
