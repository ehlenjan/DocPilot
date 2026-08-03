import Foundation

final class AutoAnalysisService {

    func analyzeIfNeeded(
        documents: [DocumentRecord],
        alreadyAnalyzed: (DocumentRecord) -> Bool,
        analyze: (DocumentRecord) -> Void
    ) {

        for document in documents {

            guard !alreadyAnalyzed(document) else {
                continue
            }

            analyze(document)
        }
    }
}
