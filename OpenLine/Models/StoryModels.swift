import Foundation

enum StoryThemeID: String, Codable, CaseIterable, Hashable {
    case iceBlue = "ice_blue"
    case warmRose = "warm_rose"
}

struct StoryEndingMeta: Codable, Hashable {
    let badge: LocalizedText
    let isNegative: Bool
}

struct StoryCatalogEntry: Codable, Identifiable, Hashable {
    let id: String
    let folder: String
    let isFree: Bool
    let theme: StoryThemeID
    let title: LocalizedText
    let subtitle: LocalizedText
    let badge: LocalizedText
    let invitation: LocalizedText
    let synopsis: LocalizedText
    let signalCode: String
    let senderName: LocalizedText
    let waitingHeadline: LocalizedText
    let metricVar: String
    let metricLabel: LocalizedText
    let stageLabels: [LocalizedText]
    let startSimMinutes: Int
    let endings: [String: StoryEndingMeta]
}

struct StoryCatalog: Codable {
    let appTitle: LocalizedText
    let defaultStoryId: String
    let iapProductId: String
    let iapPriceDisplay: LocalizedText
    let stories: [StoryCatalogEntry]
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case tr
    case en

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .tr: return "Türkçe"
        case .en: return "English"
        }
    }

    var shortCode: String { rawValue.uppercased() }
}

enum AdditionalGameFont: String {
    case atkinson, lora, manrope, plexMono

    var title: String {
        switch self {
        case .atkinson: return "Atkinson Hyperlegible Next"
        case .lora: return "Lora"
        case .manrope: return "Manrope"
        case .plexMono: return "IBM Plex Mono"
        }
    }

    var postScriptName: String {
        switch self {
        case .atkinson: return "AtkinsonHyperlegibleNext-Regular"
        case .lora: return "Lora-Regular"
        case .manrope: return "Manrope-Regular"
        case .plexMono: return "IBMPlexMono-Regular"
        }
    }
}

enum AppFontStyle: String, Codable, CaseIterable, Identifiable {
    case editorial
    case typewriter
    case geometric
    case atkinson, lora, manrope, plexMono

    var additionalFont: AdditionalGameFont? { AdditionalGameFont(rawValue: rawValue) }

    var id: String { rawValue }

    func title(for lang: AppLanguage) -> String {
        switch (self, lang) {
        case (.editorial, .tr): return "Editöryal Mürekkep"
        case (.editorial, .en): return "Editorial Ink"
        case (.typewriter, .tr): return "Daktilo Kaydı"
        case (.typewriter, .en): return "Typewriter Record"
        case (.geometric, .tr): return "Teknik Geometrik"
        case (.geometric, .en): return "Technical Geometric"
        default: return additionalFont?.title ?? rawValue
        }
    }
}

enum ReplyFontStyle: String, Codable, CaseIterable, Identifiable {
    case serif
    case sans
    case mono
    case atkinson, lora, manrope, plexMono

    var additionalFont: AdditionalGameFont? { AdditionalGameFont(rawValue: rawValue) }

    var id: String { rawValue }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .serif: return "Serif"
        case .sans: return language == .tr ? "Sade" : "Sans serif"
        case .mono: return language == .tr ? "Eş aralıklı" : "Monospaced"
        default: return additionalFont?.title ?? rawValue
        }
    }
}

struct LocalizedText: Codable, Hashable {
    let tr: String
    let en: String

    func text(for lang: AppLanguage) -> String {
        switch lang {
        case .tr: return tr
        case .en: return en
        }
    }
}

enum StoryValue: Codable, Hashable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Decode Bool before numeric types because NSNumber bridges Bool/Int.
        if let b = try? container.decode(Bool.self) {
            self = .bool(b)
            return
        }
        if let i = try? container.decode(Int.self) {
            self = .int(i)
            return
        }
        if let d = try? container.decode(Double.self) {
            self = .double(d)
            return
        }
        if let s = try? container.decode(String.self) {
            self = .string(s)
            return
        }
        throw DecodingError.typeMismatch(
            StoryValue.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported StoryValue type")
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let b): try container.encode(b)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .string(let s): try container.encode(s)
        }
    }

    var intValue: Int? {
        switch self {
        case .int(let i): return i
        case .double(let d): return Int(d)
        default: return nil
        }
    }

    var stringRepresentation: String {
        switch self {
        case .bool(let b): return b ? "true" : "false"
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .string(let s): return s
        }
    }
}

