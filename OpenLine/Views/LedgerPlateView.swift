import SwiftUI

struct LedgerPlateView: View {
    let text: String
    let fontStyle: AppFontStyle
    let palette: StoryPalette
    let isActiveNewest: Bool
    let glitchLevel: Int
    let integrity: Int

    var body: some View {
        let shouldErode = isActiveNewest && (integrity < 36 || glitchLevel >= 2)

        Group {
            if shouldErode {
                Text(erodedAttributedString)
                    .font(AppTypography.narrative(style: fontStyle, size: 15, medium: isActiveNewest))
            } else {
                Text(text)
                    .font(AppTypography.narrative(style: fontStyle, size: 15, medium: isActiveNewest))
                    .foregroundStyle(isActiveNewest ? palette.inkPrimary : palette.inkHistory)
            }
        }
        .lineSpacing(5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [palette.plateTop, palette.plateBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isActiveNewest
                                ? (integrity < 30 ? palette.criticalCrimson : palette.plateActiveBorder)
                                : palette.plateBorder,
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(isActiveNewest ? 0.10 : 0.05), radius: 4, x: 0, y: 2)
        )
    }

    private var erodedAttributedString: AttributedString {
        let severity = max(Double(glitchLevel) * 0.25, Double(max(0, 36 - integrity)) / 24.0)
        let clampedSeverity = min(1.0, severity)
        let chars = Array(text)
        let keepCount = max(18, Int(Double(chars.count) * (1.0 - clampedSeverity * 0.35)))
        var result = AttributedString()

        for (idx, ch) in chars.prefix(keepCount).enumerated() {
            var segment = AttributedString(String(ch))
            let hash = Double((idx * 41 + integrity * 19) % 100) / 100.0
            if hash < clampedSeverity * 0.65 && ch != " " {
                let opacity = max(0.14, 1.0 - clampedSeverity * (0.45 + hash * 0.50))
                segment.foregroundColor = palette.inkPrimary.opacity(opacity)
            } else {
                segment.foregroundColor = palette.inkPrimary
            }
            result.append(segment)
        }

        if keepCount < chars.count {
            var tail = AttributedString("—")
            tail.foregroundColor = integrity < 30 ? palette.criticalCrimson : palette.inkTelemetry
            result.append(tail)
        }
        return result
    }
}

struct TelemetryDividerView: View {
    let text: String
    let severity: StoryItem.SystemItem.Severity
    let palette: StoryPalette

    private var textColor: Color {
        switch severity {
        case .critical: return palette.criticalCrimson
        case .warning: return palette.inkPrimary
        case .info, .success: return palette.inkTelemetry
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(palette.ruleHairline)
                .frame(height: 1)

            Text(text)
                .font(AppTypography.telemetry(size: 12).weight(severity == .critical ? .semibold : .regular))
                .foregroundStyle(textColor)
                .multilineTextAlignment(.center)
                .layoutPriority(1)

            Rectangle()
                .fill(palette.ruleHairline)
                .frame(height: 1)
        }
        .padding(.vertical, 3)
    }
}
