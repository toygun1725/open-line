import Foundation

#if canImport(ActivityKit)
import ActivityKit

public struct OpenLineActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var phase: String
        public var currentStage: Int
        public var totalStages: Int
        public var stageLabels: [String]
        public var shortTitle: String
        public var statusBody: String
        public var readyTitle: String
        public var iconName: String
        public var integrityPercent: Int
        public var themeID: String
        public var brandTitle: String
        public var metricLabel: String
        public var startDate: Date
        public var endDate: Date

        public init(
            phase: String,
            currentStage: Int,
            totalStages: Int = 4,
            stageLabels: [String],
            shortTitle: String,
            statusBody: String,
            readyTitle: String,
            iconName: String,
            integrityPercent: Int,
            themeID: String = "ice_blue",
            brandTitle: String = "Açık Hat",
            metricLabel: String = "Isı",
            startDate: Date,
            endDate: Date
        ) {
            self.phase = phase
            self.currentStage = currentStage
            self.totalStages = totalStages
            self.stageLabels = stageLabels
            self.shortTitle = shortTitle
            self.statusBody = statusBody
            self.readyTitle = readyTitle
            self.iconName = iconName
            self.integrityPercent = integrityPercent
            self.themeID = themeID
            self.brandTitle = brandTitle
            self.metricLabel = metricLabel
            self.startDate = startDate
            self.endDate = endDate
        }
    }

    public var storyID: String
    public var url: URL? { URL(string: "openline://story/\(storyID)/\(storySessionID)") }
    public var storySessionID: String

    public init(storyID: String, storySessionID: String) {
        self.storyID = storyID
        self.storySessionID = storySessionID
    }
}
#endif
