import Foundation

final class FolderBookmarkStore {

    enum BookmarkError: LocalizedError {
        case bookmarkCreationFailed
        case bookmarkResolutionFailed

        var errorDescription: String? {
            switch self {

            case .bookmarkCreationFailed:
                return "Der Ordner konnte nicht gespeichert werden."

            case .bookmarkResolutionFailed:
                return "Der gespeicherte Ordner konnte nicht wiederhergestellt."
            }
        }
    }

    private let userDefaults: UserDefaults
    private let key: String

    init(
        key: String,
        userDefaults: UserDefaults = .standard
    ) {
        self.key = key
        self.userDefaults = userDefaults
    }

    func save(url: URL) throws {

        let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        userDefaults.set(
            bookmark,
            forKey: key
        )
    }

    func load() throws -> URL? {

        guard
            let bookmark = userDefaults.data(
                forKey: key
            )
        else {
            return nil
        }

        var isStale = false

        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            try save(url: url)
        }

        return url
    }

    func remove() {
        userDefaults.removeObject(
            forKey: key
        )
    }
}
