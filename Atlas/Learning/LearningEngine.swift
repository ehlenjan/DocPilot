import Foundation

struct LearningEngine {

    private let manager: LearningManager

    init(manager: LearningManager = LearningManager()) {
        self.manager = manager
    }

    func remember(
        analysis: AtlasAnalysis,
        destination: FolderSuggestion
    ) {
        let entry = LearningEntry(
            company: analysis.sender,
            documentType: analysis.documentType,
            keywords: analysis.keywords,
            archiveArea: destination.area,
            folder: destination.folder
        )

        manager.add(entry)
    }
}
