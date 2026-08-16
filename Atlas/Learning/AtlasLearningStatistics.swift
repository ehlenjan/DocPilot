import Foundation

// MARK: - Atlas Learning Statistics

struct AtlasLearningStatistics {

    let records:
        [AtlasLearningRecord]

    // MARK: - Basic Counts

    var totalCount:
        Int {

        records.count
    }

    // MARK: - Sender

    var senderCorrectCount:
        Int {

        records.filter {
            !$0.senderWasCorrected
        }
        .count
    }

    var senderCorrectedCount:
        Int {

        records.filter {
            $0.senderWasCorrected
        }
        .count
    }

    var senderAccuracy:
        Double {

        accuracy(
            correct:
                senderCorrectCount,
            total:
                totalCount
        )
    }

    // MARK: - Recipient

    var recipientCorrectCount:
        Int {

        records.filter {
            !$0.recipientWasCorrected
        }
        .count
    }

    var recipientCorrectedCount:
        Int {

        records.filter {
            $0.recipientWasCorrected
        }
        .count
    }

    var recipientAccuracy:
        Double {

        accuracy(
            correct:
                recipientCorrectCount,
            total:
                totalCount
        )
    }

    // MARK: - Document Type

    var documentTypeCorrectCount:
        Int {

        records.filter {
            !$0.documentTypeWasCorrected
        }
        .count
    }

    var documentTypeCorrectedCount:
        Int {

        records.filter {
            $0.documentTypeWasCorrected
        }
        .count
    }

    var documentTypeAccuracy:
        Double {

        accuracy(
            correct:
                documentTypeCorrectCount,
            total:
                totalCount
        )
    }

    // MARK: - Date

    var dateCorrectCount:
        Int {

        records.filter {
            !$0.dateWasCorrected
        }
        .count
    }

    var dateCorrectedCount:
        Int {

        records.filter {
            $0.dateWasCorrected
        }
        .count
    }

    var dateAccuracy:
        Double {

        accuracy(
            correct:
                dateCorrectCount,
            total:
                totalCount
        )
    }

    // MARK: - Archive Destination

    var archiveDestinationCorrectCount:
        Int {

        records.filter {
            !archiveDestinationWasCorrected(
                $0
            )
        }
        .count
    }

    var archiveDestinationCorrectedCount:
        Int {

        records.filter {
            archiveDestinationWasCorrected(
                $0
            )
        }
        .count
    }

    var archiveDestinationAccuracy:
        Double {

        accuracy(
            correct:
                archiveDestinationCorrectCount,
            total:
                totalCount
        )
    }

    // MARK: - Overall

    var completelyCorrectCount:
        Int {

        records.filter {
            record in

            !record.senderWasCorrected
            &&
            !record.recipientWasCorrected
            &&
            !record.documentTypeWasCorrected
            &&
            !record.dateWasCorrected
            &&
            !archiveDestinationWasCorrected(
                record
            )
        }
        .count
    }

    var completelyCorrectAccuracy:
        Double {

        accuracy(
            correct:
                completelyCorrectCount,
            total:
                totalCount
        )
    }

    // MARK: - Correction Groups

    var documentTypeCorrections:
        [AtlasLearningCorrection] {

        groupedCorrections(
            records.compactMap {
                record in

                guard
                    record.documentTypeWasCorrected
                else {

                    return nil
                }

                return (
                    from:
                        record.suggestedDocumentType,
                    to:
                        record.finalDocumentType
                )
            }
        )
    }

    var senderCorrections:
        [AtlasLearningCorrection] {

        groupedCorrections(
            records.compactMap {
                record in

                guard
                    record.senderWasCorrected
                else {

                    return nil
                }

                return (
                    from:
                        cleaned(
                            record.suggestedSender
                        ),
                    to:
                        cleaned(
                            record.finalSender
                        )
                )
            }
        )
    }

    var recipientCorrections:
        [AtlasLearningCorrection] {

        groupedCorrections(
            records.compactMap {
                record in

                guard
                    record.recipientWasCorrected
                else {

                    return nil
                }

                return (
                    from:
                        cleaned(
                            record.suggestedRecipient
                        ),
                    to:
                        cleaned(
                            record.finalRecipient
                        )
                )
            }
        )
    }

    var archiveDestinationCorrections:
        [AtlasLearningCorrection] {

        groupedCorrections(
            records.compactMap {
                record in

                guard
                    archiveDestinationWasCorrected(
                        record
                    )
                else {

                    return nil
                }

                let suggested =
                    archiveDestinationText(
                        area:
                            record.suggestedArchiveArea,
                        folder:
                            record.suggestedFolder
                    )

                let final =
                    archiveDestinationText(
                        area:
                            record.finalArchiveArea,
                        folder:
                            record.finalFolder
                    )

                return (
                    from:
                        suggested,
                    to:
                        final
                )
            }
        )
    }

