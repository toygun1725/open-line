import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct StoryPalette {
    let chassisTop: Color
    let chassisMid: Color
    let chassisBottom: Color
    let windowTop: Color
    let windowBottom: Color
    let windowBorder: Color
    let windowSignal: Color
    let wellBg: Color

    let plateTop: Color
    let plateBottom: Color
    let plateBorder: Color

    let inkPrimary: Color
    let inkHistory: Color
    let inkTelemetry: Color
    let ruleHairline: Color
    let accent: Color

    let keyWhiteTop: Color
    let keyWhiteBottom: Color
    let keyWhiteBorder: Color

    let keyChosenTop: Color
    let keyChosenBottom: Color
    let keyChosenBorder: Color
    let keyChosenSkirt: Color
    let keyChosenText: Color
    let keyStoneText: Color

    let criticalCrimson: Color

    static let iceBlue = StoryPalette(
        chassisTop: Color(red: 0.929, green: 0.961, blue: 0.988),      // #EDF5FC
        chassisMid: Color(red: 0.878, green: 0.925, blue: 0.969),      // #E0ECF7
        chassisBottom: Color(red: 0.824, green: 0.886, blue: 0.945),   // #D2E2F1
        windowTop: Color(red: 0.129, green: 0.216, blue: 0.294),       // #21374B
        windowBottom: Color(red: 0.086, green: 0.169, blue: 0.239),    // #162B3D
        windowBorder: Color.white.opacity(0.23),
        windowSignal: Color(red: 0.608, green: 0.796, blue: 0.906),    // #9BCBE7
        wellBg: Color(red: 0.875, green: 0.918, blue: 0.941),          // #DFEAF0
        plateTop: Color(red: 0.984, green: 0.996, blue: 1.000),
        plateBottom: Color(red: 0.945, green: 0.976, blue: 0.996),     // #F1F9FE
        plateBorder: Color(red: 0.749, green: 0.835, blue: 0.906),     // #BFD5E7
        inkPrimary: Color(red: 0.059, green: 0.110, blue: 0.165),      // #0F1C2A
        inkHistory: Color(red: 0.145, green: 0.220, blue: 0.294),      // #25384B
        inkTelemetry: Color(red: 0.243, green: 0.329, blue: 0.412),    // #3E5469
        ruleHairline: Color(red: 0.710, green: 0.804, blue: 0.886),    // #B5CDE2
        accent: Color(red: 0.082, green: 0.369, blue: 0.584),          // #155E95
        keyWhiteTop: Color.white,
        keyWhiteBottom: Color(red: 0.914, green: 0.953, blue: 0.988),  // #E9F3FC
        keyWhiteBorder: Color(red: 0.639, green: 0.753, blue: 0.851),  // #A3C0D9
        keyChosenTop: Color(red: 0.118, green: 0.451, blue: 0.690),    // #1E73B0
        keyChosenBottom: Color(red: 0.059, green: 0.282, blue: 0.459), // #0F4875
        keyChosenBorder: Color(red: 0.043, green: 0.204, blue: 0.341),
        keyChosenSkirt: Color(red: 0.031, green: 0.149, blue: 0.251),
        keyChosenText: Color(red: 0.969, green: 0.988, blue: 1.000),
        keyStoneText: Color(red: 0.235, green: 0.329, blue: 0.420),
        criticalCrimson: Color(red: 0.722, green: 0.180, blue: 0.165)
    )

    static let warmRose = StoryPalette(
        chassisTop: Color(red: 0.992, green: 0.953, blue: 0.957),      // #FDF3F4
        chassisMid: Color(red: 0.969, green: 0.906, blue: 0.918),      // #F7E7EA
        chassisBottom: Color(red: 0.941, green: 0.859, blue: 0.875),   // #F0DBDF
        windowTop: Color(red: 0.270, green: 0.153, blue: 0.223),       // #452739
        windowBottom: Color(red: 0.220, green: 0.125, blue: 0.184),    // #38202F
        windowBorder: Color.white.opacity(0.23),
        windowSignal: Color(red: 0.898, green: 0.643, blue: 0.671),    // #E5A4AB
        wellBg: Color(red: 0.945, green: 0.886, blue: 0.878),          // #F1E2E0
        plateTop: Color(red: 1.000, green: 0.988, blue: 0.992),
        plateBottom: Color(red: 0.996, green: 0.957, blue: 0.965),     // #FEF4F6
        plateBorder: Color(red: 0.902, green: 0.796, blue: 0.820),     // #E6CBD1
        inkPrimary: Color(red: 0.137, green: 0.067, blue: 0.086),      // #231116
        inkHistory: Color(red: 0.251, green: 0.153, blue: 0.180),      // #40272E
        inkTelemetry: Color(red: 0.388, green: 0.267, blue: 0.298),    // #63444C
        ruleHairline: Color(red: 0.875, green: 0.757, blue: 0.784),    // #DFC1C8
        accent: Color(red: 0.722, green: 0.200, blue: 0.322),          // #B83352
        keyWhiteTop: Color.white,
        keyWhiteBottom: Color(red: 0.984, green: 0.937, blue: 0.945),  // #FBEFF1
        keyWhiteBorder: Color(red: 0.851, green: 0.714, blue: 0.745),  // #D9B6BE
        keyChosenTop: Color(red: 0.800, green: 0.255, blue: 0.384),    // #CC4162
        keyChosenBottom: Color(red: 0.588, green: 0.145, blue: 0.255), // #962541
        keyChosenBorder: Color(red: 0.459, green: 0.106, blue: 0.192),
        keyChosenSkirt: Color(red: 0.349, green: 0.075, blue: 0.141),
        keyChosenText: Color(red: 1.000, green: 0.980, blue: 0.984),
        keyStoneText: Color(red: 0.388, green: 0.267, blue: 0.298),
        criticalCrimson: Color(red: 0.722, green: 0.180, blue: 0.165)
    )

    static func palette(for theme: StoryThemeID) -> StoryPalette {
        switch theme {
        case .iceBlue: return .iceBlue
        case .warmRose: return .warmRose
        }
    }
}

