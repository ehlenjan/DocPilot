import Foundation

struct LearnedCompanyStore {

    private let fileManager =
        FileManager.default

    // MARK: - Load

    func load() -> [String] {

        guard let url =
            storeURL
        else {
            return []
        }

        guard
            fileManager.fileExists(
                atPath:
                    url.path
            )
        else {
            return []
        }

        do {

            let data =
                try Data(
                    contentsOf:
                        url
                )

            let companies =
                try JSONDecoder()
                    .decode(
                        [String].self,
                        from:
                            data
                    )

            return normalizedCompanies(
                companies
            )

        } catch {

            print(
                "Gelernte Firmen konnten nicht geladen werden: \(error.localizedDescription)"
            )

            return []
        }
    }

    // MARK: - Save

    func save(
        _ companies: [String]
    ) {

        guard let url =
            storeURL
        else {
            return
        }

        let cleanedCompanies =
            normalizedCompanies(
                companies
            )

        do {

            let directory =
                url
                    .deletingLastPathComponent()

            try fileManager
                .createDirectory(
                    at:
                        directory,
                    withIntermediateDirectories:
                        true
                )

            let encoder =
                JSONEncoder()

            encoder.outputFormatting = [
                .prettyPrinted,
                .sortedKeys
            ]

            let data =
                try encoder.encode(
                    cleanedCompanies
                )

            try data.write(
                to:
                    url,
                options:
                    .atomic
            )

        } catch {

            print(
                "Gelernte Firmen konnten nicht gespeichert werden: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Add

    func add(
        _ company: String
    ) {

        let cleanedCompany =
            company
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            !cleanedCompany.isEmpty
        else {
            return
        }

        var companies =
            load()

        let alreadyExists =
            companies.contains {

                normalize($0) ==
                    normalize(
                        cleanedCompany
                    )
            }

        guard
            !alreadyExists
        else {
            return
        }

        companies.append(
            cleanedCompany
        )

        save(
            companies
        )
    }

    // MARK: - Remove

    func remove(
        _ company: String
    ) {

        var companies =
            load()

        companies.removeAll {

            normalize($0) ==
                normalize(
                    company
                )
        }

        save(
            companies
        )
    }

    // MARK: - Clear

    func clear() {

        guard let url =
            storeURL
        else {
            return
        }

        guard
            fileManager.fileExists(
                atPath:
                    url.path
            )
        else {
            return
        }

        do {

            try fileManager
                .removeItem(
                    at:
                        url
                )

        } catch {

            print(
                "Gelernte Firmen konnten nicht gelöscht werden: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Store URL

    private var storeURL:
        URL? {

        guard let applicationSupportURL =
            fileManager.urls(
                for:
                    .applicationSupportDirectory,
                in:
                    .userDomainMask
            )
            .first
        else {
            return nil
        }

        return applicationSupportURL
            .appendingPathComponent(
                "Atlas",
                isDirectory:
                    true
            )
            .appendingPathComponent(
                "learned-companies.json",
                isDirectory:
                    false
            )
    }

    // MARK: - Normalize List

    private func normalizedCompanies(
        _ companies: [String]
    ) -> [String] {

        var result:
            [String] = []

        var known:
            Set<String> = []

        for company in companies {

            let cleanedCompany =
                company
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            guard
                !cleanedCompany.isEmpty
            else {
                continue
            }

            let key =
                normalize(
                    cleanedCompany
                )

            guard
                !known.contains(
                    key
                )
            else {
                continue
            }

            known.insert(
                key
            )

            result.append(
                cleanedCompany
            )
        }

        return result.sorted {

            $0.localizedStandardCompare(
                $1
            ) == .orderedAscending
        }
    }

    // MARK: - Normalize

    private func normalize(
        _ value: String
    ) -> String {

        value
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive
                ],
                locale:
                    Locale(
                        identifier:
                            "de_DE"
                    )
            )
            .lowercased()
    }
}
