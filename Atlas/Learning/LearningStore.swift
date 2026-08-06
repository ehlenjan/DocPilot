import Foundation

final class LearningStore {

    private let fileURL: URL

    init() {

        let applicationSupport =
            FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!

        let directory =
            applicationSupport
                .appendingPathComponent(
                    "DocPilot"
                )

        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        fileURL =
            directory.appendingPathComponent(
                "learning.json"
            )
    }

    func load() -> [LearningEntry] {

        guard
            let data = try? Data(
                contentsOf: fileURL
            )
        else {
            return []
        }

        return (
            try?
            JSONDecoder().decode(
                [LearningEntry].self,
                from: data
            )
        ) ?? []
    }

    func save(
        _ entries: [LearningEntry]
    ) {

        guard
            let data = try?
            JSONEncoder().encode(entries)
        else {
            return
        }

        try? data.write(
            to: fileURL
        )
    }

}
