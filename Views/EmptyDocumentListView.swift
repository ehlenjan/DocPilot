import SwiftUI

struct EmptyDocumentListView: View {

    var body: some View {
        ContentUnavailableView(
            "Keine PDF-Dateien gefunden",
            systemImage: "doc",
            description: Text(
                "Lege PDF-Dateien in den ausgewählten Eingangsordner oder lade die Ansicht neu."
            )
        )
    }
}

#Preview {
    EmptyDocumentListView()
        .frame(width: 800, height: 500)
}
