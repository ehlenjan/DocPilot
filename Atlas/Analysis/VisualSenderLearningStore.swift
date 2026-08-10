import Foundation

struct VisualSenderLearningStore {

    private let userDefaults:
        UserDefaults

    private let storageKey =
        "docpilot.visualSenderLearning"

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

    // MARK: - Clear

    func clear() {

        userDefaults.removeObject(
            forKey:
                storageKey
        )
    }
}
