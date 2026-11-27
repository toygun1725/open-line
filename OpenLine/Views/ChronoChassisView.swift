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

            VStack(spacing: 5) {
                ChronoWindowView(
                    palette: palette,
                    language: engine.language,
                    storyTitle: engine.activeStory.title.text(for: engine.language),
                    metricLabel: engine.activeStory.metricLabel.text(for: engine.language),
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
