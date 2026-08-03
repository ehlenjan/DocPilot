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
    }

    func add(
        _ entry: LearningEntry
    ) {
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
    }

    private func save() {
        store.save(entries)
    }
}
