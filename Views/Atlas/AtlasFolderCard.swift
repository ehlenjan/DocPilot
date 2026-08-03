import SwiftUI

struct AtlasFolderCard: View {

    let suggestion: FolderSuggestion?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                "Zielordner",
                systemImage: "folder"
            )
            .font(.headline)

            if let suggestion {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "folder.fill")
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(suggestion.area.rawValue)
                                .font(.headline)

                            Text(suggestion.folder)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        Text(
                            "\(Int((suggestion.confidence * 100).rounded())) %"
                        )
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    }

                    if !suggestion.reasons.isEmpty {
                        Divider()

                        ForEach(
                            suggestion.reasons,
                            id: \.self
                        ) { reason in
                            Label(
                                reason,
                                systemImage: "checkmark.circle"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                HStack(spacing: 10) {
                    Image(
                        systemName: "folder.badge.questionmark"
                    )

                    Text("Noch kein Zielordner vorgeschlagen.")
                        .foregroundStyle(.secondary)
                }
            }
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
}

#Preview {
    VStack(spacing: 20) {
        AtlasFolderCard(
            suggestion: FolderSuggestion(
                ruleName: "EHA Lieferscheine",
                area: .ehaKG,
                folder: "Lieferscheine",
                confidence: 0.85,
                reasons: [
                    "Dokumentart Lieferschein passt",
                    "Absender RAISA passt",
                    "Schlüsselwörter: Futtermittel, VzF"
                ]
            )
        )

        AtlasFolderCard(
            suggestion: nil
        )
    }
    .padding()
    .frame(width: 420)
}
