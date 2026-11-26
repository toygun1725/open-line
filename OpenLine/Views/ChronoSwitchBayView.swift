import SwiftUI

struct ChronoSwitchBayView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let options: [ChoiceOption]
    let choiceKind: String
    let chosenIndex: Int?
    let language: AppLanguage
    let palette: StoryPalette
    let onSelect: (Int) -> Void

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        layout {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                let visualState = switchState(for: index)
                ChronoKeyButton(
                    label: option.label.text(for: language),
                    state: visualState,
                    isMemoryInject: choiceKind == "memory_inject",
                    palette: palette,
                    action: { onSelect(index) }
                )
                .disabled(chosenIndex != nil)
                .accessibilityAddTraits(chosenIndex == index ? .isSelected : [])
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(palette.switchBayBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(palette.switchBayBorder, lineWidth: 1)
                )
        )
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
    let palette: StoryPalette
    let action: () -> Void

    private var gradientColors: [Color] {
        switch state {
        case .activeWhite:
            return [palette.keyWhiteTop, palette.keyWhiteBottom]
        case .chosenAccent:
            return [palette.keyChosenTop, palette.keyChosenBottom]
        case .unchosen:
            return [palette.keyStoneTop, palette.keyStoneBottom]
        }
    }

    private var borderColor: Color {
        switch state {
        case .activeWhite:
            return isMemoryInject ? palette.accent : palette.keyWhiteBorder
        case .chosenAccent:
            return palette.keyChosenBorder
        case .unchosen:
            return palette.keyStoneBorder
        }
    }

    private var skirtColor: Color {
        switch state {
        case .activeWhite: return palette.keyWhiteSkirt
        case .chosenAccent: return palette.keyChosenSkirt
        case .unchosen: return palette.keyStoneSkirt
        }
    }

    private var textColor: Color {
        switch state {
        case .activeWhite: return palette.inkPrimary
        case .chosenAccent: return palette.keyChosenText
        case .unchosen: return palette.keyStoneText
        }
    }

    private var pipColor: Color {
        switch state {
        case .activeWhite: return palette.accent
        case .chosenAccent: return Color.white
        case .unchosen: return palette.keyStoneBorder
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                HStack(spacing: 6) {
                    Text(label)
                        .font(.body.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(textColor)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)


                }
                .padding(.top, 10)
                .padding(.bottom, 10)
                .padding(.leading, 14)
                .padding(.trailing, 10)
                .frame(maxWidth: .infinity, minHeight: 50)

                Circle()
                    .fill(pipColor)
                    .frame(width: 5, height: 5)
                    .padding(.top, 7)
                    .padding(.leading, 7)
            }
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .shadow(color: skirtColor, radius: 0, x: 0, y: state == .unchosen ? 1.5 : 3)
                    .shadow(color: Color.black.opacity(0.14), radius: 4, x: 0, y: 4)
            )
        }
        .buttonStyle(TactileKeyPressStyle())
    }
}

private struct TactileKeyPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed && !reduceMotion ? 2 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
