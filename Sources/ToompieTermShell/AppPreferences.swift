import AppKit
import Combine
import Foundation
import SwiftTerm
import SwiftUI

enum TerminalCursorStyle: String, CaseIterable, Identifiable {
    case block
    case bar
    case underline

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .block: return "cursor.block"
        case .bar: return "cursor.bar"
        case .underline: return "cursor.underline"
        }
    }

    var swiftTermStyle: CursorStyle {
        switch self {
        case .block: return .steadyBlock
        case .bar: return .steadyBar
        case .underline: return .steadyUnderline
        }
    }
}

enum AppBackgroundMode: String, CaseIterable, Identifiable {
    case native
    case solid
    case gradient
    case image
    case animated
    case gif

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .native: return "bg.native"
        case .solid: return "bg.solid"
        case .gradient: return "bg.gradient"
        case .image: return "bg.image"
        case .animated: return "bg.animated"
        case .gif: return "bg.gif"
        }
    }
}

enum UIScheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var labelKey: String { "scheme.\(rawValue)" }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct UIThemePreset: Identifiable {
    let id: String
    let name: String
    let accent: String
    let foreground: String
    let background: String
    let gradientTop: String
    let gradientBottom: String
    let effects: [WeatherEffect]
    var mode: AppBackgroundMode = .gradient
    var live: LiveBackground? = nil

