import SwiftUI

struct ReceiverTimelineView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var engine: StoryEngine
    let onHome: () -> Void

    var body: some View {
        let palette = engine.palette
        let visible = engine.visibleEvents
        let typing = engine.isSenderTyping
        let lastRowID: String? = typing ? "typing-\(visible.count)" :
            (engine.activeDelayEvent != nil ? "active-delay-banner" : visible.last?.id.uuidString)
        let newestMessageID = visible.last(where: {
            if case .message = $0.kind { return true }
            return false
        })?.id

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, event in
                        let previous = index > 0 ? visible[index - 1].kind : nil
                        eventRow(for: event, previous: previous, isNewestMessage: event.id == newestMessageID, palette: palette)
                            .id(event.id.uuidString)
                    }

                    if typing {
                        let sender = engine.activeStory.senderName.text(for: engine.language)
                        TypingIndicator(label: sender + (engine.language == .tr ? " yazıyor…" : " is typing…"), palette: palette)
                            .id("typing-\(visible.count)")
                    }
                    if engine.adFailed {
                        Text(engine.language == .tr ? "Reklam yüklenemedi. Tekrar deneyebilirsin." : "Ad unavailable. Please try again.")
                            .font(.footnote).foregroundStyle(palette.inkPrimary)
                    }
                    if let activeDelay = engine.activeDelayEvent,
                       case .delayStart(let spec, _, _) = activeDelay.kind {
                        ActiveDelayBannerView(
                            spec: spec,
                            language: engine.language,
                            palette: palette
                        )
                        .id("active-delay-banner")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: visible.count)
            }
            .onAppear {
                if let lastRowID { proxy.scrollTo(lastRowID, anchor: .bottom) }
            }
            .onChange(of: lastRowID) { _, lastID in
                if let lastID {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
        .background(palette.wellBg, in: RoundedRectangle(cornerRadius: 6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func eventRow(for event: ScheduledEvent, previous: ScheduledEvent.EventKind?, isNewestMessage: Bool,
                          palette: StoryPalette) -> some View {
        switch event.kind {
        case .message(let text, let glitchLevel, _, let integritySnapshot):
            let resolved = StoryLoader.interpolate(
                text.text(for: engine.language),
                variables: event.stateSnapshot
            )
            VStack(alignment: .leading, spacing: 5) {
                if !continuesMessageGroup(previous) {
                    Text(engine.activeStory.senderName.text(for: engine.language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.accent)
                        .padding(.leading, 2)
                        .padding(.top, 6)
                }
                LedgerPlateView(
                    text: resolved,
                    fontStyle: engine.fontStyle,
                    palette: palette,
                    isActiveNewest: isNewestMessage,
                    glitchLevel: glitchLevel,
                    integrity: isNewestMessage ? engine.integrityPercent : integritySnapshot
                )
            }
            .padding(.trailing, 24)
            .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 6)), removal: .identity))

        case .system(let text, let severity):
            let resolved = StoryLoader.interpolate(
                text.text(for: engine.language),
                variables: event.stateSnapshot
            )
            TelemetryDividerView(text: resolved, severity: severity, palette: palette)

        case .delayStart:
            EmptyView()

        case .actBreakGate(let completedAct, let nextAct, let title, let subtitle, _, let isCleared):
            ActBreakGateCardView(
                completedAct: completedAct,
                nextAct: nextAct,
                title: title.text(for: engine.language),
                subtitle: subtitle.text(for: engine.language),
                isCleared: isCleared,
                isWatchingAd: engine.isWatchingAd,
                priceDisplay: engine.profile.monetization.displayPrice,
                language: engine.language,
                fontStyle: engine.fontStyle,
                palette: palette,
                onWatchAd: {
                    Task { await engine.watchAdAndContinueActBreak(eventID: event.id) }
                },
                onOpenPaywall: {
                    engine.profile.showPaywallSheet = true
                }
            )

        case .choicePrompt(let choiceKind, let options):
            ChronoSwitchBayView(
                options: options,
                choiceKind: choiceKind,
                chosenIndex: event.chosenOptionIndex,
                language: engine.language,
                replyFontStyle: engine.profile.replyFontStyle,
                palette: palette,
                onSelect: { optionIdx in
                    engine.selectChoice(eventID: event.id, optionIndex: optionIdx)
                }
            )

        case .ending(let endingId, let title, let summary):
            let meta = engine.activeStory.endings[endingId]
            let badgeText = meta?.badge.text(for: engine.language) ?? endingId.uppercased()
            let isNegative = meta?.isNegative ?? false
            EndingCardView(
                badgeLabel: badgeText,
                isNegative: isNegative,
                title: title.text(for: engine.language),
                summary: summary.text(for: engine.language),
                language: engine.language,
                fontStyle: engine.fontStyle,
                palette: palette,
                isPaid: engine.isAllAccessUnlocked, isWatchingAd: engine.isWatchingAd,
                onHome: onHome, onRestart: { Task { await engine.replay(eventID: event.id) } }
            )
        }
    }

    private func continuesMessageGroup(_ previous: ScheduledEvent.EventKind?) -> Bool {
        if case .message? = previous { return true }
        return false
    }
}

private struct TypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let label: String
    let palette: StoryPalette

    var body: some View {
        HStack(spacing: 8) {
            TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { context in
                HStack(spacing: 3) {
                    ForEach(0..<3) { index in
                        let time = context.date.timeIntervalSinceReferenceDate - Double(index) * 0.14
                        let pulse = reduceMotion ? 0 : max(0, sin(time * 2 * .pi / 1.2))
                        Circle().frame(width: 4, height: 4)
                            .opacity(0.55 + pulse * 0.45)
                            .offset(y: -2 * pulse)
                    }
                }
            }
            .accessibilityHidden(true)
            Text(label).font(.subheadline)
        }
        .foregroundStyle(palette.inkPrimary)
        .padding(.vertical, 7)
        .padding(.horizontal, 11)
        .background(palette.plateTop, in: Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ActiveDelayBannerView: View {
    let spec: LiveActivitySpec
    let language: AppLanguage
    let palette: StoryPalette

    var body: some View {
        VStack(spacing: 8) {
            Rectangle().fill(palette.ruleHairline).frame(height: 1)
            Text(spec.statusBody.text(for: language))
                .font(AppTypography.telemetry(size: 12))
                .foregroundStyle(palette.inkTelemetry)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 4)
    }
}
