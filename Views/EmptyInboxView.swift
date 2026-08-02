import SwiftUI

struct EmptyInboxView: View {

    let errorMessage: String?
    let onChooseFolder: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ContentUnavailableView(
                "Noch kein Eingangsordner",
                systemImage: "tray",
                description: Text(
                    "Wähle den Ordner aus, in dem Scanner, Mail und andere Quellen neue Dokumente ablegen."
                )
            )

            Button(
                "Eingangsordner auswählen",
                action: onChooseFolder
            )
            .buttonStyle(.borderedProminent)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
}

#Preview {
    EmptyInboxView(
        errorMessage: nil,
        onChooseFolder: {}
    )
    .frame(width: 800, height: 500)
}
