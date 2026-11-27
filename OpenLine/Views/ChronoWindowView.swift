import SwiftUI

struct ChronoWindowView: View {
    let palette: StoryPalette
    let language: AppLanguage
    let storyTitle: String
    let metricLabel: String
    let currentStage: Int
    let integrityPercent: Int
    let activeDelay: ScheduledEvent?
    let onHome: () -> Void
    let onTapSettings: () -> Void

    private var accentColor: Color {
        integrityPercent < 35 ? Color(red: 1, green: 0.69, blue: 0.66) : palette.windowSignal
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

    private var stageProgress: some View {
        HStack(spacing: 4) {
            ForEach(1...4, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStage ? accentColor : Color.white.opacity(0.24))
                    .frame(height: 4)
            }
        }
        .frame(minWidth: 64)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(language == .tr ? "Aşama \(currentStage) / 4" : "Stage \(currentStage) of 4")
    }

    private var status: some View {
        Text(statusWord)
            .font(.caption.weight(.semibold))
            .foregroundStyle(accentColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .overlay(Capsule().strokeBorder(palette.windowBorder))
            .accessibilityLabel("\(metricLabel), \(statusWord)")
    }

    @ViewBuilder
    private var countdown: some View {
        if let activeDelay,
           case .delayStart(_, let startDate, let endDate) = activeDelay.kind,
           startDate <= endDate {
            Label {
                Text(timerInterval: startDate...endDate, countsDown: true)
                    .monospacedDigit()
            } icon: {
                Image(systemName: "clock")
                    .accessibilityHidden(true)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func navigationButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.09), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                navigationButton(language == .tr ? "Ana menü" : "Main menu", icon: "chevron.left", action: onHome)
                Text(storyTitle)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)
                navigationButton(language == .tr ? "Ayarlar" : "Settings", icon: "gearshape", action: onTapSettings)
            }

            Rectangle().fill(palette.windowBorder).frame(height: 1)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    stageProgress
                    status.fixedSize(horizontal: true, vertical: false)
                    countdown
                }

                VStack(spacing: 8) {
                    stageProgress
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            status.fixedSize(horizontal: true, vertical: false)
                            countdown
                        }
                        VStack(spacing: 6) {
                            status
                            countdown
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 8)
        .padding(.top, 3)
        .padding(.bottom, 10)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(
                    LinearGradient(
                        colors: [palette.windowTop, palette.windowBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .strokeBorder(palette.windowBorder, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.19), radius: 8, y: 4)
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
