import SwiftUI

struct DocumentRowView: View {

    let document: DocumentRecord
    let analysis: AtlasAnalysis?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: documentIcon)
                .font(.title2)
                .frame(width: 28)
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle)
                    .lineLimit(1)

                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .help(statusText)
        }
        .padding(.vertical, 4)
    }

    private var displayTitle: String {
        guard let analysis else {
            return document.originalFilename
        }

        if analysis.documentType != .unknown {
            return analysis.documentType.rawValue
        }

        return document.originalFilename
    }

    private var detailText: String {
        guard let analysis else {
            return "Noch nicht analysiert"
        }

        var details: [String] = []

        if let sender = analysis.sender {
            details.append(sender)
        }

        if let date = analysis.detectedDate {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "de_DE")
            formatter.dateStyle = .medium
            details.append(formatter.string(from: date))
        }

        if details.isEmpty {
            return document.originalFilename
        }

        return details.joined(separator: " • ")
    }

    private var documentIcon: String {
        guard let analysis else {
            return "doc"
        }

        switch analysis.documentType {
        case .invoice:
            return "doc.text"

        case .creditNote:
            return "eurosign.circle"

        case .deliveryNote:
            return "shippingbox"
            
        case .invitation:
            return "envelope.open"

        case .examination:
            return "cross.case"
            
        case .slaughterReport:
            return "list.clipboard"

        case .weighingReport:
            return "scalemass"

        case .form:
            return "list.bullet.rectangle"

        case .contract:
            return "signature"

        case .letter:
            return "envelope"

        case .plan:
            return "map"

        case .unknown:
            return "doc"
        }
    }

    private var iconColor: Color {
        analysis == nil ? .secondary : .primary
    }

    private var statusIcon: String {
        analysis == nil
            ? "circle"
            : "checkmark.circle.fill"
    }

    private var statusColor: Color {
        analysis == nil
            ? .secondary
            : .green
    }

    private var statusText: String {
        analysis == nil
            ? "Noch nicht analysiert"
            : "Analysiert"
    }
}

#Preview {
    VStack {
        DocumentRowView(
            document: DocumentRecord(
                sourceURL: URL(
                    fileURLWithPath: "/tmp/scan001.pdf"
                )
            ),
            analysis: nil
        )

        DocumentRowView(
            document: DocumentRecord(
                sourceURL: URL(
                    fileURLWithPath: "/tmp/rechnung.pdf"
                )
            ),
            analysis: AtlasAnalysis(
                documentType: .invoice,
                detectedDate: Date(),
                sender: "RAISA",
                keywords: ["Rechnung", "Futtermittel"],
                confidence: 0.85,
                reasons: [
                    "Dokumentart Rechnung erkannt"
                ]
            )
        )
    }
    .padding()
    .frame(width: 340)
}
