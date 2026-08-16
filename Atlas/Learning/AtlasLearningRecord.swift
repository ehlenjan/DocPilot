import Foundation

// MARK: - Atlas Learning Record

struct AtlasLearningRecord:
    Codable,
    Identifiable {

    let id:
        UUID

    let createdAt:
        Date

    // MARK: - Document

    /// Ursprünglicher Dateiname.
    /// Wir speichern bewusst nicht den kompletten
    /// Dokumentinhalt.
    let filename:
        String

    // MARK: - Sender

    /// Ursprünglicher Atlas-Vorschlag.
    let suggestedSender:
        String?

    /// Beim Archivieren tatsächlich
    /// verwendeter Absender.
    let finalSender:
        String?

    // MARK: - Recipient

    /// Ursprünglicher Atlas-Vorschlag.
    let suggestedRecipient:
        String?

    /// Beim Archivieren tatsächlich
    /// verwendeter Empfänger.
    let finalRecipient:
        String?

    // MARK: - Document Type

    /// Ursprünglicher Atlas-Vorschlag.
    let suggestedDocumentType:
        String

    /// Beim Archivieren tatsächlich
    /// verwendete Dokumentart.
    let finalDocumentType:
        String

    // MARK: - Date

    /// Ursprünglich von Atlas erkanntes Datum.
    let suggestedDate:
        Date?

    /// Beim Archivieren tatsächlich
    /// verwendetes Datum.
    let finalDate:
        Date?

    // MARK: - Archive Destination

    /// Von Atlas vorgeschlagener Archivbereich.
    let suggestedArchiveArea:
        String?

    /// Tatsächlich verwendeter Archivbereich.
    let finalArchiveArea:
        String?

    /// Von Atlas vorgeschlagener relativer Ordner.
    let suggestedFolder:
        String?

    /// Tatsächlich verwendeter relativer Ordner.
    let finalFolder:
        String?

    /// Wurde das Archivziel vom Benutzer
    /// manuell gewählt?
    let archiveDestinationWasManual:
        Bool

    // MARK: - Comparison

    var senderWasCorrected:
        Bool {

        normalized(
            suggestedSender
        ) !=
        normalized(
            finalSender
        )
    }

    var recipientWasCorrected:
        Bool {

        normalized(
            suggestedRecipient
        ) !=
        normalized(
            finalRecipient
        )
    }

    var documentTypeWasCorrected:
        Bool {

        suggestedDocumentType !=
            finalDocumentType
    }

    var dateWasCorrected:
        Bool {

        suggestedDate !=
            finalDate
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        filename: String,
        suggestedSender: String?,
        finalSender: String?,
        suggestedRecipient: String?,
        finalRecipient: String?,
        suggestedDocumentType: String,
        finalDocumentType: String,
        suggestedDate: Date?,
        finalDate: Date?,
        suggestedArchiveArea: String?,
        finalArchiveArea: String?,
        suggestedFolder: String?,
        finalFolder: String?,
        archiveDestinationWasManual: Bool
    ) {

        self.id =
            id

        self.createdAt =
            createdAt

        self.filename =
            filename

        self.suggestedSender =
            suggestedSender

        self.finalSender =
            finalSender

        self.suggestedRecipient =
            suggestedRecipient

        self.finalRecipient =
            finalRecipient

        self.suggestedDocumentType =
            suggestedDocumentType

        self.finalDocumentType =
            finalDocumentType

        self.suggestedDate =
            suggestedDate

        self.finalDate =
            finalDate

        self.suggestedArchiveArea =
            suggestedArchiveArea

        self.finalArchiveArea =
            finalArchiveArea

        self.suggestedFolder =
            suggestedFolder

        self.finalFolder =
            finalFolder

        self.archiveDestinationWasManual =
            archiveDestinationWasManual
    }

    // MARK: - Normalize

    private func normalized(
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
}