    static let all: [UIThemePreset] = [
        UIThemePreset(id: "system", name: "System", accent: "#5E9EFF", foreground: "#E1E6EC", background: "#12141B", gradientTop: "#161B2E", gradientBottom: "#080A12", effects: [], mode: .native),
        UIThemePreset(id: "midnight", name: "Midnight", accent: "#5E9EFF", foreground: "#E1E6EC", background: "#0B0E14", gradientTop: "#10131C", gradientBottom: "#06070B", effects: []),
        UIThemePreset(id: "carbon", name: "Carbon", accent: "#9AA4B2", foreground: "#D8DEE9", background: "#0B0C10", gradientTop: "#15171C", gradientBottom: "#08090C", effects: []),
        UIThemePreset(id: "obsidian", name: "Obsidian", accent: "#7C5CFF", foreground: "#E6E1FF", background: "#0A0A12", gradientTop: "#14122A", gradientBottom: "#070710", effects: []),
        UIThemePreset(id: "tokyonight", name: "Tokyo Night", accent: "#7AA2F7", foreground: "#C0CAF5", background: "#16161E", gradientTop: "#1F2335", gradientBottom: "#101019", effects: []),
        UIThemePreset(id: "crimson", name: "Crimson", accent: "#FF4D5E", foreground: "#F6DADD", background: "#120708", gradientTop: "#241013", gradientBottom: "#0B0405", effects: [.embers]),
        UIThemePreset(id: "forest", name: "Forest", accent: "#4ADE80", foreground: "#D6F5E0", background: "#08130D", gradientTop: "#0F2418", gradientBottom: "#050B08", effects: []),
        UIThemePreset(id: "mono", name: "Mono", accent: "#B6B6BE", foreground: "#E4E4E8", background: "#0E0E10", gradientTop: "#18181C", gradientBottom: "#0A0A0C", effects: []),
        UIThemePreset(id: "matrix", name: "Matrix", accent: "#39FF14", foreground: "#39FF14", background: "#020902", gradientTop: "#04130A", gradientBottom: "#000300", effects: [.matrix]),
        UIThemePreset(id: "synthwave", name: "Synthwave", accent: "#FF2E97", foreground: "#F8E6FF", background: "#160A24", gradientTop: "#26104A", gradientBottom: "#0C0518", effects: [.bokeh]),
        UIThemePreset(id: "nord", name: "Nord", accent: "#88C0D0", foreground: "#D8DEE9", background: "#222730", gradientTop: "#2E3440", gradientBottom: "#1B1F26", effects: []),
        UIThemePreset(id: "ocean", name: "Ocean", accent: "#4FC3F7", foreground: "#CDE7FF", background: "#06121F", gradientTop: "#0A2438", gradientBottom: "#040C16", effects: [.bubbles]),
        UIThemePreset(id: "ember", name: "Ember", accent: "#FF7A18", foreground: "#FFE8D6", background: "#150B06", gradientTop: "#2A160C", gradientBottom: "#0A0503", effects: [.embers]),
        UIThemePreset(id: "sakura", name: "Sakura", accent: "#FF7EB6", foreground: "#FFF0F5", background: "#1E141A", gradientTop: "#321F2B", gradientBottom: "#130C11", effects: [.petals]),
        // Editor-inspired palettes
        UIThemePreset(id: "dracula", name: "Dracula", accent: "#BD93F9", foreground: "#F8F8F2", background: "#282A36", gradientTop: "#343746", gradientBottom: "#1E1F29", effects: []),
        UIThemePreset(id: "gruvbox", name: "Gruvbox", accent: "#FABD2F", foreground: "#EBDBB2", background: "#282828", gradientTop: "#3C3836", gradientBottom: "#1D2021", effects: []),
        UIThemePreset(id: "solarized", name: "Solarized", accent: "#268BD2", foreground: "#93A1A1", background: "#002B36", gradientTop: "#073642", gradientBottom: "#00212B", effects: []),
        UIThemePreset(id: "catppuccin", name: "Catppuccin", accent: "#CBA6F7", foreground: "#CDD6F4", background: "#1E1E2E", gradientTop: "#302D41", gradientBottom: "#181825", effects: []),
        UIThemePreset(id: "rosepine", name: "Rosé Pine", accent: "#EBBCBA", foreground: "#E0DEF4", background: "#191724", gradientTop: "#26233A", gradientBottom: "#12101C", effects: []),
        UIThemePreset(id: "everforest", name: "Everforest", accent: "#A7C080", foreground: "#D3C6AA", background: "#2B3339", gradientTop: "#374247", gradientBottom: "#1E2326", effects: []),
        // Live / effect-forward presets
        UIThemePreset(id: "lava", name: "Lava Lamp", accent: "#FF6A3D", foreground: "#FFE8D6", background: "#120604", gradientTop: "#2A0E06", gradientBottom: "#070302", effects: [], mode: .animated, live: .lavalamp),
        UIThemePreset(id: "auroraNight", name: "Aurora", accent: "#5EEAD4", foreground: "#D7FFF5", background: "#04121A", gradientTop: "#0A2A33", gradientBottom: "#030A10", effects: [], mode: .animated, live: .aurora),
        UIThemePreset(id: "deepspace", name: "Deep Space", accent: "#8B9CFF", foreground: "#DCE2FF", background: "#04040C", gradientTop: "#0B1030", gradientBottom: "#020208", effects: [.stars], mode: .animated, live: .starfield),
        UIThemePreset(id: "vaporwave", name: "Vaporwave", accent: "#FF6AD5", foreground: "#FFF0FB", background: "#1A0B2E", gradientTop: "#3B1466", gradientBottom: "#0E0420", effects: [], mode: .animated, live: .gradientFlow),
        // New live-background + weather showcase themes
        UIThemePreset(id: "cybergrid", name: "Cyber Grid", accent: "#FF2E97", foreground: "#F8E6FF", background: "#0A0118", gradientTop: "#2A0A4A", gradientBottom: "#060010", effects: [.matrix], mode: .animated, live: .grid),
        UIThemePreset(id: "sunbeam", name: "Sunbeam", accent: "#FFC24B", foreground: "#FFF3DD", background: "#1A1206", gradientTop: "#3A2A0E", gradientBottom: "#0C0803", effects: [.dust], mode: .animated, live: .rays),
        UIThemePreset(id: "silkroad", name: "Silk Road", accent: "#E0A86B", foreground: "#FBEFE0", background: "#160F0A", gradientTop: "#2E2014", gradientBottom: "#0A0705", effects: [.pollen], mode: .animated, live: .silk),
        UIThemePreset(id: "kaleido", name: "Kaleido", accent: "#B388FF", foreground: "#F2EBFF", background: "#0E0820", gradientTop: "#241452", gradientBottom: "#060312", effects: [.glitter], mode: .animated, live: .kaleidoscope),
        UIThemePreset(id: "koipond", name: "Koi Pond", accent: "#FF8FA3", foreground: "#EAF6FF", background: "#06141A", gradientTop: "#0C2A33", gradientBottom: "#040E12", effects: [.blossoms], mode: .animated, live: .ripplePool),
        UIThemePreset(id: "prismatic", name: "Prismatic", accent: "#5EEAD4", foreground: "#FFFFFF", background: "#0A0A12", gradientTop: "#1A1230", gradientBottom: "#05050A", effects: [.sparkles], mode: .animated, live: .prism),
        UIThemePreset(id: "meteorshower", name: "Meteor Shower", accent: "#8B9CFF", foreground: "#DCE2FF", background: "#03030A", gradientTop: "#0A1030", gradientBottom: "#010106", effects: [.meteors, .stars], mode: .animated, live: .starfield),
        UIThemePreset(id: "volcano", name: "Volcano", accent: "#FF5126", foreground: "#FFE3D0", background: "#140503", gradientTop: "#320C04", gradientBottom: "#080201", effects: [.cinders], mode: .animated, live: .lavalamp),
        UIThemePreset(id: "beegarden", name: "Bee Garden", accent: "#FFD23F", foreground: "#FBF4D8", background: "#0C1206", gradientTop: "#1E2E10", gradientBottom: "#060A03", effects: [.fireflies, .pollen], mode: .gradient),
        UIThemePreset(id: "comettrail", name: "Comet Trail", accent: "#7AE1FF", foreground: "#E5FAFF", background: "#03060C", gradientTop: "#0A1A2E", gradientBottom: "#01030A", effects: [.comets], mode: .animated, live: .starfield),
        UIThemePreset(id: "enchanted", name: "Enchanted", accent: "#9D7BFF", foreground: "#ECE6FF", background: "#08060F", gradientTop: "#1A1238", gradientBottom: "#050410", effects: [.wisps, .fireflies], mode: .animated, live: .nebula),
        UIThemePreset(id: "disco", name: "Disco Fever", accent: "#FF6AD5", foreground: "#FFF0FB", background: "#14071E", gradientTop: "#3A1255", gradientBottom: "#0A0414", effects: [.confetti], mode: .animated, live: .gradientFlow),
        UIThemePreset(id: "frostbite", name: "Frostbite", accent: "#8FD8FF", foreground: "#EAF7FF", background: "#050E16", gradientTop: "#0C2436", gradientBottom: "#03080F", effects: [.snowstorm], mode: .animated, live: .waves),
        UIThemePreset(id: "sporebloom", name: "Spore Bloom", accent: "#5EFF9E", foreground: "#E6FFF0", background: "#04120A", gradientTop: "#0C2A18", gradientBottom: "#020A06", effects: [.spores], mode: .animated, live: .plasma)
    ]
}

