import SwiftUI

struct AtlasReviewView: View {

    let document: DocumentRecord
    let analysis: AtlasAnalysis?
    let folderSuggestion: FolderSuggestion?

    let filenameDraft: String

    // MARK: - Visual Sender

    /// Absender, den Atlas aus Logo/Kopfbereich
    /// des Dokuments erkannt hat.
    let visualSenderSuggestion: String?

    /// Ähnlichkeit mit einer bereits bekannten
    /// visuellen Signatur, z. B. 0.941 = 94,1 %.
    let visualSenderSimilarity: Double?

    /// Wie oft diese visuelle Zuordnung bereits
    /// vom Benutzer bestätigt wurde.
    let visualSenderConfirmationCount: Int

    let isArchiving: Bool

    let onArchive: () -> Void
    let onEdit: () -> Void

    var body: some View {

        ScrollView {

            VStack(spacing: 14) {

                overviewCard

                confidenceCard

                actionCard
            }
            .padding(12)
        }
        .frame(
            minWidth: 320,
            idealWidth: 380
        )
        .background(
            Color(
                nsColor: .controlBackgroundColor
            )
        )
    }

    // MARK: - Overview

    private var overviewCard: some View {

        AtlasCard {

            VStack(
                alignment: .leading,
                spacing: 16
            ) {

                header

                Divider()

                VStack(spacing: 0) {

                    reviewRow(
                        title: "Firma",
                        value: recipientText,
                        systemImage: "building.2",
                        markerColor: .green
                    )

                    Divider()

                    senderRow

                    Divider()

                    reviewRow(
                        title: "Dokumentenart",
                        value: documentTypeText,
                        systemImage: "doc.text",
                        markerColor: .orange
                    )

                    Divider()

                    reviewRow(
                        title: "Datum",
                        value: dateText,
                        systemImage: "calendar",
                        markerColor: .yellow
                    )

                    Divider()

                    reviewRow(
                        title: "Schlüsselwörter",
                        value: keywordsText,
                        systemImage: "tag"
                    )

                    Divider()

                    reviewRow(
                        title: "Speicherort",
                        value: archivePathText,
                        systemImage: "folder"
                    )
                }

                Divider()

                filenameSection
            }
        }
    }

    // MARK: - Header

