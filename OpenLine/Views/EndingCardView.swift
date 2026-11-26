import SwiftUI

struct EndingCardView: View {
    let badgeLabel: String
    let isNegative: Bool
    let title: String
    let summary: String
    let language: AppLanguage
    let fontStyle: AppFontStyle
    let palette: StoryPalette
    let isPaid: Bool
    let isWatchingAd: Bool
    let onHome: () -> Void
    let onRestart: () -> Void

    var body: some View {
        let accent = isNegative ? palette.criticalCrimson : palette.accent

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(badgeLabel)
                    .font(AppTypography.telemetry(size: 12).weight(.semibold))
                    .foregroundStyle(accent)

                Spacer()
            }

            Text(title)
                .font(AppTypography.control(style: fontStyle, size: 17, weight: .bold))
                .foregroundStyle(palette.inkPrimary)

            Text(summary)
                .font(AppTypography.narrative(style: fontStyle, size: 14))
                .foregroundStyle(palette.inkHistory)
                .lineSpacing(4)

            Button(action: onRestart) {
                Text(isWatchingAd ? (language == .tr ? "Reklam açılıyor…" : "Opening ad…")
                    : isPaid ? (language == .tr ? "Yeniden başla" : "Play again")
                    : (language == .tr ? "Reklam izle ve yeniden başla" : "Watch ad and play again"))
                    .font(AppTypography.control(style: fontStyle, size: 13.5, weight: .semibold))
                    .foregroundStyle(palette.keyChosenText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(accent)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isWatchingAd)
            .padding(.top, 2)
            Button(language == .tr ? "Ana menüye dön" : "Main menu", action: onHome)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(accent, lineWidth: 1.5)
                )
        )
    }
}
