import SwiftUI

struct DocumentListView: View {

    let documents:
        [DocumentRecord]

    let analysisForDocument:
        (DocumentRecord) -> AtlasAnalysis?

    @Binding var selection:
        DocumentRecord?

    // MARK: - Stable URL Selection

    private var urlSelection:
        Binding<URL?> {

        Binding(
            get: {

                selection?
                    .sourceURL
            },
            set: {
                newURL in

                guard let newURL
                else {

                    selection =
                        nil

                    return
                }

                selection =
                    documents.first(
                        where: {

                            $0.sourceURL ==
                                newURL
                        }
                    )
            }
        )
    }

    // MARK: - Body

    var body: some View {

        List(
            documents,
            selection:
                urlSelection
        ) { document in

            DocumentRowView(
                document:
                    document,
                analysis:
                    analysisForDocument(
                        document
                    )
            )
            .tag(
                document.sourceURL
            )
        }
        .frame(
            minWidth:
                240,
            idealWidth:
                300
        )
    }
}

#Preview {

    @Previewable @State
    var selection:
        DocumentRecord?

    let documents = [
        DocumentRecord(
            sourceURL:
                URL(
                    fileURLWithPath:
                        "/tmp/scan001.pdf"
                )
        ),
        DocumentRecord(
            sourceURL:
                URL(
                    fileURLWithPath:
                        "/tmp/rechnung.pdf"
                )
        )
    ]

    DocumentListView(
        documents:
            documents,

        analysisForDocument: {
            document in

            document.originalFilename ==
                "rechnung.pdf"
            ? AtlasAnalysis(
                documentType:
                    .invoice,
                detectedDate:
                    Date(),
                sender:
                    "RAISA",
                keywords: [
                    "Rechnung"
                ],
                confidence:
                    0.85,
                reasons: [
                    "Dokumentart Rechnung erkannt"
                ]
            )
            : nil
        },

        selection:
            $selection
    )
    .frame(
        width:
            340,
        height:
            500
    )
}
