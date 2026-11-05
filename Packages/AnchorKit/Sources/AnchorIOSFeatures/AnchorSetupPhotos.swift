// Role: the setup sheet's photo row.

#if os(iOS)
import AnchorDesign
import SwiftUI

/// Thumbnails with add and remove. Photos stay on this phone.
struct AnchorSetupPhotos: View {
    let images: [Data]
    var remove: ((Int) -> Void)?
    @State private var selectedImage: Data?
    @State private var showsImage = false

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(images.indices, id: \.self) { index in
                    if let image = UIImage(data: images[index]) {
                        VStack(spacing: 0) {
                            Button {
                                selectedImage = images[index]
                                showsImage = true
                            } label: {
                                Image(uiImage: image).resizable().scaledToFill()
                                    .frame(width: 64, height: 64)
                                    .clipShape(.rect(cornerRadius: 10))
                            }
                            .buttonStyle(AnchorPressButtonStyle())
                            .accessibilityLabel("\(SetupCopy.photo) \(index + 1)")
                            if let remove {
                                Button { remove(index) } label: {
                                    Image(systemName: "minus.circle")
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(AnchorPressButtonStyle(.control))
                                .foregroundStyle(.tint)
                                .accessibilityLabel("\(SetupCopy.removePhoto) \(index + 1)")
                            }
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showsImage) {
            NavigationStack {
                if let selectedImage, let image = UIImage(data: selectedImage) {
                    Image(uiImage: image).resizable().scaledToFit()
                        .accessibilityLabel(SetupCopy.photo)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(SetupCopy.doneEditing) { showsImage = false }
                            }
                        }
                }
            }
        }
    }
}
#endif
