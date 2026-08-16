import SwiftUI

struct AtlasLearningView: View {

    @Environment(\.dismiss)
    private var dismiss

    private let store =
        AtlasLearningStore()

    @State private var records:
        [AtlasLearningRecord] = []

    @State private var expandedCompanies:
        Set<String> = []

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 18
            ) {

                header

                if records.isEmpty {

                    emptyState

                } else {

                    summarySection

                    accuracySection

                    overallSection

                    companySection

                    correctionSection

                    recentSection
                }
            }
            .padding(20)
        }
        .frame(
            minWidth: 760,
            idealWidth: 900,
            minHeight: 620,
            idealHeight: 760
        )
        .onAppear {

            reload()
        }
    }

    // MARK: - Statistics

    private var statistics:
        AtlasLearningStatistics {

        AtlasLearningStatistics(
            records:
                records
        )
    }

    // MARK: - Header

    private var header:
        some View {

        HStack(
            spacing: 12
        ) {

            Image(
                systemName:
                    "brain.head.profile"
            )
            .font(
                .system(
                    size: 28
                )
            )

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text(
                    "Atlas Lernfortschritt"
                )
                .font(
                    .title2.bold()
                )

                Text(
                    "Auswertung der bisher archivierten Dokumente"
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            Button {

                reload()

            } label: {

                Label(
                    "Aktualisieren",
                    systemImage:
                        "arrow.clockwise"
                )
            }

            Button {

                dismiss()

            } label: {

                Label(
                    "Schließen",
                    systemImage:
                        "xmark"
                )
            }
            .keyboardShortcut(
                .cancelAction
            )
        }
    }

    // MARK: - Empty

    private var emptyState:
        some View {

        ContentUnavailableView(
            "Noch keine Lerndaten",
            systemImage:
                "brain",
            description:
                Text(
                    "Sobald Dokumente mit Atlas archiviert werden, erscheinen hier die ersten Auswertungen."
                )
        )
        .frame(
            maxWidth:
                .infinity,
            minHeight:
                400
        )
    }

    // MARK: - Summary

    private var summarySection:
        some View {

        HStack(
            spacing: 12
        ) {

            summaryCard(
                title:
                    "Dokumente",
                value:
                    "\(statistics.totalCount)",
                systemImage:
                    "doc.text"
            )

            summaryCard(
                title:
                    "Komplett richtig",
                value:
                    percentage(
                        statistics
                            .completelyCorrectAccuracy
                    ),
                systemImage:
                    "checkmark.circle"
            )

            summaryCard(
                title:
                    "Ohne Korrektur",
                value:
                    "\(statistics.completelyCorrectCount)",
                systemImage:
                    "archivebox"
            )
        }
    }

    private func summaryCard(
        title: String,
        value: String,
        systemImage: String
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            HStack {

                Image(
                    systemName:
                        systemImage
                )

                Text(
                    title
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Text(
                value
            )
            .font(
                .system(
                    size: 28,
                    weight: .bold
                )
            )
        }
        .frame(
            maxWidth:
                .infinity,
            alignment:
                .leading
        )
        .padding(16)
        .background(
            .quaternary,
            in:
                RoundedRectangle(
                    cornerRadius: 14
                )
        )
    }

    // MARK: - Accuracy

    private var accuracySection:
        some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            sectionTitle(
                "Erkennungsgenauigkeit"
            )

            VStack(
                spacing: 0
            ) {

                accuracyRow(
                    title:
                        "Absender",
                    correct:
                        statistics
                            .senderCorrectCount,
                    corrected:
                        statistics
                            .senderCorrectedCount,
                    accuracy:
                        statistics
                            .senderAccuracy,
                    systemImage:
                        "person.text.rectangle"
                )

                Divider()

                accuracyRow(
                    title:
                        "Empfänger",
                    correct:
                        statistics
                            .recipientCorrectCount,
                    corrected:
                        statistics
                            .recipientCorrectedCount,
                    accuracy:
                        statistics
                            .recipientAccuracy,
                    systemImage:
                        "building.2"
                )

                Divider()

                accuracyRow(
                    title:
                        "Dokumentenart",
                    correct:
                        statistics
                            .documentTypeCorrectCount,
                    corrected:
                        statistics
                            .documentTypeCorrectedCount,
                    accuracy:
                        statistics
                            .documentTypeAccuracy,
                    systemImage:
                        "doc.text"
                )

                Divider()

                accuracyRow(
                    title:
                        "Datum",
                    correct:
                        statistics
                            .dateCorrectCount,
                    corrected:
                        statistics
                            .dateCorrectedCount,
                    accuracy:
                        statistics
                            .dateAccuracy,
                    systemImage:
                        "calendar"
                )

                Divider()

                accuracyRow(
                    title:
                        "Ablageort",
                    correct:
                        statistics
                            .archiveDestinationCorrectCount,
                    corrected:
                        statistics
                            .archiveDestinationCorrectedCount,
                    accuracy:
                        statistics
                            .archiveDestinationAccuracy,
                    systemImage:
                        "folder"
                )
            }
            .padding(
                .horizontal,
                14
            )
            .background(
                .quaternary,
                in:
                    RoundedRectangle(
                        cornerRadius:
                            14
                    )
            )
        }
    }

    private func accuracyRow(
        title: String,
        correct: Int,
        corrected: Int,
        accuracy: Double,
        systemImage: String
    ) -> some View {

        HStack(
            spacing: 12
        ) {

            Image(
                systemName:
                    systemImage
            )
            .frame(
                width: 24
            )

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text(
                    title
                )
                .font(
                    .headline
                )

                Text(
                    "\(correct) richtig · \(corrected) korrigiert"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            Text(
                percentage(
                    accuracy
                )
            )
            .font(
                .title3.bold()
            )
        }
        .padding(
            .vertical,
            13
        )
    }

    // MARK: - Overall

    private var overallSection:
        some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            sectionTitle(
                "Gesamtergebnis"
            )

            HStack(
                spacing: 14
            ) {

                Image(
                    systemName:
                        overallSymbol
                )
                .font(
                    .system(
                        size: 30
                    )
                )

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {

                    Text(
                        overallTitle
                    )
                    .font(
                        .headline
                    )

                    Text(
                        "\(statistics.completelyCorrectCount) von \(statistics.totalCount) Dokumenten wurden ohne Korrektur vollständig richtig erkannt und abgelegt."
                    )
                    .font(
                        .callout
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

                Spacer()
            }
            .padding(16)
            .background(
                .quaternary,
                in:
                    RoundedRectangle(
                        cornerRadius:
                            14
                    )
            )
        }
    }

    // MARK: - Company Statistics

    private var companySection:
        some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            HStack {

                sectionTitle(
                    "Erkennung nach Absender"
                )

                Spacer()

                Text(
                    "\(statistics.companyStatistics.count) Absender"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if statistics.companyStatistics.isEmpty {

                Text(
                    "Noch keine bestätigten Absender für eine Firmenauswertung vorhanden."
                )
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)

            } else {

                VStack(
                    spacing: 0
                ) {

                    ForEach(
                        statistics.companyStatistics
                    ) {
                        company in

                        companyRow(
                            company
                        )

                        if company.id !=
                            statistics.companyStatistics.last?.id {

                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(
                    .quaternary,
                    in:
                        RoundedRectangle(
                            cornerRadius: 14
                        )
                )
            }
        }
    }

    // MARK: - Company Row

    private func companyRow(
        _ company:
            AtlasCompanyLearningStatistics
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 0
        ) {

            Button {

                toggleCompany(
                    company.id
                )

            } label: {

                HStack(
                    spacing: 12
                ) {

                    Image(
                        systemName:
                            isCompanyExpanded(
                                company.id
                            )
                            ? "chevron.down"
                            : "chevron.right"
                    )
                    .font(.caption.weight(.semibold))
                    .frame(width: 12)

                    VStack(
                        alignment: .leading,
                        spacing: 3
                    ) {

                        Text(
                            company.company
                        )
                        .font(.headline)

                        Text(
                            "\(company.totalCount) Dokumente · \(company.completelyCorrectCount) komplett richtig"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(
                        percentage(
                            company.completelyCorrectAccuracy
                        )
                    )
                    .font(.title3.bold())
                }
                .contentShape(
                    Rectangle()
                )
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if isCompanyExpanded(
                company.id
            ) {

                Divider()

                companyAccuracyGrid(
                    company
                )
                .padding(.vertical, 12)

                if !company.documentTypes.isEmpty {

                    Divider()

                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {

                        Text(
                            "Dokumentenarten"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                        ForEach(
                            company.documentTypes
                        ) {
                            documentType in

                            companyDocumentTypeRow(
                                documentType
                            )
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - Company Accuracy Grid

    private func companyAccuracyGrid(
        _ company:
            AtlasCompanyLearningStatistics
    ) -> some View {

        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            alignment: .leading,
            spacing: 12
        ) {

            companyMetric(
                title: "Absender",
                value: company.senderAccuracy
            )

            companyMetric(
                title: "Empfänger",
                value: company.recipientAccuracy
            )

            companyMetric(
                title: "Dokumentart",
                value: company.documentTypeAccuracy
            )

            companyMetric(
                title: "Datum",
                value: company.dateAccuracy
            )

            companyMetric(
                title: "Ablage",
                value: company.archiveDestinationAccuracy
            )
        }
    }

    // MARK: - Company Metric

    private func companyMetric(
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
            .foregroundStyle(.secondary)

            Text(
                percentage(
                    value
                )
            )
            .font(.headline)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    // MARK: - Company Document Type Row

    private func companyDocumentTypeRow(
        _ statistics:
            AtlasCompanyDocumentTypeStatistics
    ) -> some View {

        HStack(
            spacing: 12
        ) {

            Image(
                systemName: "doc.text"
            )
            .foregroundStyle(.secondary)
            .frame(width: 20)

            VStack(
                alignment: .leading,
                spacing: 2
            ) {

                Text(
                    statistics.documentType
                )
                .font(.callout.weight(.medium))

                Text(
                    "\(statistics.correctCount) richtig · \(statistics.correctedCount) korrigiert · \(statistics.totalCount) gesamt"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(
                percentage(
                    statistics.accuracy
                )
            )
            .font(.headline)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Company Expansion

    private func isCompanyExpanded(
        _ id: String
    ) -> Bool {

        expandedCompanies.contains(
            id
        )
    }

    private func toggleCompany(
        _ id: String
    ) {

        if expandedCompanies.contains(
            id
        ) {

            expandedCompanies.remove(
                id
            )

        } else {

            expandedCompanies.insert(
                id
            )
        }
    }

    // MARK: - Corrections

    private var correctionSection:
        some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            sectionTitle(
                "Häufige Korrekturen"
            )

            if allCorrections.isEmpty {

                Text(
                    "Bisher wurden keine wiederkehrenden Korrekturen erfasst."
                )
                .foregroundStyle(
                    .secondary
                )
                .padding(
                    .vertical,
                    8
                )

            } else {

                VStack(
                    spacing: 0
                ) {

                    ForEach(
                        allCorrections
                            .prefix(15)
                    ) {
                        item in

                        correctionRow(
                            item
                        )

                        if item.id !=
                            allCorrections
                                .prefix(15)
                                .last?
                                .id {

                            Divider()
                        }
                    }
                }
                .padding(
                    .horizontal,
                    14
                )
                .background(
                    .quaternary,
                    in:
                        RoundedRectangle(
                            cornerRadius:
                                14
                        )
                )
            }
        }
    }

    private func correctionRow(
        _ item:
            DisplayCorrection
    ) -> some View {

        HStack(
            spacing: 12
        ) {

            Image(
                systemName:
                    item.systemImage
            )
            .frame(
                width:
                    22
            )

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text(
                    item.category
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )

                Text(
                    "\(item.correction.from) → \(item.correction.to)"
                )
                .font(
                    .callout.weight(
                        .medium
                    )
                )
            }

            Spacer()

            Text(
                "\(item.correction.count)×"
            )
            .font(
                .headline
            )
        }
        .padding(
            .vertical,
            10
        )
    }

    // MARK: - Recent

    private var recentSection:
        some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            sectionTitle(
                "Letzte Lernvorgänge"
            )

            VStack(
                spacing: 0
            ) {

                ForEach(
                    statistics
                        .recentRecords
                ) {
                    record in

                    recentRecordRow(
                        record
                    )

                    if record.id !=
                        statistics
                            .recentRecords
                            .last?
                            .id {

                        Divider()
                    }
                }
            }
            .padding(
                .horizontal,
                14
            )
            .background(
                .quaternary,
                in:
                    RoundedRectangle(
                        cornerRadius:
                            14
                    )
            )
        }
    }

    private func recentRecordRow(
        _ record:
            AtlasLearningRecord
    ) -> some View {

        HStack(
            spacing: 12
        ) {

            Image(
                systemName:
                    recordWasCorrected(
                        record
                    )
                    ? "pencil.circle.fill"
                    : "checkmark.circle.fill"
            )
            .foregroundStyle(
                recordWasCorrected(
                    record
                )
                ? .orange
                : .green
            )

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text(
                    record.filename
                )
                .lineLimit(
                    1
                )

                Text(
                    recentDescription(
                        for:
                            record
                    )
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            Text(
                record.createdAt
                    .formatted(
                        date:
                            .abbreviated,
                        time:
                            .shortened
                    )
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )
        }
        .padding(
            .vertical,
            10
        )
    }

    // MARK: - Corrections Combined

    private var allCorrections:
        [DisplayCorrection] {

        var result:
            [DisplayCorrection] = []

        result +=
            statistics
                .senderCorrections
                .map {

                    DisplayCorrection(
                        category:
                            "Absender",
                        systemImage:
                            "person.text.rectangle",
                        correction:
                            $0
                    )
                }

        result +=
            statistics
                .recipientCorrections
                .map {

                    DisplayCorrection(
                        category:
                            "Empfänger",
                        systemImage:
                            "building.2",
                        correction:
                            $0
                    )
                }

        result +=
            statistics
                .documentTypeCorrections
                .map {

                    DisplayCorrection(
                        category:
                            "Dokumentenart",
                        systemImage:
                            "doc.text",
                        correction:
                            $0
                    )
                }

        result +=
            statistics
                .archiveDestinationCorrections
                .map {

                    DisplayCorrection(
                        category:
                            "Ablageort",
                        systemImage:
                            "folder",
                        correction:
                            $0
                    )
                }

        return result.sorted {

            if $0.correction.count ==
                $1.correction.count {

                return $0.category
                    .localizedStandardCompare(
                        $1.category
                    )
                ==
                .orderedAscending
            }

            return $0.correction.count >
                $1.correction.count
        }
    }

    // MARK: - Helpers

    private func sectionTitle(
        _ title: String
    ) -> some View {

        Text(
            title
        )
        .font(
            .headline
        )
    }

    private func percentage(
        _ value: Double
    ) -> String {

        "\(Int((value * 100).rounded())) %"
    }

    private func recordWasCorrected(
        _ record:
            AtlasLearningRecord
    ) -> Bool {

        record.senderWasCorrected
        ||
        record.recipientWasCorrected
        ||
        record.documentTypeWasCorrected
        ||
        record.dateWasCorrected
        ||
        archiveDestinationWasCorrected(
            record
        )
    }

    private func recentDescription(
        for record:
            AtlasLearningRecord
    ) -> String {

        var parts:
            [String] = []

        if record.senderWasCorrected {

            parts.append(
                "Absender"
            )
        }

        if record.recipientWasCorrected {

            parts.append(
                "Empfänger"
            )
        }

        if record.documentTypeWasCorrected {

            parts.append(
                "Dokumentenart"
            )
        }

        if record.dateWasCorrected {

            parts.append(
                "Datum"
            )
        }

        if archiveDestinationWasCorrected(
            record
        ) {

            parts.append(
                "Ablageort"
            )
        }

        if parts.isEmpty {

            return "Ohne Korrektur archiviert"
        }

        return "Korrigiert: "
            +
            parts.joined(
                separator:
                    ", "
            )
    }

    private func archiveDestinationWasCorrected(
        _ record:
            AtlasLearningRecord
    ) -> Bool {

        normalize(
            record.suggestedArchiveArea
        )
        !=
        normalize(
            record.finalArchiveArea
        )
        ||
        normalize(
            record.suggestedFolder
        )
        !=
        normalize(
            record.finalFolder
        )
    }

    private func normalize(
        _ value: String?
    ) -> String {

        value?
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
        ?? ""
    }

    private var overallTitle:
        String {

        switch statistics
            .completelyCorrectAccuracy {

        case 0.90...:
            return "Atlas arbeitet sehr zuverlässig"

        case 0.75..<0.90:
            return "Atlas arbeitet bereits zuverlässig"

        case 0.50..<0.75:
            return "Atlas lernt noch"

        default:
            return "Atlas braucht noch mehr Beispiele"
        }
    }

    private var overallSymbol:
        String {

        switch statistics
            .completelyCorrectAccuracy {

        case 0.90...:
            return "checkmark.seal.fill"

        case 0.75..<0.90:
            return "checkmark.circle.fill"

        case 0.50..<0.75:
            return "brain.head.profile"

        default:
            return "exclamationmark.circle"
        }
    }

    // MARK: - Reload

    private func reload() {

        records =
            store.load()
    }
}

// MARK: - Display Correction

private struct DisplayCorrection:
    Identifiable {

    let category:
        String

    let systemImage:
        String

    let correction:
        AtlasLearningCorrection

    var id:
        String {

        "\(category)-\(correction.id)"
    }
}

// MARK: - Preview

#Preview {

    AtlasLearningView()
}
