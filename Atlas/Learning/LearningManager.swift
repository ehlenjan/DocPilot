import Foundation
import Observation

@Observable
final class LearningManager {

    private let store:
        LearningStore

    private(set) var entries:
        [LearningEntry]

    init(
        store: LearningStore =
            LearningStore()
    ) {

        self.store =
            store

        self.entries =
            store.load()

        mergeExistingEntries()
    }

    // MARK: - Add

    func add(
        _ entry: LearningEntry
    ) {

        if let index =
            entries.firstIndex(
                where: {

                    equivalent(
                        $0,
                        entry
                    )
                }
            ) {

            // Bestehende Zuordnung wurde
            // erneut bestätigt.
            entries[index]
                .registerUse()

            save()

            return
        }

        entries.append(
            entry
        )

        save()
    }

    // MARK: - Remove

    func remove(
        _ entry: LearningEntry
    ) {

        entries.removeAll {

            $0.id ==
                entry.id
        }

        save()
    }

    // MARK: - Clear

    func clear() {

        entries.removeAll()

        save()
    }

    // MARK: - Reload

    func reload() {

        entries =
            store.load()

        mergeExistingEntries()
    }

    // MARK: - Remove Invalid Entries

    /// Entfernt dauerhaft Lernzuordnungen,
    /// deren Zielordner in der aktuellen
    /// Archivstruktur nicht mehr existiert.
    ///
    /// Beispiele:
    ///
    /// Betrieb → Lieferscheine
    /// EHA KG → Finanzen/Belege
    ///
    /// Wenn diese Ziele nicht mehr in
    /// `KnowledgeBase.archiveFolders`
    /// vorhanden sind, werden die Einträge
    /// aus dem LearningStore entfernt.
    @discardableResult
    func removeInvalidEntries(
        validFolders: [ArchiveFolder]
    ) -> Int {

        let oldCount =
            entries.count

        entries.removeAll {
            entry in

            !isValid(
                entry:
                    entry,
                validFolders:
                    validFolders
            )
        }

        let removedCount =
            oldCount -
            entries.count

        guard
            removedCount > 0
        else {

            return 0
        }

        save()

        print(
            "🧹 Atlas hat \(removedCount) veraltete Lernzuordnung(en) entfernt."
        )

        return removedCount
    }

    // MARK: - Validate Entry

    private func isValid(
        entry: LearningEntry,
        validFolders: [ArchiveFolder]
    ) -> Bool {

        validFolders.contains {
            archiveFolder in

            archiveFolder.area ==
                entry.archiveArea
            &&
            sameFolder(
                archiveFolder.name,
                entry.folder
            )
        }
    }

    // MARK: - Folder Comparison

    private func sameFolder(
        _ first: String,
        _ second: String
    ) -> Bool {

        normalized(
            first
        ) ==
        normalized(
            second
        )
    }

    // MARK: - Merge Existing Entries

    private func mergeExistingEntries() {

        var mergedEntries:
            [LearningEntry] = []

        for entry in entries {

            if let existingIndex =
                mergedEntries
                    .firstIndex(
                        where: {

                            equivalent(
                                $0,
                                entry
                            )
                        }
                    ) {

                var existingEntry =
                    mergedEntries[
                        existingIndex
                    ]

                // Bereits vorhandene,
                // gleichartige Erfahrungen
                // zusammenfassen.
                let combinedUsageCount =
                    existingEntry
                        .usageCount
                    +
                    entry
                        .usageCount

                let newestLastUsedAt =
                    max(
                        existingEntry
                            .lastUsedAt,
                        entry
                            .lastUsedAt
                    )

                let oldestCreatedAt =
                    min(
                        existingEntry
                            .createdAt,
                        entry
                            .createdAt
                    )

                // Keywords aus beiden
                // Einträgen zusammenführen.
                let combinedKeywords =
                    mergedKeywords(
                        existingEntry
                            .keywords,
                        entry
                            .keywords
                    )

                existingEntry =
                    LearningEntry(
                        company:
                            existingEntry
                                .company
                            ??
                            entry
                                .company,
                        documentType:
                            existingEntry
                                .documentType,
                        keywords:
                            combinedKeywords,
                        archiveArea:
                            existingEntry
                                .archiveArea,
                        folder:
                            existingEntry
                                .folder,
                        createdAt:
                            oldestCreatedAt,
                        lastUsedAt:
                            newestLastUsedAt,
                        usageCount:
                            combinedUsageCount
                    )

                mergedEntries[
                    existingIndex
                ] =
                    existingEntry

            } else {

                mergedEntries.append(
                    entry
                )
            }
        }

        guard
            mergedEntries.count !=
                entries.count
        else {

            return
        }

        entries =
            mergedEntries

        save()
    }

    // MARK: - Equivalence

    private func equivalent(
        _ first: LearningEntry,
        _ second: LearningEntry
    ) -> Bool {

        let companiesMatch =
            normalized(
                first.company
            ) ==
            normalized(
                second.company
            )

        let foldersMatch =
            normalized(
                first.folder
            ) ==
            normalized(
                second.folder
            )

        return
            companiesMatch
            &&
            first.documentType ==
                second.documentType
            &&
            first.archiveArea ==
                second.archiveArea
            &&
            foldersMatch
    }

    // MARK: - Keywords

    private func mergedKeywords(
        _ first: [String],
        _ second: [String]
    ) -> [String] {

        var result:
            [String] = []

        var seen:
            Set<String> = []

        for keyword in
            first + second {

            let normalizedKeyword =
                normalized(
                    keyword
                )

            guard
                !normalizedKeyword
                    .isEmpty,
                !seen.contains(
                    normalizedKeyword
                )
            else {

                continue
            }

            seen.insert(
                normalizedKeyword
            )

            result.append(
                keyword
            )
        }

        return result
    }

    // MARK: - Normalize

    private func normalized(
        _ value: String?
    ) -> String {

        guard let value
        else {

            return ""
        }

        return value
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

    // MARK: - Save

    private func save() {

        store.save(
            entries
        )
    }
}
