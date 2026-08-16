import SwiftUI

struct LearningSettingsView: View {

    @Bindable var settingsManager: SettingsManager

    @State private var learningManager =
        LearningManager()

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

            Section(
                "Gelernte Zuordnungen"
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
                        learningManager.entries
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
