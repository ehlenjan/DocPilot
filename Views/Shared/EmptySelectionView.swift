import SwiftUI

struct EmptySelectionView: View {

    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(description)
        )
    }
}

#Preview {
    EmptySelectionView(
        title: "Kein Dokument ausgewählt",
        systemImage: "doc.text.magnifyingglass",
        description: "Wähle links eine PDF-Datei aus."
    )
    .frame(width: 600, height: 500)
}
