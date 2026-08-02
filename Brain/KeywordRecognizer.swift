import Foundation

struct KeywordRecognizer {

    private let knowledgeBase: KnowledgeBase

    init(knowledgeBase: KnowledgeBase) {
        self.knowledgeBase = knowledgeBase
    }

    func detect(in text: String) -> [String] {
        let normalizedText = text.lowercased()
        var matches = Set<String>()

        for documentType in knowledgeBase.documentTypes {
            for keyword in documentType.keywords {
                if normalizedText.contains(keyword.lowercased()) {
                    matches.insert(keyword)
                }
            }
        }

        for folderRule in knowledgeBase.folderRules {
            for keyword in folderRule.keywords {
                if normalizedText.contains(keyword.lowercased()) {
                    matches.insert(keyword)
                }
            }
        }

        return matches.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }
}
