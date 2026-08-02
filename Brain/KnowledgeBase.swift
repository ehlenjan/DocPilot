import Foundation

struct KnowledgeBase: Decodable {

    let companies: [CompanyRule]
    let documentTypes: [DocumentTypeRule]

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
