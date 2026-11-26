import XCTest
@testable import OpenLine

@MainActor
final class StoryEngineTests: XCTestCase {
    private func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("OpenLineTests_\(UUID())")
    }

    private func directory(_ root: URL, reward: @escaping @MainActor () async -> RewardResult = { .unavailable }) throws -> LineDirectory {
        try LineDirectory(loader: StoryLoader(bundle: Bundle(for: StoryEngine.self)),
            store: SaveStore(directoryURL: root), notifications: NotificationCoordinator(center: nil),
            devicesEnabled: false, reward: reward)
    }

    func testInboxDoesNotStartClocksAndDecisionsArePermanent() async throws {
        let root = tempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let hub = try directory(root)
        let table = hub.lines[0], ridge = hub.lines[1]
        hub.expandedID = table.activeStory.id
        XCTAssertTrue(hub.lines.allSatisfy { !$0.hasStarted })
        hub.open(ridge)
        XCTAssertTrue(hub.profile.showPaywallSheet)
        XCTAssertFalse(ridge.hasStarted)
        hub.profile.showPaywallSheet = false
        hub.finishPaywall()
        hub.open(table)
        let choice = try XCTUnwrap(table.timeline.last)
        table.selectChoice(eventID: choice.id, optionIndex: 1, now: choice.fireDate)
        let recorded = table.timeline
        table.selectChoice(eventID: choice.id, optionIndex: 0, now: choice.fireDate)
        await table.replay(eventID: choice.id)
        XCTAssertEqual(table.timeline, recorded)
        hub.home()
        let restored = try directory(root)
        XCTAssertNil(restored.conversation)
        XCTAssertEqual(restored.lines[0].sessionID, table.sessionID)
        XCTAssertEqual(restored.lines[0].timeline.first(where: { $0.id == choice.id })?.chosenOptionIndex, 1)
        XCTAssertFalse(restored.lines[1].hasStarted)
        hub.profile.applyAllAccessUnlock()
        hub.open(ridge)
        XCTAssertTrue(ridge.hasStarted)
        hub.route(storyID: table.activeStory.id, sessionID: table.sessionID)
        XCTAssertTrue(hub.conversation === table)
        hub.route(storyID: table.activeStory.id, sessionID: "expired")
        XCTAssertNil(hub.conversation)
        XCTAssertEqual(table.timeline, recorded)
    }

    private func seedEnding(_ root: URL, at date: Date) -> UUID {
        let text = LocalizedText(tr: "Son", en: "End")
        let event = ScheduledEvent(id: UUID(), nodeID: "ending_second_date", act: 3, fireDate: date,
            kind: .ending(endingId: "second_date", title: text, summary: text), stateSnapshot: [:], chosenOptionIndex: nil)
        let saved = PersistedSaveState(activeStoryID: "masa_7", timeline: [event], variables: [:],
            language: .tr, fontStyle: .editorial, isFastModeUnlocked: true, isFastModeEnabled: true,
            isMuted: false, unlockedEndings: ["just_friends"], sessionID: "original")
        SaveStore(directoryURL: root).save(saved, storyID: "masa_7")
        return event.id
    }

    func testReplayRequiresVisibleEndingAndOneEarnedReward() async throws {
        let root = tempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let future = Date().addingTimeInterval(60)
        let eventID = seedEnding(root, at: future)
        var result = RewardResult.cancelled
        var requests = 0
        let hub = try directory(root) {
            requests += 1
            await Task.yield()
            return result
        }
        let table = hub.lines[0]
        await table.replay(eventID: eventID)
        XCTAssertEqual(requests, 0)
        table.syncClock(now: future.addingTimeInterval(1))
        await table.replay(eventID: eventID)
        XCTAssertEqual(table.sessionID, "original")
        result = .unavailable
        await table.replay(eventID: eventID)
        XCTAssertTrue(table.adFailed)
        XCTAssertNotNil(table.visibleEnding)
        result = .earned
        async let first: Void = table.replay(eventID: eventID)
        async let second: Void = table.replay(eventID: eventID)
        _ = await (first, second)
        XCTAssertEqual(requests, 3)
        XCTAssertNotEqual(table.sessionID, "original")
        XCTAssertNil(table.visibleEnding)
        XCTAssertEqual(table.unlockedEndings, ["second_date", "just_friends"])
        XCTAssertFalse(hub.lines[1].hasStarted)
    }

    func testFullAccessReplaysWithoutAdAndKeepsFullWaits() async throws {
        let root = tempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let eventID = seedEnding(root, at: Date().addingTimeInterval(-60))
        let hub = try directory(root) { XCTFail("Paid replay requested an ad"); return .unavailable }
        hub.profile.applyAllAccessUnlock()
        let table = hub.lines[0]
        await table.replay(eventID: eventID)
        for _ in 0..<2 {
            let choice = try XCTUnwrap(table.timeline.last)
            table.selectChoice(eventID: choice.id, optionIndex: 0, now: choice.fireDate)
        }
        let wait = try XCTUnwrap(table.timeline.compactMap { event -> TimeInterval? in
            if case .delayStart(_, let start, let end) = event.kind { return end.timeIntervalSince(start) }
            return nil
        }.first)
        XCTAssertEqual(wait, 240)
    }

    func testNotificationBudgetPreservesBothReturnsAndCoalescesWithinEachStory() {
        let now = Date()
        func plan(_ id: String) -> [PlannedNotification] {
            let events = (0..<72).map { index in
                ScheduledEvent(id: UUID(), nodeID: "n", act: 1,
                    fireDate: now.addingTimeInterval(index == 0 ? 1 : Double(index * 20 - 10)),
                    kind: .message(text: LocalizedText(tr: "\(index)", en: "\(index)"), glitchLevel: 0,
                    haptic: nil, integritySnapshot: 80), stateSnapshot: [:], chosenOptionIndex: nil)
            }
            return NotificationCoordinator.buildPlan(from: events, language: .tr, senderName: id,
                now: now, storyID: id, sessionID: "run")
        }
        let result = NotificationCoordinator.merge([plan("masa_7"), plan("kuzey_sirti")])
        XCTAssertEqual(result.count, 48)
        for id in ["masa_7", "kuzey_sirti"] {
            let items = result.filter { $0.storyID == id }
            XCTAssertEqual(items.first?.body, "1")
            XCTAssertEqual(items.last?.body, "71")
        }
    }
}
