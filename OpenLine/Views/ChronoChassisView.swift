import SwiftUI

struct ChronoChassisView: View {
    @Bindable var engine: StoryEngine
    let onHome: () -> Void
    let onSettings: () -> Void

    var body: some View {
        let palette = engine.palette

        ZStack {
            LinearGradient(
                colors: [palette.chassisTop, palette.chassisMid, palette.chassisBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Side machined knurling notches
            HStack {
                KnurlingRail(inkColor: palette.inkPrimary)
                Spacer()
                KnurlingRail(inkColor: palette.inkPrimary)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 72)
            .allowsHitTesting(false)

            VStack(spacing: 10) {
                ChronoWindowView(
                    palette: palette,
                    language: engine.language,
                    fontStyle: engine.fontStyle,
                    storyBadge: engine.activeStory.badge.text(for: engine.language),
                    currentStage: engine.activeStageIndex,
                    integrityPercent: engine.integrityPercent,
                    activeDelay: engine.activeDelayEvent,
                    onHome: onHome,
                    onTapSettings: onSettings
                )

                ReceiverTimelineView(engine: engine, onHome: onHome)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)
        }
        .animation(.easeInOut(duration: 0.28), value: engine.activeStory.id)

    }
}

private struct KnurlingRail: View {
    let inkColor: Color

    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                let darkRect = CGRect(x: 0, y: y, width: 3, height: 1)
                context.fill(Path(darkRect), with: .color(inkColor.opacity(0.18)))
                let lightRect = CGRect(x: 0, y: y + 1, width: 3, height: 1.5)
                context.fill(Path(lightRect), with: .color(Color.white.opacity(0.75)))
                y += 4
            }
        }
        .frame(width: 3)
    }
}