    // MARK: - Company Statistics

    var companyStatistics:
        [AtlasCompanyLearningStatistics] {

        let grouped =
            Dictionary(
                grouping:
                    records.compactMap {
                        record
                        -> (
                            company: String,
                            record: AtlasLearningRecord
                        )? in

                        let company =
                            cleaned(
                                record.finalSender
                            )

                        guard
                            !company.isEmpty
                        else {

                            return nil
                        }

                        return (
                            company:
                                company,
                            record:
                                record
                        )
                    },
                by: {
                    normalize(
                        $0.company
                    )
                }
            )

        return grouped
            .compactMap {
                _,
                values
                -> AtlasCompanyLearningStatistics? in

                guard
                    let first =
                        values.first
                else {

                    return nil
                }

                return AtlasCompanyLearningStatistics(
                    company:
                        first.company,
                    records:
                        values.map {
                            $0.record
                        }
                )
            }
            .sorted {

                if $0.totalCount ==
                    $1.totalCount {

                    return $0.company
                        .localizedStandardCompare(
                            $1.company
                        )
                    ==
                    .orderedAscending
                }

                return $0.totalCount >
                    $1.totalCount
            }
    }

    // MARK: - Recent

    var recentRecords:
        [AtlasLearningRecord] {

        Array(
            records
                .sorted {
                    $0.createdAt >
                        $1.createdAt
                }
                .prefix(
                    20
                )
        )
    }

    // MARK: - Helpers

    private func accuracy(
        correct: Int,
        total: Int
    ) -> Double {

        guard
            total > 0
        else {

            return 0
        }

        return Double(
            correct
        )
        /
        Double(
            total
        )
    }

    private func archiveDestinationWasCorrected(
        _ record:
            AtlasLearningRecord
    ) -> Bool {

        let suggestedArea =
            normalize(
                record.suggestedArchiveArea
            )

        let finalArea =
            normalize(
                record.finalArchiveArea
            )

        let suggestedFolder =
            normalize(
                record.suggestedFolder
            )

        let finalFolder =
            normalize(
                record.finalFolder
            )

        return
            suggestedArea !=
                finalArea
            ||
            suggestedFolder !=
                finalFolder
    }

    private func groupedCorrections(
        _ values:
            [
                (
                    from: String,
                    to: String
                )
            ]
    ) -> [AtlasLearningCorrection] {

        var counts:
            [String: Int] = [:]

        var originals:
            [
                String:
                (
                    from: String,
                    to: String
                )
            ] = [:]

        for value in values {

            let from =
                value.from.isEmpty
                ? "Nicht erkannt"
                : value.from

            let to =
                value.to.isEmpty
                ? "Nicht erkannt"
                : value.to

            let key =
                normalize(
                    from
                )
                +
                "→"
                +
                normalize(
                    to
                )

            counts[
                key,
                default:
                    0
            ] +=
                1

            originals[
                key
            ] =
                (
                    from:
                        from,
                    to:
                        to
                )
        }

        return counts
            .compactMap {
                key,
                count
                -> AtlasLearningCorrection? in

                guard
                    let original =
                        originals[
                            key
                        ]
                else {

                    return nil
                }

                return AtlasLearningCorrection(
                    from:
                        original.from,
                    to:
                        original.to,
                    count:
                        count
                )
            }
            .sorted {

                if $0.count ==
                    $1.count {

                    return $0.from
                        .localizedStandardCompare(
                            $1.from
                        )
                    ==
                    .orderedAscending
                }

                return $0.count >
                    $1.count
            }
    }

    private func archiveDestinationText(
        area: String?,
        folder: String?
    ) -> String {

        let area =
            cleaned(
                area
            )

        let folder =
            cleaned(
                folder
            )

        if !area.isEmpty &&
            !folder.isEmpty {

            return "\(area) / \(folder)"
        }

        if !area.isEmpty {

            return area
        }

        if !folder.isEmpty {

            return folder
        }

        return "Nicht erkannt"
    }

    private func cleaned(
        _ value: String?
    ) -> String {

        value?
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
        ?? ""
    }

