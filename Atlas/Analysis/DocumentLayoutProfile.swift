import Foundation
import CoreGraphics

// MARK: - Document Layout Profile

struct DocumentLayoutProfile:
    Identifiable {

    let id:
        String

    /// Firma, für deren Dokumente
    /// dieses Layout gilt.
    let company:
        String

    /// Dokumentart, für die
    /// dieses Layout gilt.
    let documentType:
        DocumentType

    /// Lesbarer Name des Layouts.
    let name:
        String

    /// Typische Begriffe, anhand derer
    /// dieses konkrete Layout erkannt wird.
    let anchorKeywords:
        [String]

    /// Bereich des Dokumentdatums.
    let dateRegion:
        CGRect?

    /// Bereich, in dem Atlas die Identität
    /// des eigenen Archivbereichs suchen soll.
    ///
    /// Das kann je nach Dokument z. B.
    /// Empfänger, Lieferant oder Antragsteller sein.
    let archiveIdentityRegion:
        CGRect?

    // MARK: - Init

    init(
        id: String,
        company: String,
        documentType: DocumentType,
        name: String,
        anchorKeywords: [String] = [],
        dateRegion: CGRect? = nil,
        archiveIdentityRegion: CGRect? = nil
    ) {

        self.id =
            id

        self.company =
            company

        self.documentType =
            documentType

        self.name =
            name

        self.anchorKeywords =
            anchorKeywords

        self.dateRegion =
            dateRegion

        self.archiveIdentityRegion =
            archiveIdentityRegion
    }
}

// MARK: - Known Layouts

extension DocumentLayoutProfile {

    static let known:
        [DocumentLayoutProfile] = [

            // MARK: MBR Schlachtschweine

            DocumentLayoutProfile(
                id:
                    "mbr-delivery-note-pigs-01",

                company:
                    "MBR",

                documentType:
                    .deliveryNote,

                name:
                    "MBR Lieferschein Schlachtschweine",

                anchorKeywords: [
                    "betriebsidentifikation",
                    "angaben zu den tieren",
                    "standarderklärung",
                    "lebensmittelketteninformation",
                    "tätowiernr"
                ],

                dateRegion:
                    CGRect(
                        x: 0.52,
                        y: 0.82,
                        width: 0.45,
                        height: 0.075
                    ),

                // Beim Schlachtschweine-Lieferschein
                // steht unser Betrieb im Lieferantenfeld.
                archiveIdentityRegion:
                    CGRect(
                        x: 0.10,
                        y: 0.68,
                        width: 0.55,
                        height: 0.10
                    )
            ),

            // MARK: MBR Ferkel

            DocumentLayoutProfile(
                id:
                    "mbr-delivery-note-piglets-01",

                company:
                    "MBR",

                documentType:
                    .deliveryNote,

                name:
                    "MBR Lieferschein Ferkel",

                anchorKeywords: [
                    "ferkel",
                    "ferkelerzeuger",
                    "stück ferkel",
                    "ohrmarke",
                    "impfmaßnahmen"
                ],

                dateRegion:
                    CGRect(
                        x: 0.64,
                        y: 0.61,
                        width: 0.33,
                        height: 0.10
                    ),

                // Beim Ferkel-Lieferschein
                // steht unser Betrieb im Empfängerfeld.
                archiveIdentityRegion:
                    CGRect(
                        x: 0.07,
                        y: 0.56,
                        width: 0.58,
                        height: 0.16
                    )
            )
        ]
}

// MARK: - Matching Company + Document Type

extension DocumentLayoutProfile {

    static func matching(
        company: String,
        documentType: DocumentType
    ) -> [DocumentLayoutProfile] {

        known.filter {
            profile in

            normalize(
                profile.company
            )
            ==
            normalize(
                company
            )
            &&
            profile.documentType ==
                documentType
        }
    }
}

// MARK: - Best Matching Layout

extension DocumentLayoutProfile {

    static func bestMatching(
        company: String,
        documentType: DocumentType,
        documentText: String
    ) -> DocumentLayoutProfile? {

        let candidates =
            matching(
                company:
                    company,
                documentType:
                    documentType
            )

        guard
            !candidates.isEmpty
        else {

            return nil
        }

        let normalizedText =
            normalize(
                documentText
            )

        let scored =
            candidates.map {
                profile in

                let matches =
                    profile
                        .anchorKeywords
                        .filter {
                            keyword in

                            normalizedText
                                .contains(
                                    normalize(
                                        keyword
                                    )
                                )
                        }

                return (
                    profile:
                        profile,
                    score:
                        matches.count
                )
            }

        guard
            let best =
                scored.max(
                    by: {
                        $0.score <
                            $1.score
                    }
                )
        else {

            return nil
        }

        // Bei mehreren Layouts wollen wir
        // nicht einfach raten.
        //
        // Mindestens ein Layout-Merkmal
        // muss gefunden worden sein.
        guard
            best.score > 0
        else {

            return nil
        }

        return best.profile
    }
}

// MARK: - Normalize

private extension DocumentLayoutProfile {

    static func normalize(
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
