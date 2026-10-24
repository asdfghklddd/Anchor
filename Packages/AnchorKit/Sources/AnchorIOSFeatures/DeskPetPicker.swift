#if os(iOS)
import AnchorDesign
import SwiftUI

/// The Settings choice of desk pet: a tile per pet, plus Off. Applies at once.
struct DeskPetPicker: View {
    @Binding var selection: DeskPetKind

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(DeskPetKind.allCases) { kind in
                Button { selection = kind } label: { tile(kind) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(kind.title)
                    .accessibilityAddTraits(selection == kind ? .isSelected : [])
                    .accessibilityIdentifier("settings.deskPet.\(kind.rawValue)")
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func tile(_ kind: DeskPetKind) -> some View {
        let chosen = selection == kind
        return VStack(spacing: 6) {
            Group {
                if kind == .off {
                    Image(systemName: "moon.zzz")
                        .font(.title3)
                        .foregroundStyle(AnchorIOSStyle.secondaryText)
                } else {
                    DeskPetPortrait(kind: kind)
                }
            }
            .frame(height: 46)
            Text(kind.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(chosen ? AnchorIOSStyle.heading : AnchorIOSStyle.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(chosen ? AnchorIOSStyle.cyan.opacity(0.16) : AnchorIOSStyle.canvasTop.opacity(0.6),
                    in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(chosen ? AnchorIOSStyle.cyan : AnchorIOSStyle.border, lineWidth: chosen ? 2 : 1)
        }
        .contentShape(.rect(cornerRadius: 14))
    }
}
#endif
