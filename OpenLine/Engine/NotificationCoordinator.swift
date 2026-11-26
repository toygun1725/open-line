import Foundation
import UserNotifications

struct PlannedNotification: Equatable {
    let identifier: String
    let fireDate: Date
    let title: String
    let body: String
    let storyID: String
    let sessionID: String
}

final class NotificationCoordinator {
    static let maxScheduledSlots = 48
    static let burstWindowSeconds: TimeInterval = 15

    private let center: UNUserNotificationCenter?

    init(center: UNUserNotificationCenter? = .current()) {
        self.center = center
    }

    func requestAuthorizationIfNeeded(onGrant: @escaping @MainActor () -> Void) {
        center?.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted { Task { @MainActor in onGrant() } }
        }
    }

    static func merge(_ plans: [[PlannedNotification]]) -> [PlannedNotification] {
        let active = plans.filter { !$0.isEmpty }
        let reserved = active.flatMap { [$0.first!, $0.last!] }
        let reservedIDs = Set(reserved.map(\.identifier))
        let others = active.flatMap { $0 }.filter { !reservedIDs.contains($0.identifier) }
            .sorted { $0.fireDate < $1.fireDate }
        var seen = Set<String>()
        return (reserved + others).filter { seen.insert($0.identifier).inserted }
            .prefix(maxScheduledSlots).sorted { $0.fireDate < $1.fireDate }
    }

    func schedule(_ plans: [[PlannedNotification]], now: Date) {
        guard let center else { return }
        center.removeAllPendingNotificationRequests()
        let planned = Self.merge(plans)
        for item in planned {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            content.threadIdentifier = item.storyID
            content.userInfo = ["storyID": item.storyID, "sessionID": item.sessionID]
            // Zero external reply actions: tapping opens Açık Hat directly.

            let interval = max(1.0, item.fireDate.timeIntervalSince(now))
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let req = UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger)
            center.add(req)
        }
    }

    /// Pure deterministic planner unit-testable without UNUserNotificationCenter entitlement.
    static func buildPlan(
        from timeline: [ScheduledEvent],
        language: AppLanguage,
        senderName: String = "Açık Hat",
        now: Date, storyID: String, sessionID: String
    ) -> [PlannedNotification] {
        let futureMessages: [(ScheduledEvent, String)] = timeline.compactMap { ev in
            guard ev.fireDate > now else { return nil }
            switch ev.kind {
            case .message(let text, _, _, _):
                let body = StoryLoader.interpolate(text.text(for: language), variables: ev.stateSnapshot)
                return (ev, body)
            default:
                return nil
            }
        }

        guard !futureMessages.isEmpty else { return [] }

        // Burst-coalesce messages firing within < 15 seconds into the latest burst line.
        var coalesced: [(ScheduledEvent, String)] = []
        for entry in futureMessages {
            if let last = coalesced.last,
               entry.0.fireDate.timeIntervalSince(last.0.fireDate) < burstWindowSeconds {
                coalesced[coalesced.count - 1] = entry
            } else {
                coalesced.append(entry)
            }
        }

        // Guarantee the final message (post-delay wakeup push) never drops off the 48-slot cap.
        let capped: [(ScheduledEvent, String)]
        if coalesced.count > maxScheduledSlots {
            let head = Array(coalesced.prefix(maxScheduledSlots - 1))
            let last = coalesced[coalesced.count - 1]
            capped = head + [last]
        } else {
            capped = coalesced
        }

        return capped.map { pair in
            PlannedNotification(
                identifier: "ol_\(storyID)_\(sessionID)_\(pair.0.id.uuidString)",
                fireDate: pair.0.fireDate,
                title: senderName,
                body: pair.1, storyID: storyID, sessionID: sessionID
            )
        }
    }
}
