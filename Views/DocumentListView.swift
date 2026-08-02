import SwiftUI

struct DocumentListView: View {

    let documents: [DocumentRecord]
    let selectedAnalysis: AtlasAnalysis?

    @Binding var selection: DocumentRecord?

    var body: some View {
        List(
            documents,
            selection: $selection
        ) { document in
            DocumentRowView(
                document: document,
                analysis: analysis(for: document)
            )
            .tag(document)
        }
        .frame(
            minWidth: 240,
            idealWidth: 300
        )
    }

    private func analysis(
        for document: DocumentRecord
    ) -> AtlasAnalysis? {
        guard
            document.id == selection?.id
        else {
            return nil
        }

        return selectedAnalysis
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
        selectedAnalysis: nil,
        selection: $selection
    )
    .frame(
        width: 340,
        height: 500
    )
}
