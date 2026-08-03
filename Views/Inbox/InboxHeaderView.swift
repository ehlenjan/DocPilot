import SwiftUI

struct InboxHeaderView: View {

    let folderURL: URL
    let documentCount: Int

    let onReload: () -> Void
    let onChooseFolder: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Eingangsordner")
                    .font(.headline)

                Text(folderURL.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer()

            Text("\(documentCount) PDF")
                .foregroundStyle(.secondary)

            Button(action: onReload) {
                Label(
                    "Neu laden",
                    systemImage: "arrow.clockwise"
                )
            }

            Button(
                "Anderen Ordner auswählen",
                action: onChooseFolder
            )
        }
        .padding()
    }
}

#Preview {
    InboxHeaderView(
        folderURL: URL(
            fileURLWithPath: "/Users/jan/Desktop/Testeingang"
        ),
        documentCount: 5,
        onReload: {},
        onChooseFolder: {}
    )
    .frame(width: 900)
}
