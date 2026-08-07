import Foundation

struct ArchiveNode: Identifiable, Hashable, Sendable {

    let id = UUID()

    let name: String

    let url: URL

    var children: [ArchiveNode] = []

    var isFolder: Bool {
        !children.isEmpty
    }

    var isLeaf: Bool {
        children.isEmpty
    }
}