enum WeatherEffect: String, CaseIterable, Identifiable {
    case off
    case snow
    case rain
    case stars
    case sparkles
    case confetti
    case bubbles
    case fireflies
    case leaves
    case embers
    case hearts
    case matrix
    case petals
    case bokeh
    case dust
    case fog
    case meteors
    case lanterns
    case glitter
    case aurora
    case fireworks
    case smoke
    case ripples
    case rainbow
    case snowstorm
    case blossoms
    case cinders
    case pollen
    case comets
    case spores
    case wisps

    var id: String { rawValue }

    var labelKey: String { "weather.\(rawValue)" }

    var icon: String {
        switch self {
        case .off: return "nosign"
        case .snow: return "snowflake"
        case .rain: return "cloud.rain"
        case .stars: return "star"
        case .sparkles: return "sparkles"
        case .confetti: return "party.popper"
        case .bubbles: return "bubbles.and.sparkles"
        case .fireflies: return "lightbulb.min"
        case .leaves: return "leaf"
        case .embers: return "flame"
        case .hearts: return "heart"
        case .matrix: return "chevron.left.forwardslash.chevron.right"
        case .petals: return "camera.macro"
        case .bokeh: return "circle.hexagongrid"
        case .dust: return "wind"
        case .fog: return "cloud.fog.fill"
        case .meteors: return "moon.stars.fill"
        case .lanterns: return "lightbulb.fill"
        case .glitter: return "sparkle"
        case .aurora: return "sun.haze.fill"
        case .fireworks: return "fireworks"
        case .smoke: return "smoke.fill"
        case .ripples: return "dot.radiowaves.left.and.right"
        case .rainbow: return "rainbow"
        case .snowstorm: return "wind.snow"
        case .blossoms: return "fan.fill"
        case .cinders: return "flame.fill"
        case .pollen: return "aqi.low"
        case .comets: return "wand.and.rays"
        case .spores: return "circle.grid.cross.fill"
        case .wisps: return "humidity.fill"
        }
    }

    /// Effects whose particles read well recolored to a single user-chosen tint.
    /// Multi-color effects (confetti, fireworks, rainbow, aurora) and rain are
    /// excluded — a single tint would defeat their look.
    var tintable: Bool {
        switch self {
        case .off, .rain, .confetti, .fireworks, .rainbow, .aurora: return false
        default: return true
        }
    }
}

/// Global wind direction for the particle weather overlay. `.natural` keeps each
/// effect's hand-tuned motion; the compass cases add a steady wind force (scaled by
/// `weatherWind`) that pushes every particle the same way, so rain can slant, snow
/// can drift sideways, embers can lean, etc.
enum WeatherDirection: String, CaseIterable, Identifiable {
    case natural
    case down
    case up
    case left
    case right
    case downLeft
    case downRight
    case upLeft
    case upRight

    var id: String { rawValue }
    var labelKey: String { "wind.\(rawValue)" }

