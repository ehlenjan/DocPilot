import Foundation

struct ArchiveWorkspace: Identifiable, Codable, Hashable {

    let id: UUID
    var name: String
    var icon: String

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "externaldrive"
    ) {
        self.id = id
        self.name = name
        self.icon = icon
    }
}
