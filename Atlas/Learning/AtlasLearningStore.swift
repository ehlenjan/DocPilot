import Foundation

struct AtlasLearningStore {

    private let userDefaults:
        UserDefaults

    private let storageKey =
        "docpilot.atlasLearningRecords"

    init(
        userDefaults: UserDefaults = .standard
    ) {

        self.userDefaults =
            userDefaults
    }

    // MARK: - Load

    func load()
        -> [AtlasLearningRecord] {

        guard
            let data =
                userDefaults.data(
                    forKey:
                        storageKey
                )
        else {

            return []
        }

        do {

            return try JSONDecoder()
                .decode(
                    [AtlasLearningRecord].self,
                    from:
                        data
                )

        } catch {

            print(
                "Atlas-Lernprotokoll konnte nicht geladen werden: \(error.localizedDescription)"
            )

            return []
        }
    }

    // MARK: - Save

    func save(
        _ records:
            [AtlasLearningRecord]
    ) {

        do {

            let data =
                try JSONEncoder()
                    .encode(
                        records
                    )

            userDefaults.set(
                data,
                forKey:
                    storageKey
            )

        } catch {

            print(
                "Atlas-Lernprotokoll konnte nicht gespeichert werden: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Append

    func append(
        _ record:
            AtlasLearningRecord
    ) {

        var records =
            load()

        records.append(
            record
        )

        save(
            records
        )
    }

    // MARK: - Count

    var count:
        Int {

        load().count
    }

    // MARK: - Clear

    func clear() {

        userDefaults.removeObject(
            forKey:
                storageKey
        )
    }
}
