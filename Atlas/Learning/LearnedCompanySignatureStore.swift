import Foundation

// MARK: - Learned Company Signature

struct LearnedCompanySignature:
    Codable,
    Identifiable {

    let id:
        UUID

    var company:
        String

    /// Merkmale, die Atlas in bestätigten
    /// Dokumenten dieser Firma gefunden hat.
    var signals:
        [String: Int]

    /// Anzahl der Dokumente, mit denen
    /// diese Firma bestätigt wurde.
    var confirmationCount:
        Int

    var lastUsed:
        Date

    init(
        id: UUID = UUID(),
        company: String,
        signals: [String: Int] = [:],
        confirmationCount: Int = 1,
        lastUsed: Date = Date()
    ) {

        self.id =
            id

        self.company =
            company

        self.signals =
            signals

        self.confirmationCount =
            confirmationCount

        self.lastUsed =
            lastUsed
    }
}

// MARK: - Learned Company Match

struct LearnedCompanySignatureMatch {

    let company:
        String

    let score:
        Int

    let matchedSignals:
        [String]

    let confirmationCount:
        Int

    /// Erst ausreichend bestätigtes Wissen
    /// darf automatisch als Firma verwendet werden.
    var isReliable:
        Bool {

        confirmationCount >= 2
        &&
        (
            matchedSignals.count >= 2
            ||
            score >= 16
        )
    }
}

// MARK: - Store

struct LearnedCompanySignatureStore {

    private let fileManager =
        FileManager.default

    // MARK: - Load

