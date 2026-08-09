import SwiftUI

struct AtlasRecommendationCard: View {

    let analysis: AtlasAnalysis?
    let folderSuggestion: FolderSuggestion?

    var body: some View {
        AtlasCard {
            VStack(
                alignment: .leading,
                spacing: 16
            ) {

                header

                if let analysis {
                    recommendationContent(
                        for: analysis
                    )
                } else {
                    emptyState
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {

            Image(
                systemName:
                    "brain.head.profile"
            )
            .font(.title2)

            VStack(
                alignment: .leading,
                spacing: 2
            ) {

                Text("Atlas")
                    .font(.headline)

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
            }

            Spacer()

            Circle()
                .fill(statusColor)
                .frame(
                    width: 10,
                    height: 10
                )
        }
    }

    // MARK: - Recommendation

    private func recommendationContent(
        for analysis: AtlasAnalysis
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 16
        ) {

            if let folderSuggestion {

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {

                    Text(
                        "Ich würde dieses Dokument nach"
                    )
                    .font(.callout)
                    .foregroundStyle(
                        .secondary
                    )

                    Label(
                        folderSuggestion
                            .displayPath,
                        systemImage:
                            "folder.fill"
                    )
                    .font(
                        .title3.bold()
                    )

                    Text("ablegen.")
                        .font(.callout)
                        .foregroundStyle(
                            .secondary
                        )
                }

            } else {

                Text(
                    "Ich habe noch keinen eindeutigen Zielordner gefunden."
                )
                .font(.title3)
            }

            confidenceSection

            if !decisionBadges.isEmpty {

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {

                    ForEach(
                        decisionBadges,
                        id: \.title
                    ) { badge in

                        decisionBadge(
                            icon:
                                badge.icon,
                            title:
                                badge.title,
                            text:
                                badge.text
                        )
                    }
                }
            }

            Divider()

            VStack(
                alignment: .leading,
                spacing: 9
            ) {

                Text("Ich habe erkannt")
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                if analysis.documentType !=
                    .unknown {

                    factRow(
                        icon:
                            "doc.text",
                        text:
                            analysis
                                .documentType
                                .rawValue
                    )
                }

                if let sender =
                    analysis.sender {

                    factRow(
                        icon:
                            "building.2",
                        text:
                            "Absender: \(sender)"
                    )
                }

                if let recipientArea =
                    analysis.recipientArea {

                    factRow(
                        icon:
                            "person.crop.circle.badge.checkmark",
                        text:
                            "Empfänger: \(recipientArea.rawValue)"
                    )
                }

                if !analysis
                    .keywords
                    .isEmpty {

                    factRow(
                        icon:
                            "tag",
                        text:
                            "\(analysis.keywords.count) Schlüsselwörter"
                    )
                }

            }
        }
    }

    // MARK: - Confidence

    private var confidenceSection:
        some View {

        HStack(spacing: 10) {

            Circle()
                .fill(statusColor)
                .frame(
                    width: 11,
                    height: 11
                )

            VStack(
                alignment: .leading,
                spacing: 2
            ) {

                Text(confidenceTitle)
                    .font(.headline)

                Text(
                    confidenceSubtitle
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            Text(
                "\(confidencePercentage) %"
            )
            .font(.title3.bold())
        }
    }

    // MARK: - Decision Badges

    private struct DecisionBadge:
        Hashable {

        let icon: String
        let title: String
        let text: String
    }

    private var decisionBadges:
        [DecisionBadge] {

        var badges:
            [DecisionBadge] = []

        if let recipientArea =
            analysis?.recipientArea {

            badges.append(
                DecisionBadge(
                    icon:
                        "person.crop.circle.badge.checkmark",
                    title:
                        "Empfänger erkannt",
                    text:
                        "Dieses Dokument wurde \(recipientArea.rawValue) zugeordnet."
                )
            )
        }

        if hasLearnedSuggestion {

            let confirmationText:
                String

            if let usageCount =
                learnedUsageCount,
               usageCount > 1 {

                confirmationText =
                    "Dieses Ziel wurde bereits \(usageCount)× aus deinen Korrekturen bestätigt."

            } else {

                confirmationText =
                    "Atlas berücksichtigt eine frühere manuelle Korrektur."
            }

            badges.append(
                DecisionBadge(
                    icon:
                        "brain.head.profile",
                    title:
                        "Aus deinen Korrekturen gelernt",
                    text:
                        confirmationText
                )
            )
        }

        if learningConfirmsRule {

            badges.append(
                DecisionBadge(
                    icon:
                        "checkmark.seal",
                    title:
                        "Regel und Lernen stimmen überein",
                    text:
                        "Der feste Regelvorschlag und deine bisherigen Korrekturen zeigen auf dasselbe Ziel."
                )
            )
        }

        return badges
    }

    private func decisionBadge(
        icon: String,
        title: String,
        text: String
    ) -> some View {

        HStack(
            alignment: .top,
            spacing: 10
        ) {

            Image(
                systemName: icon
            )
            .frame(width: 18)

            VStack(
                alignment: .leading,
                spacing: 2
            ) {

                Text(title)
                    .font(
                        .callout.bold()
                    )

                Text(text)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
            }

            Spacer()
        }
        .padding(10)
        .background {
            RoundedRectangle(
                cornerRadius: 8
            )
            .fill(
                Color.secondary
                    .opacity(0.08)
            )
        }
    }

    // MARK: - Empty State

    private var emptyState:
        some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            Text(
                "Noch keine Empfehlung"
            )
            .font(.title3.bold())

            Text(
                "Atlas analysiert das Dokument und schlägt anschließend einen Dateinamen und Zielordner vor."
            )
            .foregroundStyle(
                .secondary
            )
        }
    }

    // MARK: - Facts

    private func factRow(
        icon: String,
        text: String
    ) -> some View {

        Label(
            text,
            systemImage: icon
        )
        .font(.callout)
    }

    // MARK: - Confidence Helpers

    private var effectiveConfidence:
        Double {

        folderSuggestion?
            .confidence
        ??
        analysis?
            .confidence
        ??
        0
    }

    private var confidencePercentage:
        Int {

        Int(
            (
                effectiveConfidence
                * 100
            )
            .rounded()
        )
    }

    private var confidenceTitle:
        String {

        switch effectiveConfidence {

        case 0.90...:
            return
                "Sehr hohe Sicherheit"

        case 0.75..<0.90:
            return
                "Hohe Sicherheit"

        case 0.50..<0.75:
            return
                "Bitte kurz prüfen"

        default:
            return
                "Unsichere Zuordnung"
        }
    }

    private var confidenceSubtitle:
        String {

        switch effectiveConfidence {

        case 0.90...:
            return
                "Mehrere eindeutige Merkmale stimmen überein."

        case 0.75..<0.90:
            return
                "Der Vorschlag ist wahrscheinlich richtig."

        case 0.50..<0.75:
            return
                "Einige Merkmale passen, andere sind noch unklar."

        default:
            return
                "Atlas benötigt deine Unterstützung."
        }
    }

    private var statusText:
        String {

        analysis == nil
        ? "Bereit zur Analyse"
        : confidenceTitle
    }

    private var statusColor:
        Color {

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

    // MARK: - Learning Helpers

    

    private var hasLearnedSuggestion:
        Bool {

        guard let folderSuggestion
        else {
            return false
        }

        if folderSuggestion.ruleName
            .localizedCaseInsensitiveContains(
                "gelernt"
            ) {

            return true
        }

        return folderSuggestion
            .reasons
            .contains {
                reason in

                let normalized =
                    reason.lowercased()

                return
                    normalized.contains(
                        "ähnliche dokumente"
                    )
                    ||
                    normalized.contains(
                        "gelernte zuordnung"
                    )
                    ||
                    normalized.contains(
                        "bereits"
                    )
                    &&
                    normalized.contains(
                        "bestätigt"
                    )
            }
    }

    private var learningConfirmsRule:
        Bool {

        guard let folderSuggestion
        else {
            return false
        }

        return folderSuggestion
            .reasons
            .contains {
                $0.lowercased()
                    .contains(
                        "gelernte zuordnung bestätigt den regelvorschlag"
                    )
            }
    }

    private var learnedUsageCount:
        Int? {

        guard let folderSuggestion
        else {
            return nil
        }

        for reason in
            folderSuggestion.reasons {

            let normalized =
                reason.lowercased()

            guard
                normalized.contains(
                    "bereits"
                ),
                normalized.contains(
                    "bestätigt"
                )
            else {
                continue
            }

            let digits =
                reason.filter {
                    $0.isNumber
                }

            if let value =
                Int(digits),
               value > 0 {

                return value
            }
        }

        return nil
    }
}

#Preview {

    AtlasRecommendationCard(
        analysis:
            AtlasAnalysis(
                documentType:
                    .invoice,
                detectedDate:
                    Date(),
                sender:
                    "RWG",
                recipientArea:
                    .business,
                keywords: [
                    "Rechnung",
                    "Saatgut",
                    "Pflanzenschutz",
                    "Acker"
                ],
                confidence:
                    0.95,
                reasons: []
            ),
        folderSuggestion:
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
                    "Atlas hat ähnliche Dokumente gefunden (105 Punkte)",
                    "Dieses Ziel wurde bereits 3× bestätigt",
                    "Gelernte Zuordnung bestätigt den Regelvorschlag"
                ]
            )
    )
    .padding()
    .frame(
        width: 390
    )
}
