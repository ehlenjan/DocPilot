import Foundation
import Observation

@Observable
final class SettingsManager {

    private let fileURL: URL

    private(set) var settings: AppSettings

    init() {

        let applicationSupport =
            FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!

        let directory =
            applicationSupport
                .appendingPathComponent("DocPilot")

        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        fileURL =
            directory.appendingPathComponent(
                "settings.json"
            )

        if
            let data = try? Data(contentsOf: fileURL),
            let loaded = try? JSONDecoder().decode(
                AppSettings.self,
                from: data
            )
        {
            settings = loaded
        } else {

            settings = .defaultValue
            save()

        }
    }

    func save() {

        guard
            let data = try? JSONEncoder().encode(settings)
        else {
            return
        }

        try? data.write(to: fileURL)

    }

    func reset() {

        settings = .defaultValue
        save()

    }

    func update(
        _ block: (inout AppSettings) -> Void
    ) {

        block(&settings)
        save()

    }

}
