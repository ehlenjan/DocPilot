import Foundation

struct VisualSenderLearningStore {

    private let userDefaults:
        UserDefaults

    private let storageKey =
        "docpilot.visualSenderLearning"

    private let fileManager =
        FileManager.default

    private let previewFolderName =
        "VisualSenderPreviews"

    init(
        userDefaults: UserDefaults = .standard
    ) {
        self.userDefaults =
            userDefaults
    }

    // MARK: - Load

    func load()
        -> [VisualSenderLearningEntry] {

        guard
            let data =
                userDefaults.data(
                    forKey: storageKey
                )
        else {
            return []
        }

        do {

            return try JSONDecoder()
                .decode(
                    [VisualSenderLearningEntry].self,
                    from: data
                )

        } catch {

            print(
                "Visuelles Absenderwissen konnte nicht geladen werden: \(error.localizedDescription)"
            )

            return []
        }
    }

    // MARK: - Save

    func save(
        _ entries:
            [VisualSenderLearningEntry]
    ) {

        do {

            let data =
                try JSONEncoder()
                    .encode(
                        entries
                    )

            userDefaults.set(
                data,
                forKey:
                    storageKey
            )

        } catch {

            print(
                "Visuelles Absenderwissen konnte nicht gespeichert werden: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Preview Storage

    /// Speichert ein PNG-Vorschaubild für einen
    /// visuellen Lerneintrag und gibt nur den
    /// Dateinamen zurück.
    ///
    /// Der absolute Pfad wird bewusst nicht im
    /// Lerneintrag gespeichert, damit der App-Support-
    /// Ordner verschiebbar bleibt.
    @discardableResult
    func savePreview(
        pngData: Data,
        for id: UUID
    ) -> String? {

        guard
            !pngData.isEmpty
        else {

            return nil
        }

        do {

            let folderURL =
                try previewFolderURL(
                    createIfNeeded:
                        true
                )

            let filename =
                "\(id.uuidString).png"

            let fileURL =
                folderURL
                    .appendingPathComponent(
                        filename,
                        isDirectory:
                            false
                    )

            try pngData.write(
                to:
                    fileURL,
                options:
                    .atomic
            )

            return filename

        } catch {

            print(
                "Vorschaubild konnte nicht gespeichert werden: \(error.localizedDescription)"
            )

            return nil
        }
    }

    /// Liefert die URL eines gespeicherten
    /// Vorschaubilds.
    func previewURL(
        for filename: String?
    ) -> URL? {

        guard
            let filename,
            !filename.isEmpty
        else {

            return nil
        }

        do {

            let folderURL =
                try previewFolderURL(
                    createIfNeeded:
                        false
                )

            let fileURL =
                folderURL
                    .appendingPathComponent(
                        filename,
                        isDirectory:
                            false
                    )

            guard
                fileManager.fileExists(
                    atPath:
                        fileURL.path
                )
            else {

                return nil
            }

            return fileURL

        } catch {

            return nil
        }
    }

    /// Löscht das Vorschaubild eines einzelnen
    /// Lerneintrags.
    func removePreview(
        filename: String?
    ) {

        guard
            let fileURL =
                previewURL(
                    for:
                        filename
                )
        else {

            return
        }

        do {

            try fileManager.removeItem(
                at:
                    fileURL
            )

        } catch {

            print(
                "Vorschaubild konnte nicht gelöscht werden: \(error.localizedDescription)"
            )
        }
    }

    private func previewFolderURL(
        createIfNeeded: Bool
    ) throws -> URL {

        let applicationSupportURL =
            try fileManager.url(
                for:
                    .applicationSupportDirectory,
                in:
                    .userDomainMask,
                appropriateFor:
                    nil,
                create:
                    true
            )

        let appFolderURL =
            applicationSupportURL
                .appendingPathComponent(
                    "DocPilot",
                    isDirectory:
                        true
                )

        let previewFolderURL =
            appFolderURL
                .appendingPathComponent(
                    previewFolderName,
                    isDirectory:
                        true
                )

        if createIfNeeded {

            try fileManager
                .createDirectory(
                    at:
                        previewFolderURL,
                    withIntermediateDirectories:
                        true
                )
        }

        return previewFolderURL
    }

    // MARK: - Clear

    func clear() {

        userDefaults.removeObject(
            forKey:
                storageKey
        )

        do {

            let folderURL =
                try previewFolderURL(
                    createIfNeeded:
                        false
                )

            if fileManager.fileExists(
                atPath:
                    folderURL.path
            ) {

                try fileManager.removeItem(
                    at:
                        folderURL
                )
            }

        } catch {

            // Kein Vorschaubild-Ordner vorhanden
            // oder bereits gelöscht.
        }
    }
}
