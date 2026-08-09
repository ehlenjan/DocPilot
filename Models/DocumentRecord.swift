import Foundation

struct DocumentRecord: Identifiable, Hashable {

    let id: UUID
    let sourceURL: URL

    var originalFilename: String
    var suggestedFilename: String
    var documentType: DocumentType
    var area: ArchiveArea?
    var targetFolder: URL?
    var confidence: Double
    var reasons: [String]
    var status: ProcessingStatus

    init(sourceURL: URL) {
        self.id = UUID()
        self.sourceURL = sourceURL
        self.originalFilename =
            sourceURL.lastPathComponent
        self.suggestedFilename =
            sourceURL
                .deletingPathExtension()
                .lastPathComponent
        self.documentType = .unknown
        self.area = nil
        self.targetFolder = nil
        self.confidence = 0
        self.reasons = []
        self.status = .new
    }

    // MARK: - File Information

    var fileSize: Int64? {
        do {
            let values =
                try sourceURL.resourceValues(
                    forKeys: [
                        .fileSizeKey
                    ]
                )

            guard let size =
                values.fileSize
            else {
                return nil
            }

            return Int64(size)

        } catch {
            return nil
        }
    }

    var modificationDate: Date? {
        do {
            let values =
                try sourceURL.resourceValues(
                    forKeys: [
                        .contentModificationDateKey
                    ]
                )

            return values
                .contentModificationDate

        } catch {
            return nil
        }
    }

    var formattedFileSize: String {
        guard let fileSize else {
            return "–"
        }

        return ByteCountFormatter
            .string(
                fromByteCount: fileSize,
                countStyle: .file
            )
    }

    var formattedModificationDate: String {
        guard let modificationDate else {
            return "–"
        }

        return modificationDate.formatted(
            date: .abbreviated,
            time: .omitted
        )
    }
}

enum DocumentType: String, CaseIterable, Codable {
    case invoice = "Rechnung"
    case creditNote = "Gutschrift"
    case deliveryNote = "Lieferschein"
    case slaughterReport = "Schlachtprotokoll"
    case weighingReport = "Wiegeprotokoll"
    case form = "Formular"
    case contract = "Vertrag"
    case letter = "Schreiben"
    case plan = "Plan"
    case unknown = "Unbekannt"
}

enum ArchiveArea: String, CaseIterable, Codable {
    case business = "Betrieb"
    case ehaKG = "EHA KG"
    case privateArea = "Jan Ehlen"
    case fireDepartment = "Feuerwehr"
}

enum ProcessingStatus: String, Codable {
    case new = "Neu"
    case reviewed = "Geprüft"
    case completed = "Abgelegt"
    case skipped = "Übersprungen"
}
