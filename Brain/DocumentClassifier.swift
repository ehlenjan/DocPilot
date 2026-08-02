import Foundation

struct DocumentClassifier {

    private let knowledgeBase: KnowledgeBase

    init(knowledgeBase: KnowledgeBase) {
        self.knowledgeBase = knowledgeBase
    }

    func detect(in text: String) -> DocumentType {

        let normalizedText = text.lowercased()

        for rule in knowledgeBase.documentTypes {

            for keyword in rule.keywords {

                if normalizedText.contains(keyword.lowercased()) {
                    return rule.documentType
                }

            }

        }

        return .unknown
    }
}
