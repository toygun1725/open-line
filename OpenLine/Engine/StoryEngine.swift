import Foundation
import Observation

@MainActor
@Observable
final class StoryEngine {
    let activeStory: StoryCatalogEntry
    let profile: PlayerProfile
    private let story: LoadedStory
    private let store: SaveStore
    private let activities: LiveActivityManager?
    @ObservationIgnored var onScheduleChange: (() -> Void)?
    private let ticking: Bool
    private var revealTask: Task<Void, Never>?
    private var activityTask: Task<Void, Never>?
    private(set) var sessionID = UUID().uuidString
    private(set) var timeline: [ScheduledEvent] = []
    private(set) var variables: [String: StoryValue] = [:]
    private(set) var currentTime = Date()
    private(set) var unlockedEndings: Set<String> = []
    private(set) var isWatchingAd = false
    private(set) var adFailed = false
    var language: AppLanguage { profile.language }
    var fontStyle: AppFontStyle { profile.fontStyle }
    var palette: StoryPalette { StoryPalette.palette(for: activeStory.theme) }
    var isAllAccessUnlocked: Bool { profile.isAllAccessUnlocked }
    var hasStarted: Bool { !timeline.isEmpty }
    var visibleEnding: ScheduledEvent? {
        guard let last = timeline.last, last.fireDate <= currentTime, case .ending = last.kind else { return nil }
        return last
    }
    var latestMessage: (text: String, date: Date)? {
        for event in visibleEvents.reversed() {
            if case .message(let text, _, _, _) = event.kind {
                return (StoryLoader.interpolate(text.text(for: language), variables: event.stateSnapshot), event.fireDate)
            }
        }
        return nil
    }

    init(entry: StoryCatalogEntry, story: LoadedStory, profile: PlayerProfile, store: SaveStore,
         activities: LiveActivityManager?, ticking: Bool) {
        self.activeStory = entry
        self.story = story
        self.profile = profile
        self.store = store
        self.activities = activities
        self.ticking = ticking
        if let saved = store.load(storyID: entry.id) {
            timeline = saved.timeline
            variables = saved.variables
            unlockedEndings = saved.unlockedEndings
            sessionID = saved.sessionID
            migrateLegacyTimeline(wasFast: saved.isFastModeEnabled)
        }
        if hasStarted { syncClock() }
    }

    /// Keep delivered messages and choices in place when upgrading an older saved run.
    private func migrateLegacyTimeline(wasFast: Bool) {
        var shift: TimeInterval = 0
        var changed = wasFast
        for index in timeline.indices {
            let old = timeline[index]
            let fireDate = old.fireDate.addingTimeInterval(shift)
            var kind = old.kind
            switch kind {
            case .delayStart(let spec, let start, let end) where wasFast && end > currentTime:
                if let node = story.nodes[old.nodeID], case .delay(let seconds, _, _) = node.transition {
                    let extra = max(0, seconds - end.timeIntervalSince(start))
                    kind = .delayStart(liveActivity: spec, startDate: start.addingTimeInterval(shift),
                        endDate: end.addingTimeInterval(shift + extra))
                    shift += extra
                }
            case .message(let text, let glitch, let haptic, let integrity) where text.en.localizedCaseInsensitiveContains("rewind"):
                if let node = story.nodes[old.nodeID],
                   case .message(let replacement)? = flattenItems(node.items, variables: old.stateSnapshot).last {
                    kind = .message(text: replacement.text, glitchLevel: glitch, haptic: haptic, integritySnapshot: integrity)
                }
            case .ending(_, _, let summary) where summary.en.localizedCaseInsensitiveContains("rewind"):
                if let node = story.nodes[old.nodeID], case .ending(let id, let title, let text) = node.transition {
                    kind = .ending(endingId: id, title: title, summary: text)
                }
            default: break
            }
            if fireDate != old.fireDate || kind != old.kind {
                timeline[index] = ScheduledEvent(id: old.id, nodeID: old.nodeID, act: old.act, fireDate: fireDate,
                    kind: kind, stateSnapshot: old.stateSnapshot, chosenOptionIndex: old.chosenOptionIndex)
                changed = true
            }
        }
        if changed { persist() }
    }

    func connect(now: Date = Date()) {
        guard activeStory.isFree || isAllAccessUnlocked else { return }
        guard !hasStarted else { syncClock(now: now); return }
        beginRun(now: now)
    }

