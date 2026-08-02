//import Foundation

struct CompanyRecognizer {

    private let knowledgeBase: KnowledgeBase

    init(knowledgeBase: KnowledgeBase) {
        self.knowledgeBase = knowledgeBase
    }

    func detect(in text: String) -> String? {

        let normalizedText = text.lowercased()

        for company in knowledgeBase.companies {

            for keyword in company.keywords {

                if normalizedText.contains(keyword.lowercased()) {
                    return company.name
                }

            }
        }

        return nil
    }
}