    var icon: String {
        switch self {
        case .natural: return "wind"
        case .down: return "arrow.down"
        case .up: return "arrow.up"
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        case .downLeft: return "arrow.down.left"
        case .downRight: return "arrow.down.right"
        case .upLeft: return "arrow.up.left"
        case .upRight: return "arrow.up.right"
        }
    }

    /// Unit-ish wind vector. NOTE: the weather overlay's NSView is *not* flipped, so
    /// +y points up and −y points down (matching CAEmitterCell acceleration).
    var vector: CGVector {
        let d = 0.7071 // diagonal component so combined directions stay ~unit length
        switch self {
        case .natural: return .zero
        case .down: return CGVector(dx: 0, dy: -1)
        case .up: return CGVector(dx: 0, dy: 1)
        case .left: return CGVector(dx: -1, dy: 0)
        case .right: return CGVector(dx: 1, dy: 0)
        case .downLeft: return CGVector(dx: -d, dy: -d)
        case .downRight: return CGVector(dx: d, dy: -d)
        case .upLeft: return CGVector(dx: -d, dy: d)
        case .upRight: return CGVector(dx: d, dy: d)
        }
    }
}

enum TextCaseStyle: String, CaseIterable, Identifiable {
    case standard
    case large
    case lower

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .standard: return "case.default"
        case .large: return "case.large"
        case .lower: return "case.lower"
        }
    }
}

struct TerminalTheme: Identifiable {
    let id: String
    let name: String
    let foreground: String
    let background: String

    static let all: [TerminalTheme] = [
        TerminalTheme(id: "midnight", name: "Midnight", foreground: "#E1E6EC", background: "#12141B"),
        TerminalTheme(id: "carbon", name: "Carbon", foreground: "#D8DEE9", background: "#0B0C10"),
        TerminalTheme(id: "dracula", name: "Dracula", foreground: "#F8F8F2", background: "#282A36"),
        TerminalTheme(id: "nord", name: "Nord", foreground: "#D8DEE9", background: "#2E3440"),
        TerminalTheme(id: "solarized", name: "Solarized", foreground: "#93A1A1", background: "#002B36"),
        TerminalTheme(id: "gruvbox", name: "Gruvbox", foreground: "#EBDBB2", background: "#282828"),
        TerminalTheme(id: "ocean", name: "Ocean", foreground: "#CDD6F4", background: "#101426"),
        TerminalTheme(id: "matrix", name: "Matrix", foreground: "#39FF14", background: "#020902")
    ]
}

@MainActor
final class AppPreferences: ObservableObject {
    static let shared = AppPreferences()

    @Published var revision = 0

