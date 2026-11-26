import Foundation

struct ScheduledEvent: Codable, Identifiable, Hashable {
    enum EventKind: Codable, Hashable {
        case message(
            text: LocalizedText,
            glitchLevel: Int,
            haptic: String?,
            integritySnapshot: Int
        )
        case system(
            text: LocalizedText,
            severity: StoryItem.SystemItem.Severity
        )
        case delayStart(
            liveActivity: LiveActivitySpec,
            startDate: Date,
            endDate: Date
        )
        case actBreakGate(
            completedAct: Int,
            nextAct: Int,
            title: LocalizedText,
            subtitle: LocalizedText,
            target: String,
            isCleared: Bool
        )
        case choicePrompt(
            choiceKind: String,
            options: [ChoiceOption]
        )
        case ending(
            endingId: String,
            title: LocalizedText,
            summary: LocalizedText
        )
    }

    let id: UUID
    let nodeID: String
    let act: Int
    let fireDate: Date
    let kind: EventKind
    let stateSnapshot: [String: StoryValue]
    var chosenOptionIndex: Int?
}

struct PersistedSaveState: Codable {
    var activeStoryID: String?
    var timeline: [ScheduledEvent]
    var variables: [String: StoryValue]
    var language: AppLanguage
    var fontStyle: AppFontStyle
    var isFastModeUnlocked: Bool
    var isFastModeEnabled: Bool
    var isMuted: Bool
    var unlockedEndings: Set<String>
    var sessionID: String
}
