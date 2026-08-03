import SwiftUI

struct AtlasDashboardGrid: View {

    let analysis: AtlasAnalysis?
    let folderSuggestion: FolderSuggestion?

    var body: some View {

        Grid(horizontalSpacing: 16, verticalSpacing: 16) {

            GridRow {

                AtlasConfidenceCard(
                    confidence: analysis?.confidence ?? 0
                )

                AtlasFolderCard(
                    suggestion: folderSuggestion
                )

            }

            GridRow {

                AtlasInfoCard(
                    analysis: analysis
                )

                AtlasQuickFactsCard(
                    analysis: analysis
                )

            }

        }
    }
}

#Preview {

    AtlasDashboardGrid(
        analysis: AtlasAnalysis(
            documentType: .invoice,
            detectedDate: Date(),
            sender: "RAISA",
            keywords: [
                "Rechnung",
                "Futtermittel",
                "VzF"
            ],
            confidence: 0.91,
            reasons: [
                "Dokument erkannt"
            ]
        ),
        folderSuggestion: FolderSuggestion(
            ruleName: "EHA",
            area: .ehaKG,
            folder: "Lieferscheine",
            confidence: 0.88,
            reasons: []
        )
    )
    .padding()
    .frame(width: 760)

}
