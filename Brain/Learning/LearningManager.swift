import Foundation
import Observation

@Observable
final class LearningManager {

    private let store: LearningStore

    private(set) var entries: [LearningEntry]

    init(
        store: LearningStore = LearningStore()
    ) {
        self.store = store
        self.entries = store.load()

        removeExistingDuplicates()
    }

    func add(
        _ entry: LearningEntry
    ) {

        if let index = entries.firstIndex(
            where: {
                equivalent($0, entry)
            }
        ) {

            entries[index].registerUse()
            save()
            return

        }

        entries.append(entry)
        save()
    }

    func remove(
        _ entry: LearningEntry
    ) {
        entries.removeAll {
            $0.id == entry.id
        }

        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    func reload() {
        entries = store.load()
        removeExistingDuplicates()
    }

    private func removeExistingDuplicates() {

        var uniqueEntries: [LearningEntry] = []

        for entry in entries {

            if let existingIndex = uniqueEntries.firstIndex(
                where: {
                    equivalent($0, entry)
                }
            ) {

                if entry.usageCount >
                    uniqueEntries[existingIndex].usageCount {

                    uniqueEntries[existingIndex] = entry

                }

            } else {

                uniqueEntries.append(entry)

            }

        }

        guard uniqueEntries.count != entries.count else {
            return
        }

        entries = uniqueEntries
        save()
    }

    private func equivalent(
        _ first: LearningEntry,
        _ second: LearningEntry
    ) -> Bool {

        let companiesMatch =
            normalized(first.company) ==
            normalized(second.company)

        let foldersMatch =
            normalized(first.folder) ==
            normalized(second.folder)

        let keywordsMatch =
            normalizedKeywords(first.keywords) ==
            normalizedKeywords(second.keywords)

        return companiesMatch
            && first.documentType == second.documentType
            && first.archiveArea == second.archiveArea
            && foldersMatch
            && keywordsMatch

    }

    private func normalized(
        _ value: String?
    ) -> String {

        guard let value else {
            return ""
        }

        return value
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive
                ],
                locale: Locale(identifier: "de_DE")
            )

    }

    private func normalizedKeywords(
        _ keywords: [String]
    ) -> Set<String> {

        Set(
            keywords.map {
                normalized($0)
            }
        )

    }

    private func save() {
        store.save(entries)
    }
}
