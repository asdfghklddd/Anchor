import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "anchor")
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("Anchor")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Your iPhone and Mac app foundation is ready.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(minWidth: 320, minHeight: 240)
    }
}

#Preview {
    ContentView()
}
