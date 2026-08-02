import SwiftUI

struct DocumentListView: View {

    let documents: [DocumentRecord]
    let analysisForDocument: (DocumentRecord) -> AtlasAnalysis?

    @Binding var selection: DocumentRecord?

    var body: some View {
        List(
            documents,
            selection: $selection
        ) { document in
            DocumentRowView(
                document: document,
                analysis: analysisForDocument(document)
            )
            .tag(document)
        }
        .frame(
            minWidth: 240,
            idealWidth: 300
        )
    }
}

#Preview {
    @Previewable @State var selection: DocumentRecord?

    let documents = [
        DocumentRecord(
            sourceURL: URL(
                fileURLWithPath: "/tmp/scan001.pdf"
            )
        ),
        DocumentRecord(
            sourceURL: URL(
                fileURLWithPath: "/tmp/rechnung.pdf"
            )
        )
    ]

    DocumentListView(
        documents: documents,
        analysisForDocument: { document in
            document.originalFilename == "rechnung.pdf"
                ? AtlasAnalysis(
                    documentType: .invoice,
                    detectedDate: Date(),
                    sender: "RAISA",
                    keywords: ["Rechnung"],
                    confidence: 0.85,
                    reasons: ["Dokumentart Rechnung erkannt"]
                )
                : nil
        },
        selection: $selection
    )
    .frame(
        width: 340,
        height: 500
    )
}
