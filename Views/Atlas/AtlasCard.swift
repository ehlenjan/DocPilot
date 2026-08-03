import SwiftUI

struct AtlasCard<Content: View>: View {

    @ViewBuilder
    let content: () -> Content

    var body: some View {
        content()
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(16)
            .background(.regularMaterial)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .stroke(.quaternary)
            }
    }
}

#Preview {

    AtlasCard {

        VStack(alignment: .leading) {

            Text("Atlas Card")
                .font(.headline)

            Text("Einheitliches Kartenlayout")

        }

    }
    .padding()
    .frame(width: 380)

}
