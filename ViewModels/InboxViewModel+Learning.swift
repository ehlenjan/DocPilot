import Foundation

extension InboxViewModel {

    func rememberCurrentSuggestion() {
        guard
            let analysis,
            let folderSuggestion
        else {
            return
        }

        let learningEngine = LearningEngine()

        learningEngine.remember(
            analysis: analysis,
            destination: folderSuggestion
        )
    }
}
