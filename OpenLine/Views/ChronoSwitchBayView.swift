import SwiftUI

struct ChronoSwitchBayView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let options: [ChoiceOption]
    let choiceKind: String
    let chosenIndex: Int?
    let language: AppLanguage
    let replyFontStyle: ReplyFontStyle
    let palette: StoryPalette
    let onSelect: (Int) -> Void

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        layout {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                let visualState = switchState(for: index)
                ChronoKeyButton(
                    label: option.label.text(for: language),
                    state: visualState,
                    isMemoryInject: choiceKind == "memory_inject",
                    replyFontStyle: replyFontStyle,
                    palette: palette,
                    action: { onSelect(index) }
                )
                .disabled(chosenIndex != nil)
                .accessibilityAddTraits(chosenIndex == index ? .isSelected : [])
            }
        }
        .padding(.vertical, 6)
    }

    private func switchState(for index: Int) -> ChronoKeyVisualState {
        guard let chosenIndex else { return .activeWhite }
        return chosenIndex == index ? .chosenAccent : .unchosen
    }
}

private enum ChronoKeyVisualState {
    case activeWhite
    case chosenAccent
    case unchosen
}

private struct ChronoKeyButton: View {
    let label: String
    let state: ChronoKeyVisualState
    let isMemoryInject: Bool
    let replyFontStyle: ReplyFontStyle
    let palette: StoryPalette
    let action: () -> Void

    private var fillColor: Color {
        switch state {
        case .activeWhite:
            return palette.plateTop
        case .chosenAccent:
            return palette.keyChosenBottom
        case .unchosen:
            return .clear
        }
    }

    private var borderColor: Color {
        switch state {
        case .activeWhite:
            return palette.accent
        case .chosenAccent:
            return palette.keyChosenBottom
        case .unchosen:
            return palette.plateBorder
        }
    }

    private var textColor: Color {
        switch state {
        case .activeWhite: return palette.inkPrimary
        case .chosenAccent: return palette.keyChosenText
        case .unchosen: return palette.keyStoneText
        }
    }

    var body: some View {
        let outline = RoundedRectangle(cornerRadius: 10)
        Button(action: action) {
            Text(label)
                .font(AppTypography.reply(style: replyFontStyle))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(textColor)
                .padding(.leading, 23)
                .padding(.trailing, 10)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(fillColor, in: outline)
            .overlay(
                outline.strokeBorder(borderColor,
                    style: StrokeStyle(lineWidth: 1, dash: isMemoryInject && state == .activeWhite ? [4, 2] : []))
            )
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(textColor, lineWidth: 1)
                    .background {
                        if state == .chosenAccent { RoundedRectangle(cornerRadius: 2).fill(textColor) }
                    }
                    .frame(width: 7, height: 7)
                    .padding(.leading, 9)
                    .padding(.top, 14)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
            .contentShape(outline)
        }
        .buttonStyle(TactileKeyPressStyle())
    }
}

private struct TactileKeyPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed && !reduceMotion ? 2 : 0)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
