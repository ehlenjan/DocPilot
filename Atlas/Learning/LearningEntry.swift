import Foundation

struct LearningEntry: Codable, Identifiable {

    let id: UUID
    let company: String?
    let documentType: DocumentType
    let keywords: [String]
    let archiveArea: ArchiveArea
    let folder: String

    let createdAt: Date
    var lastUsedAt: Date
    var usageCount: Int

    init(
        company: String?,
        documentType: DocumentType,
        keywords: [String],
        archiveArea: ArchiveArea,
        folder: String,
        createdAt: Date = Date(),
        lastUsedAt: Date = Date(),
        usageCount: Int = 1
    ) {
        self.id = UUID()
        self.company = company
        self.documentType = documentType
        self.keywords = keywords
        self.archiveArea = archiveArea
        self.folder = folder
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.usageCount = max(usageCount, 1)
    }

    mutating func registerUse() {
        usageCount += 1
        lastUsedAt = Date()
    }
}
