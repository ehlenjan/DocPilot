import Foundation

struct LearningEntry:
    Codable,
    Identifiable,
    Equatable {

    let id:
        UUID

    var company:
        String?

    var documentType:
        DocumentType

    var keywords:
        [String]

    /// Charakteristische Textmerkmale des
    /// ursprünglichen Dokuments.
    ///
    /// Damit kann Atlas ähnliche Dokumente
    /// später auch dann wiedererkennen,
    /// wenn Absender oder Dokumentart beim
    /// neuen Dokument zunächst nicht erkannt werden.
    var documentSignals:
        [String]

    var archiveArea:
        ArchiveArea

    var folder:
        String

    var createdAt:
        Date

    var lastUsedAt:
        Date

    var usageCount:
        Int

    // MARK: - Init

    init(
        id: UUID = UUID(),
        company: String?,
        documentType: DocumentType,
        keywords: [String],
        documentSignals: [String] = [],
        archiveArea: ArchiveArea,
        folder: String,
        createdAt: Date = Date(),
        lastUsedAt: Date = Date(),
        usageCount: Int = 1
    ) {

        self.id =
            id

        self.company =
            company

        self.documentType =
            documentType

        self.keywords =
            keywords

        self.documentSignals =
            documentSignals

        self.archiveArea =
            archiveArea

        self.folder =
            folder

        self.createdAt =
            createdAt

        self.lastUsedAt =
            lastUsedAt

        self.usageCount =
            usageCount
    }

    // MARK: - Register Use

    mutating func registerUse() {

        usageCount += 1

        lastUsedAt =
            Date()
    }

    // MARK: - Codable Compatibility

    enum CodingKeys:
        String,
        CodingKey {

        case id
        case company
        case documentType
        case keywords
        case documentSignals
        case archiveArea
        case folder
        case createdAt
        case lastUsedAt
        case usageCount
    }

    init(
        from decoder:
            Decoder
    ) throws {

        let container =
            try decoder.container(
                keyedBy:
                    CodingKeys.self
            )

        id =
            try container.decode(
                UUID.self,
                forKey:
                    .id
            )

        company =
            try container.decodeIfPresent(
                String.self,
                forKey:
                    .company
            )

        documentType =
            try container.decode(
                DocumentType.self,
                forKey:
                    .documentType
            )

        keywords =
            try container.decodeIfPresent(
                [String].self,
                forKey:
                    .keywords
            )
            ?? []

        // Alte Atlas-Lerndaten besitzen dieses
        // Feld noch nicht.
        documentSignals =
            try container.decodeIfPresent(
                [String].self,
                forKey:
                    .documentSignals
            )
            ?? []

        archiveArea =
            try container.decode(
                ArchiveArea.self,
                forKey:
                    .archiveArea
            )

        folder =
            try container.decode(
                String.self,
                forKey:
                    .folder
            )

        createdAt =
            try container.decodeIfPresent(
                Date.self,
                forKey:
                    .createdAt
            )
            ?? Date()

        lastUsedAt =
            try container.decodeIfPresent(
                Date.self,
                forKey:
                    .lastUsedAt
            )
            ?? createdAt

        usageCount =
            try container.decodeIfPresent(
                Int.self,
                forKey:
                    .usageCount
            )
            ?? 1
    }
}
