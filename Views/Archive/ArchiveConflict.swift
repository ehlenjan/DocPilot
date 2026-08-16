import Foundation

struct ArchiveConflict: Identifiable, Equatable {

    let id =
        UUID()

    let sourceURL:
        URL

    let existingURL:
        URL

    let suggestedFilename:
        String

    let isIdentical:
        Bool
}