    private func beginRun(now: Date) {
        sessionID = UUID().uuidString
        timeline = []
        currentTime = now
        var vars = story.manifest.variables.mapValues(\.default)
        enqueueLookahead(from: story.manifest.startNodeId, startTime: now, vars: &vars)
        variables = vars
        adFailed = false
        persist()
        onScheduleChange?()
        scheduleNextRevealTick()
    }

    func selectChoice(eventID: UUID, optionIndex: Int, now: Date = Date()) {
        guard let prompt = timeline.last, prompt.id == eventID, prompt.fireDate <= now,
              prompt.chosenOptionIndex == nil, case .choicePrompt(_, let options) = prompt.kind,
              options.indices.contains(optionIndex) else { return }
        let choice = options[optionIndex]
        var vars = prompt.stateSnapshot
        applyEffects(choice.effects, to: &vars)
        timeline[timeline.count - 1].chosenOptionIndex = optionIndex
        profile.sound?.playSwitch()
        profile.haptics?.triggerChoiceTap()
        currentTime = now
        enqueueLookahead(from: choice.target, startTime: now, vars: &vars)
        variables = vars
        persist()
        onScheduleChange?()
        scheduleNextRevealTick()
    }

    func watchAdAndContinueActBreak(eventID: UUID) async {
        guard let event = timeline.last, event.id == eventID, event.fireDate <= currentTime,
              case .actBreakGate(_, _, _, _, _, false) = event.kind else { return }
        await performRewardedAction(for: eventID) { clearGate(at: Date()) }
    }

    func replay(eventID: UUID) async {
        guard visibleEnding?.id == eventID else { return }
        await performRewardedAction(for: eventID) {
            let finishedSession = sessionID
            beginRun(now: Date())
            Task { await activities?.end(sessionID: finishedSession) }
        }
    }

    private func performRewardedAction(for eventID: UUID, onEarned: () -> Void) async {
        guard !isWatchingAd else { return }
        isWatchingAd = true
        defer { isWatchingAd = false }
        adFailed = false
        if !isAllAccessUnlocked {
            let result = await profile.reward()
            adFailed = result == .unavailable
            guard result == .earned else { return }
        }
        guard timeline.last?.id == eventID else { return }
        onEarned()
    }

    private func clearGate(at now: Date) {
        guard let gate = timeline.last, gate.fireDate <= now,
              case .actBreakGate(let act, let next, let title, let sub, let target, false) = gate.kind else { return }
        timeline[timeline.count - 1] = ScheduledEvent(id: gate.id, nodeID: gate.nodeID, act: gate.act,
            fireDate: gate.fireDate, kind: .actBreakGate(completedAct: act, nextAct: next,
            title: title, subtitle: sub, target: target, isCleared: true),
            stateSnapshot: gate.stateSnapshot, chosenOptionIndex: nil)
        var vars = gate.stateSnapshot
        currentTime = now
        enqueueLookahead(from: target, startTime: now, vars: &vars)
        variables = vars
        persist()
        onScheduleChange?()
        scheduleNextRevealTick()
    }

    func syncClock(now: Date = Date(), notify: Bool = false) {
        guard hasStarted else { return }
        let previousCount = visibleEvents.count
        currentTime = now
        if let last = visibleEvents.last {
            variables = last.stateSnapshot
            if notify && visibleEvents.count > previousCount, case .message = last.kind {
                profile.sound?.playIncomingMessage()
                profile.haptics?.triggerSubtleReceive()
            }
        }
        if let end = visibleEnding, case .ending(let id, _, _) = end.kind,
           unlockedEndings.insert(id).inserted { persist() }
        if isAllAccessUnlocked { clearGate(at: now) }
        syncActivity()
        scheduleNextRevealTick()
    }

    func prepareForBackground() {
        revealTask?.cancel()
        let upcoming = timeline.first { event in
            guard event.fireDate > currentTime else { return false }
            if case .delayStart = event.kind { return true }
            return false
        }
        syncActivity(upcoming: upcoming)
    }

