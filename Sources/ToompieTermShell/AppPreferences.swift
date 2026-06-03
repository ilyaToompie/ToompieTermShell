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

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .native: return "bg.native"
        case .solid: return "bg.solid"
        case .gradient: return "bg.gradient"
        case .image: return "bg.image"
        }
    }
}

enum WeatherEffect: String, CaseIterable, Identifiable {
    case off
    case snow
    case rain

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .off: return "weather.off"
        case .snow: return "weather.snow"
        case .rain: return "weather.rain"
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
    @Published var weatherEffect: WeatherEffect { didSet { store(weatherEffect.rawValue, "weatherEffect") } }
    @Published var bgInvert: Bool { didSet { store(bgInvert, "bgInvert") } }
    @Published var bgGrayscale: Bool { didSet { store(bgGrayscale, "bgGrayscale") } }
    @Published var bgBlur: Double { didSet { store(bgBlur, "bgBlur") } }
    @Published var bgBrightness: Double { didSet { store(bgBrightness, "bgBrightness") } }
    @Published var bgDim: Double { didSet { store(bgDim, "bgDim") } }

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
        weatherEffect = WeatherEffect(rawValue: d.string(forKey: "weatherEffect") ?? "") ?? .off
        bgInvert = d.bool(forKey: "bgInvert")
        bgGrayscale = d.bool(forKey: "bgGrayscale")
        bgBlur = d.double(forKey: "bgBlur")
        bgBrightness = d.double(forKey: "bgBrightness")
        bgDim = d.object(forKey: "bgDim") == nil ? 0.35 : d.double(forKey: "bgDim")
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
