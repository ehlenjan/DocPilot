import SwiftUI

struct AtlasStatusCard: View {

    let analysis: AtlasAnalysis?
    let isAnalyzing: Bool

    private var status: String {
        if isAnalyzing {
            return "Atlas analysiert …"
        }

        guard let analysis else {
            return "Bereit zur Analyse"
        }

        switch analysis.confidence {
        case 0.90...:
            return "Analyse abgeschlossen"

        case 0.75..<0.90:
            return "Analyse wahrscheinlich korrekt"

        default:
            return "Analyse bitte prüfen"
        }
    }

    private var subtitle: String {
        if isAnalyzing {
            return "Text, Dokumentart, Absender und Zielordner werden geprüft."
        }

        guard let analysis else {
            return "Wähle ein Dokument oder starte die Analyse."
        }

        switch analysis.confidence {
        case 0.90...:
            return "Atlas hat mehrere eindeutige Merkmale gefunden."

        case 0.75..<0.90:
            return "Die wichtigsten Merkmale stimmen überein."

        default:
            return "Für dieses Dokument gibt es noch zu wenige eindeutige Hinweise."
        }
    }

    private var icon: String {
        if isAnalyzing {
            return "brain.head.profile"
        }

        guard let analysis else {
            return "brain.head.profile"
        }

        switch analysis.confidence {
        case 0.90...:
            return "checkmark.circle.fill"

        case 0.75..<0.90:
            return "exclamationmark.circle.fill"

        default:
            return "questionmark.circle.fill"
        }
    }

    var body: some View {
        AtlasCard {
            HStack(spacing: 18) {
                Image(systemName: icon)
                    .font(.system(size: 42))
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(
                        .pulse,
                        options: .repeating,
                        isActive: isAnalyzing
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(status)
                        .font(.title3.bold())

                    Text(subtitle)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isAnalyzing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .animation(
            .easeInOut(duration: 0.25),
            value: isAnalyzing
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        AtlasStatusCard(
            analysis: nil,
            isAnalyzing: true
        )

        AtlasStatusCard(
            analysis: AtlasAnalysis(
                documentType: .invoice,
                detectedDate: Date(),
                sender: "RAISA",
                keywords: [],
                confidence: 0.94,
                reasons: []
            ),
            isAnalyzing: false
        )
    }
    .padding()
    .frame(width: 460)
}