    private func syncActivity(upcoming: ScheduledEvent? = nil) {
        let previous = activityTask
        let session = sessionID
        let delay = activeDelayEvent ?? upcoming
        activityTask = Task { [weak self] in
            await previous?.value
            guard let self, !Task.isCancelled, self.sessionID == session else { return }
            if let delay, case .delayStart(let spec, let start, let end) = delay.kind {
                await self.activities?.startOrUpdate(spec: spec, startDate: start, endDate: end,
                    integrityPercent: self.integrityPercent, themeID: self.activeStory.theme.rawValue,
                    brandTitle: self.activeStory.title.text(for: self.language),
                    metricLabel: self.activeStory.metricLabel.text(for: self.language),
                    storyID: self.activeStory.id, sessionID: session, language: self.language)
            } else {
                await self.activities?.end(sessionID: session)
            }
        }
    }
    var visibleEvents: [ScheduledEvent] {
        timeline.filter { $0.fireDate <= currentTime }
    }

    var isSenderTyping: Bool {
        guard let next = timeline.first(where: { $0.fireDate > currentTime }),
              case .message = next.kind else { return false }
        return activeDelayEvent == nil
    }

    var activeDelayEvent: ScheduledEvent? {
        let revealed = visibleEvents
        guard let lastDelay = revealed.last(where: {
            if case .delayStart = $0.kind { return true }
            return false
        }) else { return nil }
        if case .delayStart(_, _, let endDate) = lastDelay.kind, endDate > currentTime {
            return lastDelay
        }
        return nil
    }

    var activeStageIndex: Int {
        if let delay = activeDelayEvent,
           case .delayStart(let spec, _, _) = delay.kind {
            return spec.currentStage
        }
        let maxRevealedStage = visibleEvents.compactMap { ev -> Int? in
            if case .delayStart(let spec, _, _) = ev.kind { return spec.currentStage }
            return nil
        }.max()
        return maxRevealedStage ?? 1
    }

    var integrityPercent: Int {
        max(0, min(100, variables[activeStory.metricVar]?.intValue ?? 100))
    }

    private func enqueueLookahead(from startNodeID: String, startTime: Date, vars: inout [String: StoryValue]) {
        var cursorTime = startTime
        var currentID: String? = startNodeID
        var safetySteps = 0

        while let nid = currentID, let node = story.nodes[nid], safetySteps < 200 {
            safetySteps += 1
            applyEffects(node.effects, to: &vars)

            let expandedItems = flattenItems(node.items, variables: vars)
            for item in expandedItems {
                let stepDelay: Double
                switch item {
                case .message(let msg):
                    if let explicit = msg.typingDelaySec {
                        stepDelay = explicit
                    } else {
                        let count = Double(msg.text.text(for: language).count)
                        stepDelay = min(4.2, max(1.1, 0.8 + count * 0.022))
                    }
                    cursorTime = cursorTime.addingTimeInterval(stepDelay)
                    let integrity = max(0, min(100, vars[activeStory.metricVar]?.intValue ?? 100))
                    timeline.append(ScheduledEvent(
                        id: UUID(),
                        nodeID: node.id,
                        act: node.act,
                        fireDate: cursorTime,
                        kind: .message(
                            text: msg.text,
                            glitchLevel: msg.glitchLevel ?? 0,
                            haptic: msg.haptic,
                            integritySnapshot: integrity
                        ),
                        stateSnapshot: vars,
                        chosenOptionIndex: nil
                    ))

                case .system(let sys):
                    cursorTime = cursorTime.addingTimeInterval(0.45)
                    timeline.append(ScheduledEvent(
                        id: UUID(),
                        nodeID: node.id,
                        act: node.act,
                        fireDate: cursorTime,
                        kind: .system(text: sys.text, severity: sys.severity),
                        stateSnapshot: vars,
                        chosenOptionIndex: nil
                    ))

                case .conditional:
                    break
                }
            }

            switch node.transition {
            case .next(let target):
                currentID = target

            case .conditionalNext(let branches, let fallback):
                let matched = branches.first { $0.condition.evaluate(with: vars) }
                currentID = matched?.target ?? fallback

            case .delay(let seconds, let target, let liveActivity):
                let delayStart = cursorTime
                let delayEnd = cursorTime.addingTimeInterval(seconds)
                timeline.append(ScheduledEvent(
                    id: UUID(),
                    nodeID: node.id,
                    act: node.act,
                    fireDate: delayStart,
                    kind: .delayStart(liveActivity: liveActivity, startDate: delayStart, endDate: delayEnd),
                    stateSnapshot: vars,
                    chosenOptionIndex: nil
                ))
                cursorTime = delayEnd
                currentID = target

            case .actBreak(let completedAct, let nextAct, let title, let subtitle, let target):
                let alreadyCleared = timeline.contains { event in
                    if case .actBreakGate(let act, _, _, _, _, true) = event.kind { return act == completedAct }
                    return false
                }
                if isAllAccessUnlocked || alreadyCleared {
                    currentID = target
                } else {
                    cursorTime = cursorTime.addingTimeInterval(0.35)
                    timeline.append(ScheduledEvent(
                        id: UUID(),
                        nodeID: node.id,
                        act: node.act,
                        fireDate: cursorTime,
                        kind: .actBreakGate(
                            completedAct: completedAct,
                            nextAct: nextAct,
                            title: title,
                            subtitle: subtitle,
                            target: target,
                            isCleared: false
                        ),
                        stateSnapshot: vars,
                        chosenOptionIndex: nil
                    ))
                    currentID = nil
                }

            case .choice(let choiceKind, let options):
                cursorTime = cursorTime.addingTimeInterval(0.35)
                timeline.append(ScheduledEvent(
                    id: UUID(),
                    nodeID: node.id,
                    act: node.act,
                    fireDate: cursorTime,
                    kind: .choicePrompt(choiceKind: choiceKind, options: options),
                    stateSnapshot: vars,
                    chosenOptionIndex: nil
                ))
                currentID = nil

            case .ending(let endingId, let title, let summary):
                cursorTime = cursorTime.addingTimeInterval(0.6)
                timeline.append(ScheduledEvent(
                    id: UUID(),
                    nodeID: node.id,
                    act: node.act,
                    fireDate: cursorTime,
                    kind: .ending(endingId: endingId, title: title, summary: summary),
                    stateSnapshot: vars,
                    chosenOptionIndex: nil
                ))
                currentID = nil
            }
        }
    }

