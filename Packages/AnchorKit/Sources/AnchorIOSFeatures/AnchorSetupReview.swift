#if os(iOS)
  import AnchorDesign
  import SwiftUI

  struct AnchorSetupReview: View {
    @Bindable var draft: AnchorSetupDraft
    let edit: (AnchorSetupSegment) -> Void

    var body: some View {
      VStack(spacing: 10) {
        VStack(alignment: .leading, spacing: 8) {
          Text(SetupCopy.original).font(.footnote.bold()).foregroundStyle(AnchorSetupStyle.heading)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .overlay(alignment: .trailing) {
              Button(SetupCopy.edit) { edit(.goal) }.font(.caption).frame(
                minWidth: 44, minHeight: 44)
            }
          Text(draft.originalText.replacingOccurrences(of: "\n", with: " "))
            .lineLimit(3)
            .font(.caption)
            .foregroundStyle(AnchorSetupStyle.secondary)
            .fixedSize(horizontal: false, vertical: true)
          if !draft.imageData.isEmpty { AnchorSetupPhotos(images: draft.imageData) }
        }
        .padding(14)
        .background(AnchorSetupStyle.card, in: .rect(cornerRadius: 16))

        section(.goal, symbol: "anchor") {
          Text(draft.goalTitle).font(.footnote).fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 28)
        }
        section(.criteria, symbol: "checkmark.seal") {
          VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(draft.criteria.enumerated()), id: \.offset) { _, line in
              HStack(alignment: .top, spacing: 10) {
                Image(systemName: "circle").foregroundStyle(AnchorSetupStyle.accent)
                  .accessibilityHidden(true)
                Text(line).fixedSize(horizontal: false, vertical: true)
              }
              .font(.footnote)
            }
          }
          Button {
            edit(.criteria)
          } label: {
            Label(SetupCopy.addCriterion, systemImage: "plus").font(.caption).frame(minHeight: 44)
          }
        }
        section(.steps, symbol: "list.bullet.rectangle") {
          VStack(spacing: 0) {
            ForEach(Array(draft.steps.enumerated()), id: \.offset) { index, line in
              HStack(alignment: .center, spacing: 10) {
                Text(String(format: "%02d", index + 1))
                  .font(.caption.monospacedDigit())
                  .padding(.horizontal, 8).padding(.vertical, 3)
                  .background(AnchorSetupStyle.controlSurface, in: .capsule)
                Text(line).font(.footnote).frame(maxWidth: .infinity, alignment: .leading)
                Menu {
                  Button(SetupCopy.up, systemImage: "arrow.up") { moveStep(index, by: -1) }
                    .disabled(index == 0)
                  Button(SetupCopy.down, systemImage: "arrow.down") { moveStep(index, by: 1) }
                    .disabled(index == draft.steps.count - 1)
                } label: {
                  Image(systemName: "circle.grid.3x3.fill")
                    .font(.caption)
                    .foregroundStyle(AnchorSetupStyle.secondary)
                    .frame(width: 44, height: 44).contentShape(.rect)
                }
                .accessibilityLabel("\(SetupCopy.reorder) \(index + 1)")
              }
            }
          }
          Button {
            edit(.steps)
          } label: {
            Label(SetupCopy.addStep, systemImage: "plus").font(.caption).frame(minHeight: 44)
          }
        }
      }
      .foregroundStyle(AnchorSetupStyle.ink)
      .tint(AnchorIOSStyle.action)
      .buttonStyle(.plain)
    }

    private func section<Content: View>(
      _ segment: AnchorSetupSegment, symbol: String, @ViewBuilder content: () -> Content
    ) -> some View {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          Group {
            if segment == .goal {
              HarborAnchorGlyph(color: AnchorSetupStyle.accent, lineWidth: 1.2)
                .frame(width: 13, height: 15)
            } else { Image(systemName: symbol).font(.caption).foregroundStyle(AnchorSetupStyle.accent) }
          }
          .frame(width: 22, height: 22)
          .background(AnchorSetupStyle.controlSurface, in: .circle)
          .accessibilityHidden(true)
          Text(segment.title).font(.footnote.bold()).foregroundStyle(AnchorSetupStyle.heading)
            .accessibilityAddTraits(.isHeader)
          Spacer(minLength: 44)
        }
        .frame(minHeight: 28)
        .overlay(alignment: .trailing) {
          // The 44pt target fits in the surrounding padding without enlarging the header.
          Button {
            edit(segment)
          } label: {
            Image(systemName: "pencil.line").frame(width: 44, height: 44).contentShape(.rect)
          }
          .accessibilityLabel("\(SetupCopy.edit) \(segment.title)")
          .accessibilityIdentifier("setup.edit.\(segment.rawValue)")
        }
        .padding(.top, 8)
        content()
      }
      .padding(.horizontal, 14)
      .padding(.bottom, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AnchorSetupStyle.card, in: .rect(cornerRadius: 16))
    }

    private func moveStep(_ index: Int, by offset: Int) {
      var steps = draft.steps
      guard steps.indices.contains(index + offset) else { return }
      steps.swapAt(index, index + offset)
      draft.actionPlan = steps.joined(separator: "\n")
    }
  }
#endif
