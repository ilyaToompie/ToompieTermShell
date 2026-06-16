import AppKit
import Foundation
import SwiftUI

/// Stateless actions backing the **Tools** and **Vibes** menus. Tools operate on
/// the clipboard or inject text into the focused terminal; Vibes reach into the
/// existing appearance prefs so the menu bar can shuffle the look on a whim.
@MainActor
enum MenuActions {

    // MARK: - Tools (clipboard + terminal injection)

    private static var pasteboard: NSPasteboard { .general }

    private static func clipboardString() -> String {
        pasteboard.string(forType: .string) ?? ""
    }

    private static func setClipboard(_ value: String) {
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }

    private static func insertIntoTerminal(_ text: String) {
        TerminalWorkspaceManager.shared.insertText(text)
    }

    private static func copied(_ value: String, _ messageKey: String) {
        setClipboard(value)
        ToastCenter.shared.show(LocalizationManager.shared.string(messageKey), icon: "doc.on.clipboard.fill", tint: .blue)
    }

    /// Insert a fresh lowercased UUID at the terminal cursor.
    static func insertUUID() {
        insertIntoTerminal(UUID().uuidString.lowercased())
    }

    static func copyUUID() {
        copied(UUID().uuidString.lowercased(), "tools.copied")
    }

    /// Insert the current Unix epoch seconds.
    static func insertUnixTimestamp() {
        insertIntoTerminal(String(Int(Date().timeIntervalSince1970)))
    }

    /// Insert an ISO-8601 timestamp.
    static func insertISODate() {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        insertIntoTerminal(fmt.string(from: Date()))
    }

    static func base64EncodeClipboard() {
        let input = clipboardString()
        guard !input.isEmpty else { return emptyClipboardToast() }
        copied(Data(input.utf8).base64EncodedString(), "tools.copied")
    }

    static func base64DecodeClipboard() {
        let input = clipboardString().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: input), let text = String(data: data, encoding: .utf8) else {
            return ToastCenter.shared.show(LocalizationManager.shared.string("tools.badInput"), icon: "exclamationmark.triangle.fill", tint: .orange)
        }
        copied(text, "tools.copied")
    }

    static func urlEncodeClipboard() {
        let input = clipboardString()
        guard !input.isEmpty else { return emptyClipboardToast() }
        let encoded = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
        copied(encoded, "tools.copied")
    }

    static func urlDecodeClipboard() {
        let input = clipboardString()
        copied(input.removingPercentEncoding ?? input, "tools.copied")
    }

    static func prettyPrintJSONClipboard() {
        let input = clipboardString()
        guard let data = input.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
              let text = String(data: pretty, encoding: .utf8) else {
            return ToastCenter.shared.show(LocalizationManager.shared.string("tools.badInput"), icon: "exclamationmark.triangle.fill", tint: .orange)
        }
        copied(text, "tools.copied")
    }

    static func copyRandomPassword() {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%^&*-_")
        let pw = String((0..<20).map { _ in alphabet.randomElement()! })
        copied(pw, "tools.copied")
    }

    static func copyLoremIpsum() {
        let lorem = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."
        copied(lorem, "tools.copied")
    }

    static func clipboardWordCount() {
        let input = clipboardString()
        let words = input.split { $0.isWhitespace || $0.isNewline }.count
        let chars = input.count
        let lines = input.isEmpty ? 0 : input.split(separator: "\n", omittingEmptySubsequences: false).count
        let msg = LocalizationManager.shared.string("tools.countResult")
            .replacingOccurrences(of: "%w", with: "\(words)")
            .replacingOccurrences(of: "%c", with: "\(chars)")
            .replacingOccurrences(of: "%l", with: "\(lines)")
        ToastCenter.shared.show(msg, icon: "text.word.spacing", tint: .blue)
    }

    private static func emptyClipboardToast() {
        ToastCenter.shared.show(LocalizationManager.shared.string("tools.emptyClipboard"), icon: "doc.on.clipboard", tint: .orange)
    }

    // MARK: - Vibes (appearance prefs)

    static func shuffleTheme() {
        AppPreferences.shared.randomizeTheme()
        SessionStats.shared.record(.themeShuffled)
        ToastCenter.shared.show(LocalizationManager.shared.string("vibes.shuffled"), icon: "paintpalette.fill", tint: AppPreferences.shared.accentColor)
    }

    static func toggleCinema() {
        UIChrome.shared.toggleHidden()
    }

    static func toggleReduceMotion() {
        AppPreferences.shared.reduceMotion.toggle()
    }

    static func toggleCRT() {
        AppPreferences.shared.crtMode.toggle()
    }

    static func cycleGraphicsMode() {
        let all = GraphicsMode.allCases
        let prefs = AppPreferences.shared
        if let idx = all.firstIndex(of: prefs.graphicsMode) {
            prefs.graphicsMode = all[(idx + 1) % all.count]
        }
        ToastCenter.shared.show(LocalizationManager.shared.string(prefs.graphicsMode.labelKey), icon: prefs.graphicsMode.icon, tint: AppPreferences.shared.accentColor)
    }

    static func randomWeatherEffect() {
        let pool = WeatherEffect.allCases.filter { $0 != .off }
        guard let effect = pool.randomElement() else { return }
        AppPreferences.shared.toggleEffect(effect)
    }

    static func clearWeatherEffects() {
        AppPreferences.shared.activeEffects = []
    }
}
