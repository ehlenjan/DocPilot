import Foundation

struct LearningEntry: Codable, Identifiable {

    let id: UUID
    let company: String?
    let documentType: DocumentType
    let keywords: [String]
    let archiveArea: ArchiveArea
    let folder: String
    let createdAt: Date

    init(
        company: String?,
        documentType: DocumentType,
        keywords: [String],
        archiveArea: ArchiveArea,
        folder: String
    ) {
        self.id = UUID()
        self.company = company
        self.documentType = documentType
        self.keywords = keywords
        self.archiveArea = archiveArea
        self.folder = folder
        self.createdAt = Date()
    }
}
