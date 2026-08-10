import Foundation
import Observation

@Observable
final class VisualSenderLearningManager {

    private let store:
        VisualSenderLearningStore

    private(set) var entries:
        [VisualSenderLearningEntry]

    // Startwert.
    //
    // Den kalibrieren wir später mit echten
    // Dokumenten, falls nötig.
    private let minimumSimilarity:
        Double = 0.90

    init(
        store: VisualSenderLearningStore =
            VisualSenderLearningStore()
    ) {
        self.store =
            store

        self.entries =
            store.load()
    }

    // MARK: - Confirm

    func confirm(
        company: String,
        signature: VisualFeatureSignature
    ) {

        let cleanedCompany =
            company.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard
            !cleanedCompany.isEmpty
        else {
            return
        }

        // Zuerst nach einem bereits bekannten
        // ähnlichen Logo/Kopfbereich suchen.
        if let match =
            bestMatch(
                for:
                    signature
            ),
           match.similarity >=
                minimumSimilarity {

            let existingEntry =
                entries[
                    match.index
                ]

            if sameCompany(
                existingEntry.company,
                cleanedCompany
            ) {

                // Dasselbe visuelle Muster wurde
                // erneut derselben Firma bestätigt.
                entries[
                    match.index
                ]
                .confirm()

                save()

                return
            }

            // Dasselbe bzw. sehr ähnliche visuelle
            // Muster wurde für eine andere Firma
            // bestätigt.
            //
            // Alte Zuordnung verwerfen und
            // Vertrauen neu aufbauen.
            entries.remove(
                at:
                    match.index
            )
        }

        let newEntry =
            VisualSenderLearningEntry(
                company:
                    cleanedCompany,
                signature:
                    signature
            )

        entries.append(
            newEntry
        )

        save()
    }

    // MARK: - Match

    func match(
        signature: VisualFeatureSignature
    ) -> VisualSenderLearningEntry? {

        guard
            let match =
                bestMatch(
                    for:
                        signature
                ),
            match.similarity >=
                minimumSimilarity
        else {
            return nil
        }

        return entries[
            match.index
        ]
    }

    // MARK: - Match Information

    func matchInformation(
        for signature:
            VisualFeatureSignature
    ) -> (
        entry: VisualSenderLearningEntry,
        similarity: Double
    )? {

        guard
            let match =
                bestMatch(
                    for:
                        signature
                ),
            match.similarity >=
                minimumSimilarity
        else {
            return nil
        }

        return (
            entry:
                entries[
                    match.index
                ],
            similarity:
                match.similarity
        )
    }

    // MARK: - Automatic Sender

    func automaticSender(
        for signature:
            VisualFeatureSignature
    ) -> String? {

        guard
            let entry =
                match(
                    signature:
                        signature
                ),
            entry.canUseAutomatically
        else {
            return nil
        }

        return entry.company
    }

    // MARK: - Confirmation Count

    func confirmationCount(
        for signature:
            VisualFeatureSignature
    ) -> Int {

        match(
            signature:
                signature
        )?
        .confirmationCount
        ?? 0
    }

    // MARK: - Needs Confirmation

    func needsConfirmation(
        for signature:
            VisualFeatureSignature
    ) -> Bool {

        guard
            let entry =
                match(
                    signature:
                        signature
                )
        else {

            // Noch völlig unbekannt.
            return true
        }

        // Erst nach drei Bestätigungen
        // darf Atlas ohne Rückfrage arbeiten.
        return
            !entry.canUseAutomatically
    }

    // MARK: - Remove

    func remove(
        _ entry:
            VisualSenderLearningEntry
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

        store.clear()
    }

    // MARK: - Reload

    func reload() {

        entries =
            store.load()
    }

    // MARK: - Best Match

    private struct MatchResult {

        let index: Int
        let similarity: Double
    }

    private func bestMatch(
        for signature:
            VisualFeatureSignature
    ) -> MatchResult? {

        var best:
            MatchResult?

        for index in
            entries.indices {

            guard
                let similarity =
                    entries[index]
                        .signature
                        .similarity(
                            to:
                                signature
                        )
            else {
                continue
            }

            if best == nil ||
                similarity >
                    best!.similarity {

                best =
                    MatchResult(
                        index:
                            index,
                        similarity:
                            similarity
                    )
            }
        }

        return best
    }

    // MARK: - Company Comparison

    private func sameCompany(
        _ first: String,
        _ second: String
    ) -> Bool {

        normalize(first) ==
            normalize(second)
    }

    private func normalize(
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

    // MARK: - Save

    private func save() {

        store.save(
            entries
        )
    }
}
