import SwiftUI

struct DocumentListView: View {

    let documents: [DocumentRecord]

    @Binding var selection: DocumentRecord?

    var body: some View {
        List(
            documents,
            selection: $selection
        ) { document in
            Label(
                document.originalFilename,
                systemImage: "doc.richtext"
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
        ),
        DocumentRecord(
            sourceURL: URL(
                fileURLWithPath: "/tmp/lieferschein.pdf"
            )
        )
    ]

    DocumentListView(
        documents: documents,
        selection: $selection
    )
    .frame(
        width: 320,
        height: 500
    )
}
