import Foundation

struct PDFEvidence: Identifiable, Hashable {

    let id = UUID()

    let text: String
    let kind: Kind

    enum Kind: Hashable {
        case date
        case sender
        case recipient
        case documentType
    }
}