    @Published var fontFamily: String { didSet { store(fontFamily, "fontFamily") } }
    @Published var fontSize: Double { didSet { store(fontSize, "fontSize") } }
    @Published var cursorStyle: TerminalCursorStyle { didSet { store(cursorStyle.rawValue, "cursorStyle") } }
    @Published var foregroundHex: String { didSet { store(foregroundHex, "foregroundHex") } }
    @Published var backgroundHex: String { didSet { store(backgroundHex, "backgroundHex") } }
    @Published var caretHex: String { didSet { store(caretHex, "caretHex") } }
    @Published var terminalOpacity: Double { didSet { store(terminalOpacity, "terminalOpacity") } }
    @Published var backgroundMode: AppBackgroundMode { didSet { store(backgroundMode.rawValue, "backgroundMode") } }
    @Published var windowColorHex: String { didSet { store(windowColorHex, "windowColorHex") } }
    @Published var gradientTopHex: String { didSet { store(gradientTopHex, "gradientTopHex") } }
    @Published var gradientBottomHex: String { didSet { store(gradientBottomHex, "gradientBottomHex") } }
    @Published var backgroundImagePath: String { didSet { store(backgroundImagePath, "backgroundImagePath") } }
    @Published var confirmDangerous: Bool { didSet { store(confirmDangerous, "confirmDangerous") } }
    @Published var disableAntialiasing: Bool { didSet { store(disableAntialiasing, "disableAntialiasing") } }
    @Published var textCase: TextCaseStyle { didSet { store(textCase.rawValue, "textCase") } }
    @Published var gifPath: String { didSet { store(gifPath, "gifPath") } }
    @Published var sshKeyDirectory: String { didSet { store(sshKeyDirectory, "sshKeyDirectory") } }
    @Published var defaultUser: String { didSet { store(defaultUser, "defaultUser") } }
    @Published var defaultPort: Int { didSet { store(defaultPort, "defaultPort") } }
    @Published var defaultEditor: String { didSet { store(defaultEditor, "defaultEditor") } }
    @Published var defaultWorkingDir: String { didSet { store(defaultWorkingDir, "defaultWorkingDir") } }
    @Published var accentHex: String { didSet { store(accentHex, "accentHex") } }
    @Published var gifSize: Double { didSet { store(gifSize, "gifSize") } }
    @Published var gifOpacity: Double { didSet { store(gifOpacity, "gifOpacity") } }
    @Published var gifCornerRadius: Double { didSet { store(gifCornerRadius, "gifCornerRadius") } }
    @Published var gifBorder: Bool { didSet { store(gifBorder, "gifBorder") } }
    @Published var gifFit: Bool { didSet { store(gifFit, "gifFit") } }
    @Published var gifShowBox: Bool { didSet { store(gifShowBox, "gifShowBox") } }
    @Published var gifBoxOpacity: Double { didSet { store(gifBoxOpacity, "gifBoxOpacity") } }
    @Published var gifOffsetX: Double { didSet { store(gifOffsetX, "gifOffsetX") } }
    @Published var gifOffsetY: Double { didSet { store(gifOffsetY, "gifOffsetY") } }
    @Published var gifInnerScale: Double { didSet { store(gifInnerScale, "gifInnerScale") } }
    @Published var gifEditable: Bool { didSet { store(gifEditable, "gifEditable") } }
    @Published var gifRotation: Double { didSet { store(gifRotation, "gifRotation") } }
    @Published var gifFlip: Bool { didSet { store(gifFlip, "gifFlip") } }
    @Published var crtMode: Bool { didSet { store(crtMode, "crtMode") } }
    @Published var graphicsModeRaw: String { didSet { store(graphicsModeRaw, "graphicsMode") } }
    @Published var weatherDirectionRaw: String { didSet { store(weatherDirectionRaw, "weatherDirection") } }
    @Published var weatherWind: Double { didSet { store(weatherWind, "weatherWind") } }
    @Published var schemeRaw: String { didSet { store(schemeRaw, "uiScheme") } }
    @Published var shellPath: String { didSet { store(shellPath, "shellPath") } }
    @Published var shellStartupCommand: String { didSet { store(shellStartupCommand, "shellStartupCommand") } }
    @Published var loginShell: Bool { didSet { store(loginShell, "loginShell") } }
    @Published var effectsRaw: String { didSet { store(effectsRaw, "activeEffects") } }
    @Published var bgInvert: Bool { didSet { store(bgInvert, "bgInvert") } }
    @Published var bgGrayscale: Bool { didSet { store(bgGrayscale, "bgGrayscale") } }
    @Published var bgBlur: Double { didSet { store(bgBlur, "bgBlur") } }
    @Published var bgBrightness: Double { didSet { store(bgBrightness, "bgBrightness") } }
    @Published var bgDim: Double { didSet { store(bgDim, "bgDim") } }
    @Published var bgSaturation: Double { didSet { store(bgSaturation, "bgSaturation") } }
    @Published var bgVignette: Double { didSet { store(bgVignette, "bgVignette") } }
    @Published var bgGrain: Double { didSet { store(bgGrain, "bgGrain") } }
    @Published var bgScanlines: Bool { didSet { store(bgScanlines, "bgScanlines") } }
    @Published var liveBackgroundRaw: String { didSet { store(liveBackgroundRaw, "liveBackground") } }
    @Published var bgEffectSpeed: Double { didSet { store(bgEffectSpeed, "bgEffectSpeed") } }
    @Published var bgEffectIntensity: Double { didSet { store(bgEffectIntensity, "bgEffectIntensity") } }
    @Published var backgroundGifPath: String { didSet { store(backgroundGifPath, "backgroundGifPath") } }
    @Published var effectTintsRaw: String { didSet { store(effectTintsRaw, "effectTints") } }
    @Published var defaultCommitMessage: String { didSet { store(defaultCommitMessage, "defaultCommitMessage") } }
    @Published var paletteCategoryOrderRaw: String { didSet { store(paletteCategoryOrderRaw, "paletteCategoryOrder") } }
    /// Master switch that makes the ambient, always-on animations (the floating
    /// decor blobs, the rotating focus border, the running-tab pulse) hold still.
    /// Off by default; flipping it on is the single biggest idle-CPU/GPU saving.
    @Published var reduceMotion: Bool { didSet { store(reduceMotion, "reduceMotion") } }

    private let defaults = UserDefaults.standard

