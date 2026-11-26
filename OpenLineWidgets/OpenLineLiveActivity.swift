import ActivityKit
import SwiftUI
import WidgetKit

private struct WidgetStoryPalette {
    let platterTint: Color
    let ink: Color
    let mutedInk: Color
    let accent: Color
    let pillBg: Color
    let track: Color
    let porcelain: Color
    let diAccent: Color
    let critCrimson: Color

    static func resolve(_ themeID: String) -> WidgetStoryPalette {
        switch themeID {
        case "warm_rose":
            return WidgetStoryPalette(
                platterTint: Color(red: 1.000, green: 0.969, blue: 0.973), // #FFF7F8
                ink: Color(red: 0.137, green: 0.067, blue: 0.086),         // #231116
                mutedInk: Color(red: 0.388, green: 0.267, blue: 0.298),    // #63444C
                accent: Color(red: 0.722, green: 0.200, blue: 0.322),      // #B83352
                pillBg: Color(red: 0.980, green: 0.867, blue: 0.890),      // #FADDE3
                track: Color(red: 0.910, green: 0.835, blue: 0.855),       // #E8D5DA
                porcelain: Color(red: 1.000, green: 0.984, blue: 0.988),
                diAccent: Color(red: 0.992, green: 0.643, blue: 0.686),    // #FDA4AF
                critCrimson: Color(red: 0.722, green: 0.180, blue: 0.165)
            )
        default: // "ice_blue"
            return WidgetStoryPalette(
                platterTint: Color(red: 0.941, green: 0.973, blue: 0.996), // #F0F8FE
                ink: Color(red: 0.059, green: 0.110, blue: 0.165),         // #0F1C2A
                mutedInk: Color(red: 0.243, green: 0.329, blue: 0.412),    // #3E5469
                accent: Color(red: 0.082, green: 0.369, blue: 0.584),      // #155E95
                pillBg: Color(red: 0.863, green: 0.925, blue: 0.984),      // #DCECFB
                track: Color(red: 0.812, green: 0.863, blue: 0.910),       // #CFDCE8
                porcelain: Color(red: 0.969, green: 0.984, blue: 1.000),
                diAccent: Color(red: 0.490, green: 0.827, blue: 0.988),    // #7DD3FC
                critCrimson: Color(red: 0.722, green: 0.180, blue: 0.165)
            )
        }
    }
}

struct OpenLineLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OpenLineActivityAttributes.self) { context in
            let pal = WidgetStoryPalette.resolve(context.state.themeID)
            LockScreenLiveActivityView(state: context.state, isStale: context.isStale, palette: pal)
                .widgetURL(context.attributes.url)
                .activityBackgroundTint(pal.platterTint)
                .activitySystemActionForegroundColor(pal.accent)
        } dynamicIsland: { context in
            let pal = WidgetStoryPalette.resolve(context.state.themeID)
            let critColor = Color(red: 0.973, green: 0.443, blue: 0.443)
            let accent = context.state.integrityPercent < 30 ? critColor : pal.diAccent

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        SplitChronoEmblem(size: 16, color: accent)
                        Text("\(context.state.currentStage)/\(max(1, context.state.totalStages))")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(Color(red: 0.86, green: 0.88, blue: 0.91))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.isStale {
                        Text(context.state.readyTitle)
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(accent)
                    } else {
                        Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(accent)
                            .multilineTextAlignment(.trailing)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(context.isStale ? context.state.readyTitle : context.state.statusBody)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        UberStageProgressBar(
                            currentStage: context.state.currentStage,
                            totalStages: context.state.totalStages,
                            isReady: context.isStale,
                            activeColor: accent,
                            trackColor: Color(red: 0.220, green: 0.220, blue: 0.232),
                            dotRingColor: .black,
                            barHeight: 4,
                            showMarker: false
                        )
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    SplitChronoEmblem(size: 14, color: accent)
                    Text("\(context.state.currentStage)/\(max(1, context.state.totalStages))")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Color(red: 0.86, green: 0.88, blue: 0.91))
                }
            } compactTrailing: {
                if context.isStale {
                    Text(context.state.readyTitle)
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(accent)
                } else {
                    Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(accent)
                        .frame(maxWidth: 44, alignment: .trailing)
                }
            } minimal: {
                SplitChronoEmblem(size: 14, color: accent)
            }
            .widgetURL(context.attributes.url)
        }
    }
}

private struct LockScreenLiveActivityView: View {
    let state: OpenLineActivityAttributes.ContentState
    let isStale: Bool
    let palette: WidgetStoryPalette

    private var activeTint: Color {
        state.integrityPercent < 30 ? palette.critCrimson : palette.accent
    }

    private var statusWord: String {
        switch state.integrityPercent {
        case 80...: return "Çok İyi"
        case 55...: return "İyi"
        case 35...: return "Gergin"
        default: return "Kritik"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SplitChronoEmblem(size: 16, color: activeTint)
                Text(state.brandTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.mutedInk)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Group {
                    if isStale {
                        Text(state.readyTitle)
                            .foregroundStyle(palette.porcelain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(activeTint))
                    } else {
                        Text(timerInterval: state.startDate...state.endDate, countsDown: true)
                            .foregroundStyle(activeTint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(palette.pillBg))
                    }
                }
                .font(.caption.monospacedDigit().weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isStale ? state.readyTitle : state.statusBody)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)

                Text("\(state.metricLabel): \(statusWord) · \(state.shortTitle)")
                    .font(.caption)
                    .foregroundStyle(palette.mutedInk)
                    .lineLimit(1)
            }

            VStack(spacing: 6) {
                UberStageProgressBar(
                    currentStage: state.currentStage,
                    totalStages: state.totalStages,
                    isReady: isStale,
                    activeColor: activeTint,
                    trackColor: palette.track,
                    dotRingColor: palette.porcelain,
                    barHeight: 6,
                    showMarker: true
                )

                HStack(spacing: 8) {
                    ForEach(Array(state.stageLabels.enumerated()), id: \.offset) { idx, label in
                        let step = idx + 1
                        Text(label)
                            .font(.caption2.weight(step == state.currentStage ? .semibold : .regular))
                            .foregroundStyle(step <= state.currentStage ? palette.ink : palette.mutedInk.opacity(0.75))
                            .frame(maxWidth: .infinity)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct UberStageProgressBar: View {
    let currentStage: Int
    let totalStages: Int
    let isReady: Bool
    let activeColor: Color
    let trackColor: Color
    let dotRingColor: Color
    let barHeight: CGFloat
    let showMarker: Bool

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...max(1, totalStages), id: \.self) { step in
                GeometryReader { geo in
                    let fillRatio: CGFloat = {
                        if step < currentStage || (step == currentStage && isReady) {
                            return 1.0
                        } else if step == currentStage {
                            return 0.65
                        } else {
                            return 0.0
                        }
                    }()

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(trackColor)
                            .frame(height: barHeight)

                        if fillRatio > 0 {
                            Capsule()
                                .fill(activeColor)
                                .frame(width: max(barHeight, geo.size.width * fillRatio), height: barHeight)
                        }

                        if showMarker && step == currentStage && !isReady {
                            Circle()
                                .fill(activeColor)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle()
                                        .stroke(dotRingColor, lineWidth: 2)
                                )
                                .offset(x: max(0, geo.size.width * fillRatio - 5))
                        }
                    }
                    .frame(height: max(barHeight, 10))
                }
                .frame(height: showMarker ? 10 : barHeight)
            }
        }
    }
}

private struct SplitChronoEmblem: View {
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