struct VariableSpec: Codable {
    let type: String
    let `default`: StoryValue
    let min: Int?
    let max: Int?
}

struct CheckpointSpec: Codable, Identifiable, Hashable {
    let id: String
    let nodeId: String
    let title: LocalizedText
}

struct StoryManifest: Codable {
    let storyId: String
    let version: String
    let startNodeId: String
    let checkpoints: [CheckpointSpec]
    let variables: [String: VariableSpec]
}

struct StoryActFile: Codable {
    let act: Int
    let nodes: [StoryNode]
}

struct StoryNode: Codable {
    let id: String
    let act: Int
    let effects: [StateEffect]?
    let items: [StoryItem]
    let transition: StoryTransition
}

struct StateEffect: Codable, Hashable {
    enum Operation: String, Codable {
        case set
        case add
        case clamp
    }

    let `var`: String
    let op: Operation
    let value: StoryValue?
}

enum ConditionOp: String, Codable {
    case eq
    case neq
    case gt
    case gte
    case lt
    case lte
}

indirect enum ConditionExpr: Codable {
    case leaf(varName: String, op: ConditionOp, value: StoryValue)
    case all([ConditionExpr])
    case any([ConditionExpr])

    private enum CodingKeys: String, CodingKey {
        case `var`
        case op
        case value
        case all
        case any
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let allExprs = try container.decodeIfPresent([ConditionExpr].self, forKey: .all) {
            self = .all(allExprs)
            return
        }
        if let anyExprs = try container.decodeIfPresent([ConditionExpr].self, forKey: .any) {
            self = .any(anyExprs)
            return
        }
        let varName = try container.decode(String.self, forKey: .var)
        let op = try container.decode(ConditionOp.self, forKey: .op)
        let val = try container.decode(StoryValue.self, forKey: .value)
        self = .leaf(varName: varName, op: op, value: val)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .all(let exprs):
            try container.encode(exprs, forKey: .all)
        case .any(let exprs):
            try container.encode(exprs, forKey: .any)
        case .leaf(let varName, let op, let value):
            try container.encode(varName, forKey: .var)
            try container.encode(op, forKey: .op)
            try container.encode(value, forKey: .value)
        }
    }

    func evaluate(with variables: [String: StoryValue]) -> Bool {
        switch self {
        case .all(let exprs):
            return exprs.allSatisfy { $0.evaluate(with: variables) }
        case .any(let exprs):
            return exprs.contains { $0.evaluate(with: variables) }
        case .leaf(let varName, let op, let expected):
            guard let actual = variables[varName] else { return false }
            switch op {
            case .eq: return actual == expected
            case .neq: return actual != expected
            case .gt, .gte, .lt, .lte:
                guard let a = actual.intValue, let b = expected.intValue else { return false }
                switch op {
                case .gt: return a > b
                case .gte: return a >= b
                case .lt: return a < b
                case .lte: return a <= b
                default: return false
                }
            }
        }
    }
}

enum StoryItem: Codable {
    case message(MessageItem)
    case system(SystemItem)
    case conditional(ConditionalItem)

    struct MessageItem: Codable {
        let text: LocalizedText
        let typingDelaySec: Double?
        let glitchLevel: Int?
        let haptic: String?
    }

    struct SystemItem: Codable {
        enum Severity: String, Codable {
            case info
            case warning
            case critical
            case success
        }

        let text: LocalizedText
        let severity: Severity
    }

