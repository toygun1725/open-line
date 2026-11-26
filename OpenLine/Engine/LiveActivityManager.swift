import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
final class LiveActivityManager {
    private let isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func startOrUpdate(
        spec: LiveActivitySpec,
        startDate: Date,
        endDate: Date,
        integrityPercent: Int,
        themeID: String,
        brandTitle: String,
        metricLabel: String,
        storyID: String,
        sessionID: String,
        language: AppLanguage
    ) async {
        guard isEnabled else { return }
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        guard #available(iOS 17.0, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = OpenLineActivityAttributes.ContentState(
            phase: spec.phase,
            currentStage: spec.currentStage,
            totalStages: spec.totalStages,
            stageLabels: spec.stages.map { $0.text(for: language) },
            shortTitle: spec.shortTitle.text(for: language),
            statusBody: spec.statusBody.text(for: language),
            readyTitle: language == .tr ? "Hazır — Yeni mesaj var" : "Ready — New message",
            iconName: spec.icon,
            integrityPercent: integrityPercent,
            themeID: themeID,
            brandTitle: brandTitle,
            metricLabel: metricLabel,
            startDate: startDate,
            endDate: endDate
        )

        let content = ActivityContent(state: state, staleDate: endDate)

        if let existing = Activity<OpenLineActivityAttributes>.activities.first(where: { $0.attributes.storySessionID == sessionID }) {
            await existing.update(content)
        } else {
            let attrs = OpenLineActivityAttributes(storyID: storyID, storySessionID: sessionID)
            _ = try? Activity.request(attributes: attrs, content: content, pushType: nil)
        }
        #endif
    }

    func end(sessionID: String) async {
        guard isEnabled else { return }
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        guard #available(iOS 17.0, *) else { return }
        for activity in Activity<OpenLineActivityAttributes>.activities where activity.attributes.storySessionID == sessionID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        #endif
    }
}
