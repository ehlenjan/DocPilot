import Foundation

struct KnowledgeBase: Decodable {

    let companies: [CompanyRule]
    let documentTypes: [DocumentTypeRule]
    let folderRules: [FolderRule]
    
    var archiveFolders: [ArchiveFolder] {
        let folders = folderRules.compactMap { rule -> ArchiveFolder? in
            guard let area = rule.archiveArea else {
                return nil
            }

            return ArchiveFolder(
                area: area,
                name: rule.folder
            )
        }

        return Array(Set(folders)).sorted {
            if $0.area.rawValue == $1.area.rawValue {
                return $0.name.localizedStandardCompare(
                    $1.name
                ) == .orderedAscending
            }

            return $0.area.rawValue.localizedStandardCompare(
                $1.area.rawValue
            ) == .orderedAscending
        }
    }

    static func load() throws -> KnowledgeBase {
        guard let url = Bundle.main.url(
            forResource: "knowledge",
            withExtension: "json"
        ) else {
            throw KnowledgeBaseError.fileNotFound
        }

        do {
            let data = try Data(contentsOf: url)

            let decoder = JSONDecoder()

            return try decoder.decode(
                KnowledgeBase.self,
                from: data
            )
        } catch let decodingError as DecodingError {
            throw KnowledgeBaseError.decodingFailed(
                decodingError
            )
        } catch {
            throw KnowledgeBaseError.readingFailed(
                error.localizedDescription
            )
        }
    }
}

struct CompanyRule: Decodable, Identifiable {

    let name: String
    let keywords: [String]

    var id: String {
        name
    }
}

struct DocumentTypeRule: Decodable, Identifiable {

    let type: String
    let displayName: String
    let keywords: [String]

    var id: String {
        type
    }

    var documentType: DocumentType {
        switch type {

        case "invoice":
            return .invoice

        case "creditNote":
            return .creditNote

        case "deliveryNote":
            return .deliveryNote

        case "slaughterReport":
            return .slaughterReport

        case "weighingReport":
            return .weighingReport

        case "invitation":
            return .invitation

        case "examination":
            return .examination

        case "form":
            return .form

        case "contract":
            return .contract

        case "letter":
            return .letter

        case "plan":
            return .plan

        default:
            return .unknown
        }
    }
}

struct FolderRule: Decodable, Identifiable {

    let name: String
    let area: String
    let folder: String
    let documentTypes: [String]
    let companies: [String]
    let keywords: [String]

    var id: String {
        name
    }

    var archiveArea: ArchiveArea? {
        ArchiveArea(rawValue: area)
    }

    func matchesDocumentType(
        _ documentType: DocumentType
    ) -> Bool {
        guard !documentTypes.isEmpty else {
            return false
        }

        return documentTypes.contains(
            documentTypeIdentifier(documentType)
        )
    }

    func matchesCompany(
        _ company: String?
    ) -> Bool {
        guard
            let company,
            !companies.isEmpty
        else {
            return false
        }

        return companies.contains {
            $0.caseInsensitiveCompare(company) == .orderedSame
        }
    }

    func matchingKeywords(
        in text: String
    ) -> [String] {
        let normalizedText = text.lowercased()

        return keywords.filter { keyword in
            normalizedText.contains(
                keyword.lowercased()
            )
        }
    }

    private func documentTypeIdentifier(
        _ documentType: DocumentType
    ) -> String {
        switch documentType {

        case .invoice:
            return "invoice"

        case .creditNote:
            return "creditNote"

        case .deliveryNote:
            return "deliveryNote"

        case .slaughterReport:
            return "slaughterReport"

        case .weighingReport:
            return "weighingReport"

        case .invitation:
            return "invitation"

        case .examination:
            return "examination"

        case .form:
            return "form"

        case .contract:
            return "contract"

        case .letter:
            return "letter"

        case .plan:
            return "plan"

        case .unknown:
            return "unknown"
        }
    }
}

enum KnowledgeBaseError: LocalizedError {

    case fileNotFound
    case readingFailed(String)
    case decodingFailed(DecodingError)

    var errorDescription: String? {
        switch self {

        case .fileNotFound:
            return "Die Datei knowledge.json wurde nicht gefunden."

        case .readingFailed(let message):
            return "Die Wissensbasis konnte nicht gelesen werden: \(message)"

        case .decodingFailed(let error):
            return "Die Wissensbasis enthält ungültige Daten: \(error.localizedDescription)"
        }
    }
}