    struct ConditionalItem: Codable {
        let condition: ConditionExpr
        let thenItems: [StoryItem]
        let elseItems: [StoryItem]?
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "message":
            self = .message(try MessageItem(from: decoder))
        case "system":
            self = .system(try SystemItem(from: decoder))
        case "conditional":
            self = .conditional(try ConditionalItem(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown StoryItem type \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .message(let m):
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode("message", forKey: .type)
            try m.encode(to: encoder)
        case .system(let s):
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode("system", forKey: .type)
            try s.encode(to: encoder)
        case .conditional(let cond):
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode("conditional", forKey: .type)
            try cond.encode(to: encoder)
        }
    }
}

struct LiveActivitySpec: Codable, Hashable {
    let phase: String
    let currentStage: Int
    let totalStages: Int
    let stages: [LocalizedText]
    let shortTitle: LocalizedText
    let statusBody: LocalizedText
    let icon: String
}

struct ChoiceOption: Codable, Hashable, Identifiable {
    let id: String
    let label: LocalizedText
    let effects: [StateEffect]?
    let target: String
}

struct ConditionalBranch: Codable {
    let condition: ConditionExpr
    let target: String
}

enum StoryTransition: Codable {
    case next(target: String)
    case conditionalNext(branches: [ConditionalBranch], fallback: String)
    case delay(seconds: Double, target: String, liveActivity: LiveActivitySpec)
    case actBreak(completedAct: Int, nextAct: Int, title: LocalizedText, subtitle: LocalizedText, target: String)
    case choice(choiceKind: String, options: [ChoiceOption])
    case ending(endingId: String, title: LocalizedText, summary: LocalizedText)

    private enum CodingKeys: String, CodingKey {
        case type
        case target
        case branches
        case fallback
        case seconds
        case liveActivity
        case completedAct
        case nextAct
        case subtitle
        case choiceKind
        case options
        case endingId
        case title
        case summary
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "next":
            self = .next(target: try c.decode(String.self, forKey: .target))
        case "conditionalNext":
            self = .conditionalNext(
                branches: try c.decode([ConditionalBranch].self, forKey: .branches),
                fallback: try c.decode(String.self, forKey: .fallback)
            )
        case "delay":
            self = .delay(
                seconds: try c.decode(Double.self, forKey: .seconds),
                target: try c.decode(String.self, forKey: .target),
                liveActivity: try c.decode(LiveActivitySpec.self, forKey: .liveActivity)
            )
        case "actBreak":
            self = .actBreak(
                completedAct: try c.decode(Int.self, forKey: .completedAct),
                nextAct: try c.decode(Int.self, forKey: .nextAct),
                title: try c.decode(LocalizedText.self, forKey: .title),
                subtitle: try c.decode(LocalizedText.self, forKey: .subtitle),
                target: try c.decode(String.self, forKey: .target)
            )
        case "choice":
            self = .choice(
                choiceKind: try c.decode(String.self, forKey: .choiceKind),
                options: try c.decode([ChoiceOption].self, forKey: .options)
            )
        case "ending":
            self = .ending(
                endingId: try c.decode(String.self, forKey: .endingId),
                title: try c.decode(LocalizedText.self, forKey: .title),
                summary: try c.decode(LocalizedText.self, forKey: .summary)
            )
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unknown transition type \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .next(let target):
            try c.encode("next", forKey: .type)
            try c.encode(target, forKey: .target)
        case .conditionalNext(let branches, let fallback):
            try c.encode("conditionalNext", forKey: .type)
            try c.encode(branches, forKey: .branches)
            try c.encode(fallback, forKey: .fallback)
        case .delay(let seconds, let target, let la):
            try c.encode("delay", forKey: .type)
            try c.encode(seconds, forKey: .seconds)
            try c.encode(target, forKey: .target)
            try c.encode(la, forKey: .liveActivity)
        case .actBreak(let completedAct, let nextAct, let title, let subtitle, let target):
            try c.encode("actBreak", forKey: .type)
            try c.encode(completedAct, forKey: .completedAct)
            try c.encode(nextAct, forKey: .nextAct)
            try c.encode(title, forKey: .title)
            try c.encode(subtitle, forKey: .subtitle)
            try c.encode(target, forKey: .target)
        case .choice(let kind, let opts):
            try c.encode("choice", forKey: .type)
            try c.encode(kind, forKey: .choiceKind)
            try c.encode(opts, forKey: .options)
        case .ending(let eid, let title, let summary):
            try c.encode("ending", forKey: .type)
            try c.encode(eid, forKey: .endingId)
            try c.encode(title, forKey: .title)
            try c.encode(summary, forKey: .summary)
        }
    }
}
