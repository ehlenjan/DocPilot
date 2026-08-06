import SwiftUI

struct AtlasRenameCard: View {

    @Binding var filenameDraft: String

    let isArchiving: Bool
    let canArchive: Bool

    let onGenerateSuggestion: () -> Void
    let onRename: () -> Void
    let onArchive: () -> Void

    var body: some View {
        AtlasCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(
                    "Dateiname",
                    systemImage: "pencil"
                )
                .font(.headline)

                TextField(
                    "Neuer Dateiname",
                    text: $filenameDraft
                )
                .textFieldStyle(.roundedBorder)

                HStack {
                    Text(".pdf")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(
                        action: onGenerateSuggestion
                    ) {
                        Label(
                            "Vorschlag",
                            systemImage: "sparkles"
                        )
                    }
                }

                HStack(spacing: 10) {
                    Button(
                        action: onRename
                    ) {
                        Label(
                            "Umbenennen",
                            systemImage: "checkmark.circle"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(
                        .return,
                        modifiers: [.command]
                    )
                    .disabled(cleanFilename.isEmpty)

                    Button(
                        action: onArchive
                    ) {
                        Label(
                            isArchiving
                                ? "Archiviert …"
                                : "Archivieren",
                            systemImage: isArchiving
                                ? "hourglass"
                                : "archivebox.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        !canArchive ||
                        isArchiving
                    )
                }
            }
        }
    }

    private var cleanFilename: String {
        filenameDraft.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }
}

#Preview {
    @Previewable @State var filename =
        "2026-08-03 Rechnung RAISA"

    AtlasRenameCard(
        filenameDraft: $filename,
        isArchiving: false,
        canArchive: true,
        onGenerateSuggestion: {},
        onRename: {},
        onArchive: {}
    )
    .padding()
    .frame(width: 420)
}