    func load() -> [LearnedCompanySignature] {

        guard
            let url =
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

            return try JSONDecoder()
                .decode(
                    [LearnedCompanySignature].self,
                    from:
                        data
                )

        } catch {

            print(
                "Gelernte Firmenmerkmale konnten nicht geladen werden: \(error.localizedDescription)"
            )

            return []
        }
    }

    // MARK: - Save

    func save(
        _ signatures:
            [LearnedCompanySignature]
    ) {

        guard
            let url =
                storeURL
        else {

            return
        }

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

            encoder.dateEncodingStrategy =
                .iso8601

            let data =
                try encoder.encode(
                    signatures
                )

            try data.write(
                to:
                    url,
                options:
                    .atomic
            )

        } catch {

            print(
                "Gelernte Firmenmerkmale konnten nicht gespeichert werden: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Learn

    func learn(
        company: String,
        documentText: String
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

        let newSignals =
            extractSignals(
                company:
                    cleanedCompany,
                from:
                    documentText
            )

        guard
            !newSignals.isEmpty
        else {

            return
        }

        var signatures =
            load()

        if let index =
            signatures.firstIndex(
                where: {

                    normalize(
                        $0.company
                    )
                    ==
                    normalize(
                        cleanedCompany
                    )
                }
            ) {

            var signature =
                signatures[index]

            signature.confirmationCount +=
                1

            signature.lastUsed =
                Date()

            for signal in newSignals {

                signature.signals[
                    signal,
                    default:
                        0
                ] +=
                    1
            }

            signatures[index] =
                signature

        } else {

            var signalCounts:
                [String: Int] = [:]

            for signal in newSignals {

                signalCounts[
                    signal,
                    default:
                        0
                ] +=
                    1
            }

            signatures.append(
                LearnedCompanySignature(
                    company:
                        cleanedCompany,
                    signals:
                        signalCounts
                )
            )
        }

        save(
            signatures
        )
    }

    // MARK: - Match

    func bestMatch(
        in documentText: String
    ) -> LearnedCompanySignatureMatch? {

        let normalizedText =
            normalize(
                documentText
            )

        guard
            !normalizedText.isEmpty
        else {

            return nil
        }

        let signatures =
            load()

        var bestMatch:
            LearnedCompanySignatureMatch?

        for signature in signatures {

            var score =
                0

            var matchedSignals:
                [String] = []

            for (
                signal,
                occurrences
            ) in signature.signals {

                let normalizedSignal =
                    normalize(
                        signal
                    )

                guard
                    normalizedSignal.count >= 4
                else {

                    continue
                }

                guard
                    normalizedText.contains(
                        normalizedSignal
                    )
                else {

                    continue
                }

                matchedSignals.append(
                    signal
                )

                score +=
                    signalScore(
                        signal:
                            signal,
                        confirmations:
                            occurrences
                    )
            }

            // Der Firmenname selbst ist ebenfalls
            // ein starkes Merkmal.
            let normalizedCompany =
                normalize(
                    signature.company
                )

            if !normalizedCompany.isEmpty,
               normalizedText.contains(
                    normalizedCompany
               ) {

                score +=
                    12

                if !matchedSignals.contains(
                    signature.company
                ) {

                    matchedSignals.append(
                        signature.company
                    )
                }
            }

            guard
                score > 0
            else {

                continue
            }

            let match =
                LearnedCompanySignatureMatch(
                    company:
                        signature.company,
                    score:
                        score,
                    matchedSignals:
                        matchedSignals,
                    confirmationCount:
                        signature.confirmationCount
                )

            if bestMatch == nil
                ||
                match.score >
                    bestMatch!.score {

                bestMatch =
                    match
            }
        }

        return bestMatch
    }

    // MARK: - Signal Extraction

    private func extractSignals(
        company: String,
        from documentText: String
    ) -> [String] {

        let lines =
            documentText
                .components(
                    separatedBy:
                        .newlines
                )
                .map {

                    $0.trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                }
                .filter {

                    !$0.isEmpty
                }

        var signals:
            Set<String> = []

        // Der bestätigte Firmenname selbst
        // ist immer ein sinnvolles Merkmal.
        signals.insert(
            normalize(
                company
            )
        )

        let normalizedCompany =
            normalize(
                company
            )

        for line in lines {

            let normalizedLine =
                normalize(
                    line
                )

            guard
                !normalizedLine.isEmpty
            else {

                continue
            }

            // MARK: Firmenname in Zeile

            if normalizedLine.contains(
                normalizedCompany
            ) {

                if line.count <= 120 {

                    signals.insert(
                        normalizedLine
                    )
                }
            }

            // MARK: E-Mail

            if line.contains(
                "@"
            ) {

                let emailCandidates =
                    extractEmailCandidates(
                        from:
                            line
                    )

                for candidate in emailCandidates {

                    signals.insert(
                        normalize(
                            candidate
                        )
                    )
                }
            }

            // MARK: Domain / Website

            let domains =
                extractDomainCandidates(
                    from:
                        line
                )

            for domain in domains {

                signals.insert(
                    normalize(
                        domain
                    )
                )
            }
        }

        return signals
            .filter {

                $0.count >= 4
            }
            .sorted()
    }

    // MARK: - Email Candidates

    private func extractEmailCandidates(
        from value: String
    ) -> [String] {

        let pattern =
            #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#

        guard
            let regex =
                try? NSRegularExpression(
                    pattern:
                        pattern,
                    options:
                        .caseInsensitive
                )
        else {

            return []
        }

        let range =
            NSRange(
                value.startIndex...,
                in:
                    value
            )

        return regex
            .matches(
                in:
                    value,
                range:
                    range
            )
            .compactMap {

                guard
                    let swiftRange =
                        Range(
                            $0.range,
                            in:
                                value
                        )
                else {

                    return nil
                }

                return String(
                    value[
                        swiftRange
                    ]
                )
            }
    }

    // MARK: - Domain Candidates

    private func extractDomainCandidates(
        from value: String
    ) -> [String] {

        let pattern =
            #"(?:https?://)?(?:www\.)?[A-Z0-9.-]+\.(?:de|com|net|org|eu)"#

        guard
            let regex =
                try? NSRegularExpression(
                    pattern:
                        pattern,
                    options:
                        .caseInsensitive
                )
        else {

            return []
        }

        let range =
            NSRange(
                value.startIndex...,
                in:
                    value
            )

        return regex
            .matches(
                in:
                    value,
                range:
                    range
            )
            .compactMap {

                guard
                    let swiftRange =
                        Range(
                            $0.range,
                            in:
                                value
                        )
                else {

                    return nil
                }

                var domain =
                    String(
                        value[
                            swiftRange
                        ]
                    )
                    .lowercased()

                domain =
                    domain
                        .replacingOccurrences(
                            of:
                                "https://",
                            with:
                                ""
                        )
                        .replacingOccurrences(
                            of:
                                "http://",
                            with:
                                ""
                        )
                        .replacingOccurrences(
                            of:
                                "www.",
                            with:
                                ""
                        )

                return domain
            }
    }

    // MARK: - Score

    private func signalScore(
        signal: String,
        confirmations: Int
    ) -> Int {

        var score =
            4

        // Mailadresse und Domain sind besonders
        // gute Firmenmerkmale.
        if signal.contains(
            "@"
        ) {

            score +=
                8

        } else if signal.contains(
            ".de"
        )
        ||
        signal.contains(
            ".com"
        )
        ||
        signal.contains(
            ".eu"
        ) {

            score +=
                6

        } else if signal.count >= 12 {

            score +=
                3
        }

        // Wiederholt bestätigte Merkmale
        // werden schrittweise stärker.
        score +=
            min(
                confirmations * 2,
                10
            )

        return score
    }

    // MARK: - Store URL

    private var storeURL:
        URL? {

        guard
            let applicationSupportURL =
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
                "learned-company-signatures.json",
                isDirectory:
                    false
            )
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
