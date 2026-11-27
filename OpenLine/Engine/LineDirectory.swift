import Foundation
import Observation

enum RewardResult: Equatable { case earned, cancelled, unavailable }

@MainActor
@Observable
final class PlayerProfile {
    let catalog: StoryCatalog
    let monetization: MonetizationManager
    let reward: @MainActor () async -> RewardResult
    let sound: SoundEngine?
    let haptics: HapticEngine?
    private let store: SaveStore
    var language: AppLanguage { didSet { persist() } }
    var fontStyle: AppFontStyle { didSet { persist() } }
    var replyFontStyle: ReplyFontStyle { didSet { persist() } }
    var isMuted: Bool { didSet { sound?.isMuted = isMuted; persist() } }
    private(set) var isAllAccessUnlocked: Bool
    var showPaywallSheet = false

    init(catalog: StoryCatalog, store: SaveStore, monetization: MonetizationManager,
         sound: SoundEngine?, haptics: HapticEngine?, reward: @escaping @MainActor () async -> RewardResult) {
        self.catalog = catalog
        self.store = store
        self.monetization = monetization
        self.sound = sound
        self.haptics = haptics
        self.reward = reward
        let saved = store.loadPreferences()
        language = saved?.language ?? (Locale.current.language.languageCode?.identifier == "en" ? .en : .tr)
        fontStyle = saved?.fontStyle ?? .editorial
        replyFontStyle = saved?.replyFontStyle ?? .serif
        isMuted = saved?.isMuted ?? false
        isAllAccessUnlocked = saved?.isAllAccessUnlocked ?? false
        sound?.isMuted = isMuted
    }

    func applyAllAccessUnlock() {
        isAllAccessUnlocked = true
        showPaywallSheet = false
        persist()
    }

    private func persist() {
        store.savePreferences(AppPreferences(activeStoryID: catalog.defaultStoryId, language: language,
            fontStyle: fontStyle, replyFontStyle: replyFontStyle, isMuted: isMuted, isAllAccessUnlocked: isAllAccessUnlocked))
    }
}

@MainActor
@Observable
final class LineDirectory {
    let profile: PlayerProfile
    let lines: [StoryEngine]
    let notifications: NotificationCoordinator
    private(set) var conversation: StoryEngine?
    var expandedID: String?
    private var requestedAccessFor: String?

    init(loader: StoryLoader = StoryLoader(), store: SaveStore = SaveStore(),
         notifications: NotificationCoordinator = NotificationCoordinator(), devicesEnabled: Bool = true,
         reward: (@MainActor () async -> RewardResult)? = nil) throws {
        let catalog = try loader.loadCatalog()
        let commerce = MonetizationManager()
        let player = PlayerProfile(catalog: catalog, store: store, monetization: commerce,
            sound: devicesEnabled ? SoundEngine() : nil, haptics: devicesEnabled ? HapticEngine() : nil,
            reward: reward ?? { await commerce.watchRewardedAd() })
        profile = player
        self.notifications = notifications
        let activities = devicesEnabled ? LiveActivityManager() : nil
        lines = try catalog.stories.map { entry in
            StoryEngine(entry: entry, story: try loader.loadStory(folder: entry.folder),
                profile: player, store: store, activities: activities, ticking: devicesEnabled)
        }
        for line in lines {
            line.onScheduleChange = { [weak self] in self?.scheduleNotifications() }
        }
    }

    func open(_ line: StoryEngine) {
        guard line.activeStory.isFree || profile.isAllAccessUnlocked else {
            requestedAccessFor = line.activeStory.id
            profile.showPaywallSheet = true
            return
        }
        let firstConnection = !lines.contains(where: { $0.hasStarted })
        line.connect()
        conversation = line
        expandedID = nil
        if firstConnection {
            notifications.requestAuthorizationIfNeeded { [weak self] in self?.scheduleNotifications() }
        }
    }

    func home() {
        conversation = nil
        expandedID = nil
    }

    func route(storyID: String, sessionID: String) {
        guard let line = lines.first(where: { $0.activeStory.id == storyID && $0.hasStarted }),
              line.sessionID == sessionID else { home(); return }
        open(line)
    }

    func finishPaywall() {
        defer { requestedAccessFor = nil }
        if profile.isAllAccessUnlocked {
            sync()
            if let line = lines.first(where: { $0.activeStory.id == requestedAccessFor }) { open(line) }
        }
    }

    func sync(now: Date = Date()) { for line in lines { line.syncClock(now: now) } }

    func prepareForBackground() {
        for line in lines where line.hasStarted { line.prepareForBackground() }
        scheduleNotifications()
        home()
    }

    func scheduleNotifications(now: Date = Date()) {
        let plans = lines.filter(\.hasStarted).map { line in
            NotificationCoordinator.buildPlan(from: line.timeline, language: profile.language,
                senderName: line.activeStory.senderName.text(for: profile.language), now: now,
                storyID: line.activeStory.id, sessionID: line.sessionID)
        }
        notifications.schedule(plans, now: now)
    }
}
