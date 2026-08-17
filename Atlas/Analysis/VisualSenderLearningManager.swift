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
        signature: VisualFeatureSignature,
        previewPNGData: Data? = nil
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

                if let previewPNGData,
                   let filename =
                    store.savePreview(
                        pngData:
                            previewPNGData,
                        for:
                            entries[
                                match.index
                            ]
                            .id
                    ) {

                    entries[
                        match.index
                    ]
                    .previewFilename =
                        filename
                }

                save()

                return
            }

            // Dasselbe bzw. sehr ähnliche visuelle
            // Muster wurde für eine andere Firma
            // bestätigt.
            //
            // Alte Zuordnung verwerfen und
            // Vertrauen neu aufbauen.
            store.removePreview(
                filename:
                    entries[
                        match.index
                    ]
                    .previewFilename
            )

            entries.remove(
                at:
                    match.index
            )
        }

        var newEntry =
            VisualSenderLearningEntry(
                company:
                    cleanedCompany,
                signature:
                    signature
            )

        if let previewPNGData,
           let filename =
            store.savePreview(
                pngData:
                    previewPNGData,
                for:
                    newEntry.id
            ) {

            newEntry.previewFilename =
                filename
        }

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

        store.removePreview(
            filename:
                entry.previewFilename
        )

        entries.removeAll {
            $0.id ==
                entry.id
        }

        save()
    }

    // MARK: - Reassign

    /// Ordnet eine bereits gelernte visuelle Signatur
    /// einer anderen Firma zu.
    ///
    /// Signatur und Bestätigungszahl bleiben erhalten.
    @discardableResult
    func reassign(
        _ entry:
            VisualSenderLearningEntry,
        to company:
            String
    ) -> Bool {

        let cleanedCompany =
            company.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard
            !cleanedCompany.isEmpty,
            let index =
                entries.firstIndex(
                    where: {
                        $0.id ==
                            entry.id
                    }
                )
        else {

            return false
        }

        let currentEntry =
            entries[index]

        let reassignedEntry =
            VisualSenderLearningEntry(
                id:
                    currentEntry.id,
                company:
                    cleanedCompany,
                signature:
                    currentEntry.signature,
                previewFilename:
                    currentEntry.previewFilename,
                createdAt:
                    currentEntry.createdAt,
                lastConfirmedAt:
                    currentEntry.lastConfirmedAt,
                confirmationCount:
                    currentEntry.confirmationCount
            )

        entries[index] =
            reassignedEntry

        save()

        return true
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