    private var header: some View {

        HStack(spacing: 10) {

            Image(
                systemName: "brain.head.profile"
            )
            .font(.title2)

            VStack(
                alignment: .leading,
                spacing: 2
            ) {

                Text("Atlas")
                    .font(.headline)

                Text(
                    "Dokument prüfen"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(confidenceColor)
                .frame(
                    width: 10,
                    height: 10
                )
        }
    }

    // MARK: - Normal Review Row

    private func reviewRow(
        title: String,
        value: String,
        systemImage: String,
        markerColor: Color? = nil
    ) -> some View {

        HStack(
            alignment: .firstTextBaseline,
            spacing: 10
        ) {

            Label(
                title,
                systemImage: systemImage
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(
                width: 125,
                alignment: .leading
            )

            HStack(
                spacing: 7
            ) {

                if let markerColor {

                    Circle()
                        .fill(markerColor)
                        .frame(
                            width: 8,
                            height: 8
                        )
                }

                Text(value)
                    .font(
                        .callout.weight(.semibold)
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
            }
        }
        .padding(
            .vertical,
            9
        )
    }

    // MARK: - Sender Row

    private var senderRow: some View {

        HStack(
            alignment: .top,
            spacing: 10
        ) {

            Label(
                "Absender",
                systemImage:
                    "person.text.rectangle"
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(
                width: 125,
                alignment: .leading
            )

            VStack(
                alignment: .leading,
                spacing: 5
            ) {

                HStack(spacing: 6) {

                    Circle()
                        .fill(Color.blue)
                        .frame(
                            width: 8,
                            height: 8
                        )

                    Text(senderText)
                        .font(
                            .callout.weight(
                                .semibold
                            )
                        )
                        .textSelection(
                            .enabled
                        )

                    if senderSourcesAgree {

                        Image(
                            systemName:
                                "checkmark.circle.fill"
                        )
                        .foregroundStyle(
                            .green
                        )
                        .help(
                            "Text- und Grafikerkennung stimmen überein."
                        )

                    } else if senderSourcesConflict {

                        Image(
                            systemName:
                                "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(
                            .orange
                        )
                        .help(
                            "Text- und Grafikerkennung erkennen unterschiedliche Absender."
                        )
                    }
                }

                visualSenderInformation
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        }
        .padding(
            .vertical,
            9
        )
    }

    // MARK: - Visual Sender Information

    @ViewBuilder
    private var visualSenderInformation: some View {

        if let visualSender =
            cleanedVisualSender {

            if senderSourcesAgree {

                HStack(spacing: 5) {

                    Image(
                        systemName:
                            "viewfinder"
                    )

                    Text(
                        visualAgreementText
                    )
                }
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

            } else if senderSourcesConflict {

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    HStack(spacing: 5) {

                        Image(
                            systemName:
                                "viewfinder"
                        )

                        Text(
                            "Grafik erkennt:"
                        )

                        Text(
                            visualSender
                        )
                        .fontWeight(
                            .semibold
                        )
                    }

                    if let similarityText =
                        visualSimilarityText {

                        Text(
                            similarityText
                        )
                    }

                    if visualSenderConfirmationCount > 0 {

                        Text(
                            confirmationText
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(
                    .orange
                )

            } else {

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    HStack(spacing: 5) {

                        Image(
                            systemName:
                                "viewfinder"
                        )

                        Text(
                            "Grafik erkennt:"
                        )

                        Text(
                            visualSender
                        )
                        .fontWeight(
                            .semibold
                        )
                    }

                    if let similarityText =
                        visualSimilarityText {

                        Text(
                            similarityText
                        )
                    }

                    if visualSenderConfirmationCount > 0 {

                        Text(
                            confirmationText
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }
        }
    }

    // MARK: - Filename Section

    private var filenameSection: some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(
                    "Alter Dateiname"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(
                    document.sourceURL
                        .lastPathComponent
                )
                .font(.callout)
                .textSelection(.enabled)
            }

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(
                    "Zukünftiger Dateiname"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(
                    futureFilename
                )
                .font(
                    .callout.weight(.semibold)
                )
                .textSelection(.enabled)
            }
        }
    }

    // MARK: - Confidence

    private var confidenceCard: some View {

        AtlasCard {

            HStack(spacing: 12) {

                Circle()
                    .fill(confidenceColor)
                    .frame(
                        width: 12,
                        height: 12
                    )

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    Text(
                        confidenceTitle
                    )
                    .font(.headline)

                    Text(
                        confidenceSubtitle
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text(
                    "\(confidencePercentage) %"
                )
                .font(
                    .title3.bold()
                )
            }
        }
    }

    // MARK: - Actions

    private var actionCard: some View {

        AtlasCard {

            VStack(spacing: 10) {

                Button {

                    onArchive()

                } label: {

                    Label(
                        isArchiving
                            ? "Archiviert …"
                            : "Alles stimmt – Archivieren",
                        systemImage:
                            isArchiving
                            ? "hourglass"
                            : "archivebox.fill"
                    )
                    .frame(
                        maxWidth: .infinity
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .disabled(
                    !canArchive ||
                    isArchiving
                )
                .keyboardShortcut(
                    .return,
                    modifiers: []
                )

                Button {

                    onEdit()

                } label: {

                    Label(
                        "Angaben korrigieren",
                        systemImage: "pencil"
                    )
                    .frame(
                        maxWidth: .infinity
                    )
                }
                .buttonStyle(.bordered)
                .disabled(isArchiving)
            }
        }
    }

    // MARK: - Values

    private var recipientText: String {

        analysis?
            .recipientArea?
            .rawValue
        ?? "Nicht erkannt"
    }

    private var senderText: String {

        let sender =
            analysis?
                .sender?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            let sender,
            !sender.isEmpty
        else {

            return "Nicht erkannt"
        }

        return sender
    }

    private var cleanedTextSender: String? {

        guard let sender =
            analysis?
                .sender?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                ),
            !sender.isEmpty
        else {

            return nil
        }

        return sender
    }

    private var cleanedVisualSender: String? {

        guard let sender =
            visualSenderSuggestion?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                ),
            !sender.isEmpty
        else {

            return nil
        }

        return sender
    }

    // MARK: - Sender Comparison

    private var senderSourcesAgree: Bool {

        guard
            let textSender =
                cleanedTextSender,
            let visualSender =
                cleanedVisualSender
        else {

            return false
        }

        return normalizeCompany(
            textSender
        ) ==
        normalizeCompany(
            visualSender
        )
    }

    private var senderSourcesConflict: Bool {

        guard
            cleanedTextSender != nil,
            cleanedVisualSender != nil
        else {

            return false
        }

        return !senderSourcesAgree
    }

    // MARK: - Visual Sender Text

    private var visualAgreementText: String {

        if let similarityText =
            visualSimilarityText {

            return "Text + Grafik stimmen überein · \(similarityText)"
        }

        return "Text + Grafik stimmen überein"
    }

    private var visualSimilarityText: String? {

        guard let similarity =
            visualSenderSimilarity
        else {

            return nil
        }

        let normalizedSimilarity =
            max(
                0,
                min(
                    similarity,
                    1
                )
            )

        let percentage =
            normalizedSimilarity
            * 100

        return String(
            format:
                "%.1f %% visuelle Ähnlichkeit",
            percentage
        )
    }

    private var confirmationText: String {

        if visualSenderConfirmationCount == 1 {

            return "1× bestätigt"
        }

        return "\(visualSenderConfirmationCount)× bestätigt"
    }

    // MARK: - Document Type

    private var documentTypeText: String {

        guard let analysis
        else {

            return "Nicht erkannt"
        }

        guard
            analysis.documentType !=
                .unknown
        else {

            return "Nicht erkannt"
        }

        return analysis
            .documentType
            .rawValue
    }

    // MARK: - Date

    private var dateText: String {

        guard let date =
            analysis?.detectedDate
        else {

            return "Nicht erkannt"
        }

        let formatter =
            DateFormatter()

        formatter.locale =
            Locale(
                identifier:
                    "de_DE"
            )

        formatter.dateStyle =
            .medium

        return formatter.string(
            from: date
        )
    }

    // MARK: - Keywords

    private var keywordsText: String {

        guard
            let keywords =
                analysis?.keywords,
            !keywords.isEmpty
        else {

            return "Keine"
        }

        return keywords.joined(
            separator: ", "
        )
    }

    // MARK: - Archive Path

    private var archivePathText: String {

        folderSuggestion?
            .displayPath
        ?? "Noch kein Ziel"
    }

    // MARK: - Future Filename

    private var futureFilename: String {

        let cleaned =
            filenameDraft
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            !cleaned.isEmpty
        else {

            return "Noch kein Dateiname"
        }

        if cleaned
            .lowercased()
            .hasSuffix(".pdf") {

            return cleaned
        }

        return "\(cleaned).pdf"
    }

    // MARK: - Confidence

    //
    // Vorerst bleibt Atlas' bisherige
    // Sicherheitsberechnung unverändert.
    //
    // Die visuelle Erkennung wird zunächst
    // nur sichtbar gemacht.
    //
    // Wenn wir echte Dokumente getestet haben,
    // können wir Übereinstimmung bzw. Konflikt
    // gezielt in die Sicherheit einrechnen.
    //

    private var effectiveConfidence: Double {

        folderSuggestion?
            .confidence
        ??
        analysis?
            .confidence
        ??
        0
    }

    private var confidencePercentage: Int {

        Int(
            (
                effectiveConfidence
                * 100
            )
            .rounded()
        )
    }

    private var confidenceTitle: String {

        switch effectiveConfidence {

        case 0.90...:
            return "Sehr hohe Sicherheit"

        case 0.75..<0.90:
            return "Hohe Sicherheit"

        case 0.50..<0.75:
            return "Bitte kurz prüfen"

        default:
            return "Unsichere Zuordnung"
        }
    }

    private var confidenceSubtitle: String {

        if senderSourcesConflict {

            return "Text- und Grafikerkennung erkennen unterschiedliche Absender."
        }

        if senderSourcesAgree {

            return "Text- und Grafikerkennung bestätigen denselben Absender."
        }

        switch effectiveConfidence {

        case 0.90...:
            return "Atlas hält die Zuordnung für sehr zuverlässig."

        case 0.75..<0.90:
            return "Der Vorschlag ist wahrscheinlich richtig."

        case 0.50..<0.75:
            return "Einige Informationen sind noch unsicher."

        default:
            return "Mindestens eine wichtige Information sollte geprüft werden."
        }
    }

    private var confidenceColor: Color {

        if senderSourcesConflict {

            return .orange
        }

        switch effectiveConfidence {

        case 0.90...:
            return .green

        case 0.75..<0.90:
            return .yellow

        case 0.50..<0.75:
            return .orange

        default:
            return .red
        }
    }

    // MARK: - Validation

    private var canArchive: Bool {

        folderSuggestion != nil
        &&
        !filenameDraft
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty
    }

    // MARK: - Normalize Company

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
}

// MARK: - Preview

#Preview {

    AtlasReviewView(
        document:
            DocumentRecord(
                sourceURL:
                    URL(
                        fileURLWithPath:
                            "/tmp/Scan_4711.pdf"
                    )
            ),

        analysis:
            AtlasAnalysis(
                documentType:
                    .deliveryNote,

                detectedDate:
                    Date(),

                sender:
                    "MeyVa",

                recipientArea:
                    .business,

                keywords: [
                    "Schweine",
                    "Lieferung",
                    "Stück"
                ],

                confidence:
                    0.90,

                reasons: []
            ),

        folderSuggestion:
            FolderSuggestion(
                ruleName:
                    "Betrieb Lieferscheine",

                area:
                    .business,

                folder:
                    "Lieferscheine",

                confidence:
                    0.94,

                reasons: []
            ),

        filenameDraft:
            "2026-08-10 Lieferschein MeyVa",

        visualSenderSuggestion:
            "MeyVa",

        visualSenderSimilarity:
            0.941,

        visualSenderConfirmationCount:
            2,

        isArchiving:
            false,

        onArchive: {},

        onEdit: {}
    )
    .frame(
        width: 420,
        height: 760
    )
}