    private func normalize(
        _ value: String?
    ) -> String {

        cleaned(
            value
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

// MARK: - Company Learning Statistics

struct AtlasCompanyLearningStatistics:
    Identifiable{

    let company:
        String

    let records:
        [AtlasLearningRecord]

    var id:
        String {

        company
    }

    // MARK: - Total

    var totalCount:
        Int {

        records.count
    }

    // MARK: - Sender

    var senderCorrectCount:
        Int {

        records.filter {
            !$0.senderWasCorrected
        }
        .count
    }

    var senderCorrectedCount:
        Int {

        records.filter {
            $0.senderWasCorrected
        }
        .count
    }

    var senderAccuracy:
        Double {

        accuracy(
            correct:
                senderCorrectCount,
            total:
                totalCount
        )
    }

    // MARK: - Document Type

    var documentTypeCorrectCount:
        Int {

        records.filter {
            !$0.documentTypeWasCorrected
        }
        .count
    }

    var documentTypeCorrectedCount:
        Int {

        records.filter {
            $0.documentTypeWasCorrected
        }
        .count
    }

    var documentTypeAccuracy:
        Double {

        accuracy(
            correct:
                documentTypeCorrectCount,
            total:
                totalCount
        )
    }

    // MARK: - Date

    var dateCorrectCount:
        Int {

        records.filter {
            !$0.dateWasCorrected
        }
        .count
    }

    var dateCorrectedCount:
        Int {

        records.filter {
            $0.dateWasCorrected
        }
        .count
    }

    var dateAccuracy:
        Double {

        accuracy(
            correct:
                dateCorrectCount,
            total:
                totalCount
        )
    }

    // MARK: - Recipient

    var recipientCorrectCount:
        Int {

        records.filter {
            !$0.recipientWasCorrected
        }
        .count
    }

    var recipientCorrectedCount:
        Int {

        records.filter {
            $0.recipientWasCorrected
        }
        .count
    }

    var recipientAccuracy:
        Double {

        accuracy(
            correct:
                recipientCorrectCount,
            total:
                totalCount
        )
    }

    // MARK: - Archive Destination

    var archiveDestinationCorrectCount:
        Int {

        records.filter {
            !archiveDestinationWasCorrected(
                $0
            )
        }
        .count
    }

    var archiveDestinationCorrectedCount:
        Int {

        records.filter {
            archiveDestinationWasCorrected(
                $0
            )
        }
        .count
    }

    var archiveDestinationAccuracy:
        Double {

        accuracy(
            correct:
                archiveDestinationCorrectCount,
            total:
                totalCount
        )
    }

    // MARK: - Completely Correct

    var completelyCorrectCount:
        Int {

        records.filter {
            record in

            !record.senderWasCorrected
            &&
            !record.recipientWasCorrected
            &&
            !record.documentTypeWasCorrected
            &&
            !record.dateWasCorrected
            &&
            !archiveDestinationWasCorrected(
                record
            )
        }
        .count
    }

    var completelyCorrectAccuracy:
        Double {

        accuracy(
            correct:
                completelyCorrectCount,
            total:
                totalCount
        )
    }

    // MARK: - Document Types

    var documentTypes:
        [AtlasCompanyDocumentTypeStatistics] {

        let grouped =
            Dictionary(
                grouping:
                    records,
                by: {
                    $0.finalDocumentType
                }
            )

        return grouped
            .map {
                type,
                records in

                AtlasCompanyDocumentTypeStatistics(
                    documentType:
                        type,
                    records:
                        records
                )
            }
            .sorted {

                if $0.totalCount ==
                    $1.totalCount {

                    return $0.documentType
                        .localizedStandardCompare(
                            $1.documentType
                        )
                    ==
                    .orderedAscending
                }

                return $0.totalCount >
                    $1.totalCount
            }
    }

    // MARK: - Helpers

    private func accuracy(
        correct: Int,
        total: Int
    ) -> Double {

        guard
            total > 0
        else {

            return 0
        }

        return Double(
            correct
        )
        /
        Double(
            total
        )
    }

    private func archiveDestinationWasCorrected(
        _ record:
            AtlasLearningRecord
    ) -> Bool {

        normalize(
            record.suggestedArchiveArea
        )
        !=
        normalize(
            record.finalArchiveArea
        )
        ||
        normalize(
            record.suggestedFolder
        )
        !=
        normalize(
            record.finalFolder
        )
    }

    private func normalize(
        _ value: String?
    ) -> String {

        value?
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
        ?? ""
    }
}

// MARK: - Company Document Type Statistics

struct AtlasCompanyDocumentTypeStatistics:
    Identifiable{

    let documentType:
        String

    let records:
        [AtlasLearningRecord]

    var id:
        String {

        documentType
    }

    var totalCount:
        Int {

        records.count
    }

    var correctCount:
        Int {

        records.filter {
            !$0.documentTypeWasCorrected
        }
        .count
    }

    var correctedCount:
        Int {

        records.filter {
            $0.documentTypeWasCorrected
        }
        .count
    }

    var accuracy:
        Double {

        guard
            totalCount > 0
        else {

            return 0
        }

        return Double(
            correctCount
        )
        /
        Double(
            totalCount
        )
    }
}

// MARK: - Correction

struct AtlasLearningCorrection:
    Identifiable,
    Hashable {

    let from:
        String

    let to:
        String

    let count:
        Int

    var id:
        String {

        "\(from)→\(to)"
    }
}
