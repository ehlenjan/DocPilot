import Foundation

struct AppSettings: Codable, Equatable {

    var automaticAnalysisEnabled: Bool
    var learningEnabled: Bool
    var showConfidence: Bool
    var showReasons: Bool
    var ocrEnabled: Bool
    var ocrLanguage: OCRLanguage

    static let defaultValue = AppSettings(
        automaticAnalysisEnabled: true,
        learningEnabled: true,
        showConfidence: true,
        showReasons: true,
        ocrEnabled: true,
        ocrLanguage: .german
    )
}

enum OCRLanguage: String, Codable, CaseIterable, Identifiable {

    case german = "Deutsch"
    case english = "Englisch"

    var id: String {
        rawValue
    }

    var recognitionLanguageCode: String {
        switch self {
        case .german:
            return "de-DE"

        case .english:
            return "en-US"
        }
    }
}

