import SwiftUI

struct AtlasRenameCard: View {

    @Binding var filenameDraft: String

    let onGenerateSuggestion: () -> Void
    let onRename: () -> Void

    var body: some View {
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

            Button(
                action: onRename
            ) {
                Label(
                    "Datei umbenennen",
                    systemImage: "checkmark.circle.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(
                .return,
                modifiers: [.command]
            )
            .disabled(cleanFilename.isEmpty)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(.quaternary)
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
        onGenerateSuggestion: {},
        onRename: {}
    )
    .padding()
    .frame(width: 420)
}