    private init() {
        let d = UserDefaults.standard
        fontFamily = d.string(forKey: "fontFamily") ?? ""
        let size = d.double(forKey: "fontSize")
        fontSize = size == 0 ? 13 : size
        cursorStyle = TerminalCursorStyle(rawValue: d.string(forKey: "cursorStyle") ?? "") ?? .block
        foregroundHex = d.string(forKey: "foregroundHex") ?? "#E1E6EC"
        backgroundHex = d.string(forKey: "backgroundHex") ?? "#12141B"
        caretHex = d.string(forKey: "caretHex") ?? "#39E08B"
        let opacity = d.double(forKey: "terminalOpacity")
        terminalOpacity = opacity == 0 ? 1.0 : opacity
        backgroundMode = AppBackgroundMode(rawValue: d.string(forKey: "backgroundMode") ?? "") ?? .native
        windowColorHex = d.string(forKey: "windowColorHex") ?? "#0B0E14"
        gradientTopHex = d.string(forKey: "gradientTopHex") ?? "#161B2E"
        gradientBottomHex = d.string(forKey: "gradientBottomHex") ?? "#080A12"
        backgroundImagePath = d.string(forKey: "backgroundImagePath") ?? ""
        confirmDangerous = d.object(forKey: "confirmDangerous") == nil ? true : d.bool(forKey: "confirmDangerous")
        disableAntialiasing = d.bool(forKey: "disableAntialiasing")
        textCase = TextCaseStyle(rawValue: d.string(forKey: "textCase") ?? "") ?? .standard
        gifPath = d.string(forKey: "gifPath") ?? ""
        sshKeyDirectory = d.string(forKey: "sshKeyDirectory") ?? (FileManager.default.homeDirectoryForCurrentUser.path + "/.ssh")
        defaultUser = d.string(forKey: "defaultUser") ?? NSUserName()
        let port = d.integer(forKey: "defaultPort")
        defaultPort = port == 0 ? 22 : port
        defaultEditor = d.string(forKey: "defaultEditor") ?? "nano"
        defaultWorkingDir = d.string(forKey: "defaultWorkingDir") ?? ""
        accentHex = d.string(forKey: "accentHex") ?? "#FF5F6D"
        let gs = d.double(forKey: "gifSize")
        gifSize = gs == 0 ? 110 : gs
        let go = d.double(forKey: "gifOpacity")
        gifOpacity = go == 0 ? 1.0 : go
        gifCornerRadius = d.object(forKey: "gifCornerRadius") == nil ? 14 : d.double(forKey: "gifCornerRadius")
        gifBorder = d.bool(forKey: "gifBorder")
        gifFit = d.object(forKey: "gifFit") == nil ? true : d.bool(forKey: "gifFit")
        gifShowBox = d.object(forKey: "gifShowBox") == nil ? true : d.bool(forKey: "gifShowBox")
        gifBoxOpacity = d.double(forKey: "gifBoxOpacity")
        gifOffsetX = d.double(forKey: "gifOffsetX")
        gifOffsetY = d.double(forKey: "gifOffsetY")
        let innerScale = d.double(forKey: "gifInnerScale")
        gifInnerScale = innerScale == 0 ? 1.0 : innerScale
        gifEditable = d.bool(forKey: "gifEditable")
        gifRotation = d.double(forKey: "gifRotation")
        gifFlip = d.bool(forKey: "gifFlip")
        if let stored = d.string(forKey: "activeEffects") {
            effectsRaw = stored
        } else if let legacy = d.string(forKey: "weatherEffect"), legacy != "off", !legacy.isEmpty {
            effectsRaw = legacy
        } else {
            effectsRaw = ""
        }
        bgInvert = d.bool(forKey: "bgInvert")
        bgGrayscale = d.bool(forKey: "bgGrayscale")
        bgBlur = d.double(forKey: "bgBlur")
        bgBrightness = d.double(forKey: "bgBrightness")
        // Defaults to 0: bgDim is now a universal post-processing filter applied to
        // every background mode, so it must start neutral (like blur/vignette/grain)
        // rather than silently darkening existing solid/gradient setups on upgrade.
        bgDim = d.double(forKey: "bgDim")
        bgSaturation = d.object(forKey: "bgSaturation") == nil ? 1.0 : d.double(forKey: "bgSaturation")
        bgVignette = d.double(forKey: "bgVignette")
        bgGrain = d.double(forKey: "bgGrain")
        bgScanlines = d.bool(forKey: "bgScanlines")
        liveBackgroundRaw = d.string(forKey: "liveBackground") ?? LiveBackground.aurora.rawValue
        bgEffectSpeed = d.object(forKey: "bgEffectSpeed") == nil ? 1.0 : d.double(forKey: "bgEffectSpeed")
        bgEffectIntensity = d.object(forKey: "bgEffectIntensity") == nil ? 0.7 : d.double(forKey: "bgEffectIntensity")
        backgroundGifPath = d.string(forKey: "backgroundGifPath") ?? ""
        effectTintsRaw = d.string(forKey: "effectTints") ?? ""
        defaultCommitMessage = d.string(forKey: "defaultCommitMessage") ?? ""
        paletteCategoryOrderRaw = d.string(forKey: "paletteCategoryOrder") ?? ""
        reduceMotion = d.bool(forKey: "reduceMotion")
        crtMode = d.bool(forKey: "crtMode")
        graphicsModeRaw = d.string(forKey: "graphicsMode") ?? GraphicsMode.auto.rawValue
        weatherDirectionRaw = d.string(forKey: "weatherDirection") ?? WeatherDirection.natural.rawValue
        weatherWind = d.object(forKey: "weatherWind") == nil ? 0.5 : d.double(forKey: "weatherWind")
        schemeRaw = d.string(forKey: "uiScheme") ?? "dark"
        shellPath = d.string(forKey: "shellPath") ?? ""
        shellStartupCommand = d.string(forKey: "shellStartupCommand") ?? ""
        loginShell = d.object(forKey: "loginShell") == nil ? true : d.bool(forKey: "loginShell")
    }

