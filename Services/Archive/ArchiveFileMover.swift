import Foundation

struct ArchiveFileMover: Sendable {

    enum MoveError: LocalizedError {
        case sourceDoesNotExist
        case destinationDoesNotExist
        case sourceAndDestinationAreEqual
        case destinationAlreadyExists(URL)
        case couldNotDetermineVolume
        case copiedFileCouldNotBeVerified

        var errorDescription: String? {
            switch self {

            case .sourceDoesNotExist:
                return "Die Quelldatei existiert nicht mehr."

            case .destinationDoesNotExist:
                return "Der Zielordner existiert nicht."

            case .sourceAndDestinationAreEqual:
                return "Die Datei befindet sich bereits in diesem Ordner."

            case .destinationAlreadyExists(let url):
                return "Im Zielordner existiert bereits eine Datei mit dem Namen „\(url.lastPathComponent)“."

            case .couldNotDetermineVolume:
                return "Das Laufwerk von Quelle oder Ziel konnte nicht ermittelt werden."

            case .copiedFileCouldNotBeVerified:
                return "Die kopierte Datei konnte nicht sicher überprüft werden. Das Original wurde nicht gelöscht."
            }
        }
    }

    enum MoveMethod: Sendable {
        case directMove
        case copyAndDelete
    }

    struct Result: Sendable {
        let destinationURL: URL
        let method: MoveMethod
    }

    func move(
        file sourceURL: URL,
        to destinationFolderURL: URL
    ) throws -> Result {

        let fileManager = FileManager.default

        // MARK: Quelle prüfen

        var sourceIsDirectory: ObjCBool = false

        guard fileManager.fileExists(
            atPath: sourceURL.path,
            isDirectory: &sourceIsDirectory
        ),
        !sourceIsDirectory.boolValue
        else {
            throw MoveError.sourceDoesNotExist
        }

        // MARK: Zielordner prüfen

        var destinationIsDirectory: ObjCBool = false

        guard fileManager.fileExists(
            atPath: destinationFolderURL.path,
            isDirectory: &destinationIsDirectory
        ),
        destinationIsDirectory.boolValue
        else {
            throw MoveError.destinationDoesNotExist
        }

        // MARK: Gleicher Ordner?

        let sourceFolderURL =
            sourceURL
                .deletingLastPathComponent()
                .standardizedFileURL

        let standardizedDestinationFolderURL =
            destinationFolderURL
                .standardizedFileURL

        guard sourceFolderURL !=
                standardizedDestinationFolderURL
        else {
            throw MoveError
                .sourceAndDestinationAreEqual
        }

        // MARK: Zielpfad

        let destinationURL =
            destinationFolderURL
                .appendingPathComponent(
                    sourceURL.lastPathComponent,
                    isDirectory: false
                )

        // Niemals ungefragt überschreiben

        guard !fileManager.fileExists(
            atPath: destinationURL.path
        ) else {
            throw MoveError
                .destinationAlreadyExists(
                    destinationURL
                )
        }

        // MARK: Volume bestimmen

        let sourceVolume =
            try volumeIdentifier(
                for: sourceURL
            )

        let destinationVolume =
            try volumeIdentifier(
                for: destinationFolderURL
            )

        // MARK: Gleiches Volume

        if sourceVolume == destinationVolume {

            try fileManager.moveItem(
                at: sourceURL,
                to: destinationURL
            )

            return Result(
                destinationURL:
                    destinationURL,
                method:
                    .directMove
            )
        }

        // MARK: Unterschiedliche Volumes

        let sourceSize =
            try fileSize(
                for: sourceURL
            )

        // Erst kopieren
        try fileManager.copyItem(
            at: sourceURL,
            to: destinationURL
        )

        do {
            // Ziel muss existieren
            guard fileManager.fileExists(
                atPath: destinationURL.path
            ) else {
                throw MoveError
                    .copiedFileCouldNotBeVerified
            }

            // Dateigröße kontrollieren
            let destinationSize =
                try fileSize(
                    for: destinationURL
                )

            guard sourceSize ==
                    destinationSize
            else {
                throw MoveError
                    .copiedFileCouldNotBeVerified
            }

            // Erst jetzt Original löschen
            try fileManager.removeItem(
                at: sourceURL
            )

        } catch {

            // Falls das Kopieren bzw. die Prüfung
            // nicht sauber abgeschlossen wurde,
            // entfernen wir die Zielkopie wieder.
            //
            // Das Original bleibt erhalten.
            try? fileManager.removeItem(
                at: destinationURL
            )

            throw error
        }

        return Result(
            destinationURL:
                destinationURL,
            method:
                .copyAndDelete
        )
    }

    // MARK: - Volume

    private func volumeIdentifier(
        for url: URL
    ) throws -> String {

        let values =
            try url.resourceValues(
                forKeys: [
                    .volumeIdentifierKey
                ]
            )

        guard let identifier =
            values.volumeIdentifier
        else {
            throw MoveError
                .couldNotDetermineVolume
        }

        return String(
            describing: identifier
        )
    }

    // MARK: - File Size

    private func fileSize(
        for url: URL
    ) throws -> Int64 {

        let values =
            try url.resourceValues(
                forKeys: [
                    .fileSizeKey
                ]
            )

        guard let size =
            values.fileSize
        else {
            throw MoveError
                .copiedFileCouldNotBeVerified
        }

        return Int64(size)
    }
}
