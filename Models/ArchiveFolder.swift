//import Foundation

struct ArchiveFolder: Identifiable, Hashable {

    let area: ArchiveArea
    let name: String

    var id: String {
        "\(area.rawValue)-\(name)"
    }

    var displayPath: String {
        "\(area.rawValue) → \(name)"
    }
}
