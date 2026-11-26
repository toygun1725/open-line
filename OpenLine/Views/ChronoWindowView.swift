import SwiftUI

struct ChronoWindowView: View {
    let palette: StoryPalette
    let language: AppLanguage
    let fontStyle: AppFontStyle
    let storyBadge: String
    let currentStage: Int
    let integrityPercent: Int
    let activeDelay: ScheduledEvent?
    let onHome: () -> Void
    let onTapSettings: () -> Void

    private var accentColor: Color {
        integrityPercent < 30 ? palette.criticalCrimson : palette.accent
    }

    private var statusWord: String {
        switch (integrityPercent, language) {
        case (80..., .tr): return "Çok İyi"
        case (80..., .en): return "Great"
        case (55..., .tr): return "İyi"
        case (55..., .en): return "Good"
        case (35..., .tr): return "Gergin"
        case (35..., .en): return "Tense"
        case (_, .tr): return "Kritik"
        case (_, .en): return "Critical"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    // The current line is identified beside the return action.

                    Button(action: onHome) {
                        Label(language == .tr ? "Ana menü" : "Main menu", systemImage: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 44)
                    }
                    .foregroundStyle(palette.inkPrimary)
                    Text(storyBadge).font(AppTypography.telemetry(size: 12))
                        .foregroundStyle(palette.inkPrimary).lineLimit(1).minimumScaleFactor(0.8)

                    HStack(spacing: 4) {
                        ForEach(1...4, id: \.self) { step in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(step <= currentStage ? accentColor : palette.prismInactive)
                                .frame(width: 14, height: 4)
                        }
                    }
                    .accessibilityLabel(
                        language == .tr
                            ? "Aşama \(currentStage) / 4"
                            : "Stage \(currentStage) of 4"
                    )
                }

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    if let activeDelay,
                       case .delayStart(_, _, let endDate) = activeDelay.kind {
                        Text(endDate, style: .timer)
                            .font(AppTypography.telemetry(size: 12).weight(.semibold))
                            .foregroundStyle(palette.inkPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(palette.keyWhiteBottom)
                            )
                    }

                    Text(statusWord)
                        .font(AppTypography.telemetry(size: 12).weight(.semibold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(palette.plateTop)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(integrityPercent < 30 ? palette.criticalCrimson : palette.windowBorder, lineWidth: 1)
                                )
                        )

                    Button(action: onTapSettings) {
                        Text(language == .tr ? "Ayarlar" : "Setup")
                            .font(AppTypography.control(style: fontStyle, size: 12, weight: .semibold))
                            .foregroundStyle(palette.inkPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [palette.keyWhiteTop, palette.keyWhiteBottom],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(palette.keyWhiteBorder, lineWidth: 1)
                                    )
                                    .shadow(color: palette.keyStoneSkirt.opacity(0.65), radius: 0, x: 0, y: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            // Machined Vernier ruler ticks
            Canvas { context, size in
                var x: CGFloat = 0
                while x < size.width {
                    let rect = CGRect(x: x, y: 0, width: 1, height: size.height)
                    context.fill(Path(rect), with: .color(palette.inkPrimary.opacity(0.22)))
                    x += 8
                }
            }
            .frame(height: 4)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [palette.windowTop, palette.windowBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(palette.windowBorder, lineWidth: 1)
                )
        )
    }
}

struct SplitChronoEmblemView: View {
    let size: CGFloat
    let color: Color

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = min(canvasSize.width, canvasSize.height) * 0.39
            let lineW = max(1.6, size * 0.12)

            var bgRing = Path()
            bgRing.addEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            context.stroke(bgRing, with: .color(color.opacity(0.20)), lineWidth: lineW)

            var splitArc = Path()
            splitArc.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(-90),
                endAngle: .degrees(160),
                clockwise: false
            )
            context.stroke(splitArc, with: .color(color), style: StrokeStyle(lineWidth: lineW, lineCap: .round))

            var hands = Path()
            hands.move(to: CGPoint(x: center.x, y: center.y - radius * 0.55))
            hands.addLine(to: center)
            hands.addLine(to: CGPoint(x: center.x + radius * 0.42, y: center.y + radius * 0.25))
            context.stroke(hands, with: .color(color), style: StrokeStyle(lineWidth: max(1.4, lineW * 0.85), lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}