enum AppColors {
    static let inkPrimary = StoryPalette.iceBlue.inkPrimary
    static let criticalCrimson = StoryPalette.iceBlue.criticalCrimson
}

enum AppTypography {
    static func reply(style: ReplyFontStyle) -> Font {
        switch style {
        case .serif: return .system(.subheadline, design: .serif).weight(.semibold)
        case .sans: return .subheadline.weight(.medium)
        case .mono: return .system(.subheadline, design: .monospaced).weight(.medium)
        default:
            guard let added = style.additionalFont else { return .subheadline }
            return .custom(added.postScriptName, size: 15, relativeTo: .subheadline)
        }
    }

    static func narrative(style: AppFontStyle, size: CGFloat = 15, medium: Bool = false) -> Font {
        switch style {
        case .editorial:
            let psName = medium ? "IBMPlexSerif-Medium" : "IBMPlexSerif-Regular"
            return safeCustomFont(name: psName, size: size) ?? .system(size: size, weight: medium ? .medium : .regular, design: .serif)
        case .typewriter:
            let psName = medium ? "CourierPrime-Bold" : "CourierPrime-Regular"
            return safeCustomFont(name: psName, size: size) ?? .system(size: size, weight: medium ? .bold : .regular, design: .monospaced)
        case .geometric:
            return spaceGrotesk(size: size, weight: medium ? .medium : .regular)
        default:
            guard let added = style.additionalFont else { return .system(size: size) }
            return safeCustomFont(name: added.postScriptName, size: size) ?? .system(size: size)
        }
    }

    static func control(style: AppFontStyle, size: CGFloat = 13.5, weight: Font.Weight = .semibold) -> Font {
        switch style {
        case .editorial, .geometric:
            return spaceGrotesk(size: size, weight: weight)
        case .typewriter:
            return safeCustomFont(name: "CourierPrime-Bold", size: size) ?? .system(size: size, weight: .bold, design: .monospaced)
        default:
            guard let added = style.additionalFont else { return .system(size: size, weight: weight) }
            return safeCustomFont(name: added.postScriptName, size: size)?.weight(weight) ?? .system(size: size, weight: weight)
        }
    }

    static func telemetry(size: CGFloat = 12) -> Font {
        (safeCustomFont(name: "CourierPrime-Regular", size: size) ?? .system(size: size, design: .monospaced)).monospacedDigit()
    }

    private static func spaceGrotesk(size: CGFloat, weight: Font.Weight) -> Font {
        #if canImport(UIKit)
        if UIFont(name: "SpaceGrotesk-Light", size: size) != nil {
            return Font.custom("SpaceGrotesk-Light", size: size).weight(weight)
        }
        #endif
        return .system(size: size, weight: weight, design: .default)
    }

    private static func safeCustomFont(name: String, size: CGFloat) -> Font? {
        #if canImport(UIKit)
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        #endif
        return nil
    }
}