    func resolvedShell() -> String {
        if !shellPath.isEmpty, FileManager.default.isExecutableFile(atPath: shellPath) {
            return shellPath
        }
        if let env = ProcessInfo.processInfo.environment["SHELL"], FileManager.default.isExecutableFile(atPath: env) {
            return env
        }
        return "/bin/zsh"
    }

    var scheme: UIScheme {
        get { UIScheme(rawValue: schemeRaw) ?? .dark }
        set { schemeRaw = newValue.rawValue }
    }

    /// Randomizes the whole look: a random palette preset, a random background
    /// mode (with a random live style), and a random handful of weather effects.
    func randomizeTheme() {
        if let preset = UIThemePreset.all.randomElement() {
            applyPreset(preset)
        }
        let modes: [AppBackgroundMode] = [.gradient, .animated, .animated, .solid]
        if let mode = modes.randomElement() {
            backgroundMode = mode
            if mode == .animated, let live = LiveBackground.allCases.randomElement() {
                liveBackground = live
            }
            if mode == .solid {
                windowColorHex = gradientBottomHex
            }
        }
        let pool = WeatherEffect.allCases.filter { $0 != .off }
        var chosen = Set<WeatherEffect>()
        for _ in 0..<Int.random(in: 0...2) {
            if let effect = pool.randomElement() { chosen.insert(effect) }
        }
        activeEffects = chosen
    }

    func applyPreset(_ preset: UIThemePreset) {
        accentHex = preset.accent
        foregroundHex = preset.foreground
        backgroundHex = preset.background
        gradientTopHex = preset.gradientTop
        gradientBottomHex = preset.gradientBottom
        backgroundMode = preset.mode
        if let live = preset.live { liveBackground = live }
        activeEffects = Set(preset.effects)
    }

    var liveBackground: LiveBackground {
        get { LiveBackground(rawValue: liveBackgroundRaw) ?? .aurora }
        set { liveBackgroundRaw = newValue.rawValue }
    }

    // MARK: - Graphics quality

    var graphicsMode: GraphicsMode {
        get { GraphicsMode(rawValue: graphicsModeRaw) ?? .auto }
        set { graphicsModeRaw = newValue.rawValue }
    }

    /// Resolved per-tier rendering knobs — what every eye-candy view reads to scale
    /// itself. Recomputed cheaply from the current mode (and the cached RAM probe).
    var graphicsQuality: GraphicsQuality { graphicsMode.resolvedTier.quality }

    // MARK: - Weather wind

    var weatherDirection: WeatherDirection {
        get { WeatherDirection(rawValue: weatherDirectionRaw) ?? .natural }
        set { weatherDirectionRaw = newValue.rawValue }
    }

    /// Extra constant acceleration applied to every weather particle, in the chosen
    /// direction. Zero when direction is `.natural`. Tuned so 100% reads as a brisk
    /// but not absurd gust.
    var weatherWindAcceleration: CGVector {
        guard weatherDirection != .natural else { return .zero }
        let v = weatherDirection.vector
        let magnitude = max(0, min(weatherWind, 1)) * 220
        return CGVector(dx: v.dx * magnitude, dy: v.dy * magnitude)
    }

    // MARK: - Command palette category order

    /// The user's on-screen order of palette categories. Categories not yet in the
    /// stored list (e.g. ones introduced in a later build) are appended in their
    /// natural order, so the setting stays forward-compatible.
    var paletteCategoryOrder: [PaletteCategory] {
        let stored = paletteCategoryOrderRaw
            .split(separator: ",")
            .compactMap { PaletteCategory(rawValue: String($0)) }
        var seen = Set(stored)
        var result = stored
        for category in PaletteCategory.allCases where !seen.contains(category) {
            result.append(category)
            seen.insert(category)
        }
        return result
    }

