import SwiftUI

struct AtlasConfidenceCard: View {

    let confidence: Double

    private var safeConfidence: Double {
        min(max(confidence, 0), 1)
    }

    private var percentage: Int {
        Int((safeConfidence * 100).rounded())
    }

    private var title: String {
        switch safeConfidence {
        case 0.90...:
            return "Sehr hohe Sicherheit"

        case 0.75..<0.90:
            return "Hohe Sicherheit"

        case 0.50..<0.75:
            return "Mittlere Sicherheit"

        default:
            return "Niedrige Sicherheit"
        }
    }

    private var explanation: String {
        switch safeConfidence {
        case 0.90...:
            return "Atlas hat mehrere eindeutige Merkmale erkannt."

        case 0.75..<0.90:
            return "Die wichtigsten Merkmale stimmen überein."

        case 0.50..<0.75:
            return "Der Vorschlag sollte kurz geprüft werden."

        default:
            return "Atlas benötigt deine Unterstützung."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Atlas")
                        .font(.headline)

                    Text("Dokumentenassistent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(percentage) %")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            ProgressView(value: safeConfidence)
                .progressViewStyle(.linear)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        AtlasConfidenceCard(confidence: 0.94)
        AtlasConfidenceCard(confidence: 0.68)
        AtlasConfidenceCard(confidence: 0.32)
    }
    .padding()
    .frame(width: 420)
}