    private func flattenItems(_ items: [StoryItem], variables: [String: StoryValue]) -> [StoryItem] {
        var out: [StoryItem] = []
        for item in items {
            switch item {
            case .conditional(let cond):
                if cond.condition.evaluate(with: variables) {
                    out.append(contentsOf: flattenItems(cond.thenItems, variables: variables))
                } else if let elseItems = cond.elseItems {
                    out.append(contentsOf: flattenItems(elseItems, variables: variables))
                }
            default:
                out.append(item)
            }
        }
        return out
    }

    private func applyEffects(_ effects: [StateEffect]?, to vars: inout [String: StoryValue]) {
        guard let effects else { return }
        for eff in effects {
            let key = eff.var
            let spec = story.manifest.variables[key]
            switch eff.op {
            case .set:
                if let val = eff.value {
                    vars[key] = clampIfInt(val, spec: spec)
                }
            case .add:
                let current = vars[key]?.intValue ?? 0
                let delta = eff.value?.intValue ?? 0
                vars[key] = clampIfInt(.int(current + delta), spec: spec)
            case .clamp:
                if let current = vars[key] {
                    vars[key] = clampIfInt(current, spec: spec)
                }
            }
        }
    }

    private func clampIfInt(_ val: StoryValue, spec: VariableSpec?) -> StoryValue {
        guard case .int(let n) = val else { return val }
        var clamped = n
        if let minVal = spec?.min { clamped = max(minVal, clamped) }
        if let maxVal = spec?.max { clamped = min(maxVal, clamped) }
        return .int(clamped)
    }

    private func scheduleNextRevealTick() {
        revealTask?.cancel()
        guard ticking, let nextEvent = timeline.first(where: { $0.fireDate > currentTime }) else {
            return
        }
        var wakeDate = nextEvent.fireDate
        if let delay = activeDelayEvent, case .delayStart(_, _, let end) = delay.kind {
            wakeDate = min(wakeDate, end)
        }
        let delaySec = max(0.05, wakeDate.timeIntervalSinceNow)
        revealTask = Task { [weak self] in
            let ns = UInt64(delaySec * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
            guard !Task.isCancelled, let self else { return }
            self.syncClock(now: Date(), notify: true)
        }
    }

    private func persist() {
        let state = PersistedSaveState(
            activeStoryID: activeStory.id,
            timeline: timeline,
            variables: variables,
            language: language,
            fontStyle: fontStyle,
            isFastModeUnlocked: false,
            isFastModeEnabled: false,
            isMuted: profile.isMuted,
            unlockedEndings: unlockedEndings,
            sessionID: sessionID
        )
        store.save(state, storyID: activeStory.id)
    }
}