    func setPaletteCategoryOrder(_ order: [PaletteCategory]) {
        paletteCategoryOrderRaw = order.map(\.rawValue).joined(separator: ",")
    }

    /// Drops `moved` onto `target`, placing it after the target when dragged down
    /// and before it when dragged up — the natural drag-reorder behaviour. Inserting
    /// at the target's *original* index (computed before removal) yields exactly that
    /// for every case, and is never a no-op for an adjacent swap.
    func movePaletteCategory(_ moved: PaletteCategory, onto target: PaletteCategory) {
        guard moved != target else { return }
        var order = paletteCategoryOrder
        guard let from = order.firstIndex(of: moved), let to = order.firstIndex(of: target) else { return }
        order.remove(at: from)
        order.insert(moved, at: min(to, order.count))
        setPaletteCategoryOrder(order)
    }

    func resetPaletteCategoryOrder() {
        paletteCategoryOrderRaw = ""
    }

    // MARK: - Per-effect color tints

    var effectTints: [String: String] {
        get {
            guard let data = effectTintsRaw.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String: String].self, from: data)
            else { return [:] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue), let json = String(data: data, encoding: .utf8) {
                effectTintsRaw = json
            } else {
                effectTintsRaw = ""
            }
        }
    }

    /// Tints for only the effects that are currently active and tintable —
    /// what the overlay actually needs.
    var activeEffectTints: [String: String] {
        let tints = effectTints
        var result: [String: String] = [:]
        for effect in activeEffects where effect.tintable {
            if let hex = tints[effect.rawValue] { result[effect.rawValue] = hex }
        }
        return result
    }

    func effectTint(_ effect: WeatherEffect) -> SwiftUI.Color? {
        guard let hex = effectTints[effect.rawValue] else { return nil }
        return SwiftUI.Color(hex: hex)
    }

    func setEffectTint(_ effect: WeatherEffect, _ color: SwiftUI.Color?) {
        var tints = effectTints
        if let color { tints[effect.rawValue] = NSColor(color).hexString } else { tints.removeValue(forKey: effect.rawValue) }
        effectTints = tints
    }

    var activeEffects: Set<WeatherEffect> {
        get {
            Set(effectsRaw.split(separator: ",").compactMap { WeatherEffect(rawValue: String($0)) }).subtracting([.off])
        }
        set {
            effectsRaw = newValue.subtracting([.off]).map { $0.rawValue }.sorted().joined(separator: ",")
        }
    }

    func toggleEffect(_ effect: WeatherEffect) {
        if effect == .off {
            activeEffects = []
            return
        }
        var set = activeEffects
        if set.contains(effect) { set.remove(effect) } else { set.insert(effect) }
        activeEffects = set
    }

    func applyTheme(_ theme: TerminalTheme) {
        foregroundHex = theme.foreground
        backgroundHex = theme.background
    }

    private func store(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
        revision += 1
    }

    var foregroundColor: NSColor { NSColor(hex: foregroundHex) ?? .white }
    var backgroundColor: NSColor { NSColor(hex: backgroundHex) ?? NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.10, alpha: 1) }
    var caretColor: NSColor { NSColor(hex: caretHex) ?? .systemGreen }
    var accentColor: SwiftUI.Color { SwiftUI.Color(hex: accentHex) }

    func resolvedFont() -> NSFont {
        let size = CGFloat(fontSize)
        if !fontFamily.isEmpty, let font = FontLibrary.shared.font(family: fontFamily, size: size) {
            return font
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6 || value.count == 8, let intValue = UInt64(value, radix: 16) else { return nil }
        let r, g, b, a: CGFloat
        if value.count == 8 {
            r = CGFloat((intValue >> 24) & 0xFF) / 255
            g = CGFloat((intValue >> 16) & 0xFF) / 255
            b = CGFloat((intValue >> 8) & 0xFF) / 255
            a = CGFloat(intValue & 0xFF) / 255
        } else {
            r = CGFloat((intValue >> 16) & 0xFF) / 255
            g = CGFloat((intValue >> 8) & 0xFF) / 255
            b = CGFloat(intValue & 0xFF) / 255
            a = 1
        }
        self.init(calibratedRed: r, green: g, blue: b, alpha: a)
    }

    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int((rgb.redComponent * 255).rounded())
        let g = Int((rgb.greenComponent * 255).rounded())
        let b = Int((rgb.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

extension SwiftUI.Color {
    init(hex: String) {
        let ns = NSColor(hex: hex) ?? .black
        self.init(nsColor: ns)
    }
}
