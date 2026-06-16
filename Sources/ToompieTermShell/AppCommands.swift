import AppKit
import SwiftUI

/// Populates the standard macOS menu bar (App / File / Terminal / View / Help).
/// Factored out of `ToompieTermShellApp` so the scene declaration stays readable.
/// Titles read through `localization`, and the struct observes it so the menus
/// re-render when the UI language changes.
struct AppCommands: Commands {
    @ObservedObject var terminalManager: TerminalWorkspaceManager
    @ObservedObject var localization: LocalizationManager
    @ObservedObject var prefs = AppPreferences.shared
    @ObservedObject var health = HealthReminders.shared
    @ObservedObject var stats = SessionStats.shared
    @AppStorage("lastSelectedSidebarTab") private var selectedSidebarTabRawValue = SidebarTab.ssh.rawValue

    private static let githubURL = URL(string: "https://github.com/ilyaToompie/ToompieTermShell")!

    var body: some Commands {
        // ── App menu ──────────────────────────────────────────────────────
        CommandGroup(replacing: .appInfo) {
            Button("About ToompieTermShell") { Self.showAboutPanel() }
        }

        // ── File menu ─────────────────────────────────────────────────────
        // Replaces the default New/Open block. ⌘N is reused for a new tab
        // (single-window app, so the default "New Window" is meaningless).
        CommandGroup(replacing: .newItem) {
            Button(localization("common.newTab")) { newTab() }
                .keyboardShortcut("t", modifiers: [.command])
            Button(localization("common.newTab")) { newTab() }
                .keyboardShortcut("n", modifiers: [.command])
            Button(localization("menu.openFile")) { openFile() }
                .keyboardShortcut("o", modifiers: [.command])
            Divider()
            Button(localization("common.closeTab")) {
                terminalManager.closeActiveTab(in: terminalManager.focusedPanelIndex)
            }
            .keyboardShortcut("w", modifiers: [.command])
        }
        CommandGroup(replacing: .saveItem) {
            Button(localization("common.save")) { saveActiveEditor() }
                .keyboardShortcut("s", modifiers: [.command])
        }

        // ── Terminal menu ─────────────────────────────────────────────────
        CommandMenu(localization("palette.cat.terminal")) {
            Button(localization("menu.commandPalette")) { PaletteController.shared.present(.basic) }
                .keyboardShortcut("k", modifiers: [.command])
            Button(localization("menu.paletteAdvanced")) { PaletteController.shared.present(.advanced) }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            Button(localization("menu.paletteSuper")) { PaletteController.shared.present(.superA) }
                .keyboardShortcut("k", modifiers: [.command, .option])

            Divider()

            Button(localization("menu.clearScreen")) {
                // Form feed (Ctrl-L) clears the screen in most shells.
                terminalManager.send("\u{0C}", to: terminalManager.focusedPanelIndex)
            }
            .keyboardShortcut("l", modifiers: [.command])

            Divider()

            ForEach(0..<4, id: \.self) { index in
                Button("\(localization("terminal.panel")) \(index + 1)") {
                    terminalManager.focusPanel(index)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command])

                Button(localization("terminal.usePanels").replacingOccurrences(of: "%@", with: "\(index + 1)")) {
                    terminalManager.setVisiblePanelCount(index + 1)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command, .shift])
            }
        }

        // Grouped: CommandsBuilder permits at most 10 top-level members.
        Group {
        // ── Fun menu ──────────────────────────────────────────────────────
        CommandMenu(localization("menu.fun")) {
            Button(localization("menu.fun.tir")) { TirGameController.shared.present() }
                .keyboardShortcut("g", modifiers: [.command, .shift])
        }

        // ── Health menu ───────────────────────────────────────────────────
        CommandMenu(localization("menu.health")) {
            ForEach(HealthReminderKind.allCases) { kind in
                Toggle(isOn: Binding(
                    get: { health.isEnabled(kind) },
                    set: { health.setEnabled($0, for: kind) }
                )) {
                    Text("\(kind.emoji)  \(localization(kind.labelKey))")
                }
            }
            Divider()
            Button(localization("menu.health.test")) {
                let kind = HealthReminderKind.allCases.first { health.isEnabled($0) } ?? .water
                health.fireNow(kind)
            }
            Button(localization("menu.health.disableAll")) { health.disableAll() }
                .disabled(!health.anyEnabled)
        }

        // ── Tools menu ────────────────────────────────────────────────────
        CommandMenu(localization("menu.tools")) {
            Button(localization("tools.insertUUID")) { MenuActions.insertUUID() }
            Button(localization("tools.copyUUID")) { MenuActions.copyUUID() }
            Divider()
            Button(localization("tools.insertTimestamp")) { MenuActions.insertUnixTimestamp() }
            Button(localization("tools.insertISO")) { MenuActions.insertISODate() }
            Divider()
            Button(localization("tools.base64Encode")) { MenuActions.base64EncodeClipboard() }
            Button(localization("tools.base64Decode")) { MenuActions.base64DecodeClipboard() }
            Button(localization("tools.urlEncode")) { MenuActions.urlEncodeClipboard() }
            Button(localization("tools.urlDecode")) { MenuActions.urlDecodeClipboard() }
            Button(localization("tools.jsonPretty")) { MenuActions.prettyPrintJSONClipboard() }
            Divider()
            Button(localization("tools.password")) { MenuActions.copyRandomPassword() }
            Button(localization("tools.lorem")) { MenuActions.copyLoremIpsum() }
            Button(localization("tools.wordCount")) { MenuActions.clipboardWordCount() }
        }

        // ── Stats menu (live session + lifetime counters) ─────────────────
        CommandMenu(localization("menu.stats")) {
            Text("\(localization("stats.uptime")): \(stats.uptimeString)")
            Text("\(localization("stats.tabsOpened")): \(stats.tabsOpened)")
            Text("\(localization("stats.paletteOpens")): \(stats.paletteOpens)")
            Text("\(localization("stats.themeShuffles")): \(stats.themeShuffles)")
            Text("\(localization("stats.games")): \(stats.gamesPlayed)")
            Divider()
            Text("\(localization("stats.targetsHit")): \(stats.targetsHit)")
            Text("\(localization("stats.highScore")): \(stats.tirHighScore)")
            Text("\(localization("stats.bestStreak")): \(stats.tirBestStreak)")
            Divider()
            Button(localization("stats.reset")) { stats.resetLifetime() }
        }

        // ── Vibes menu ────────────────────────────────────────────────────
        CommandMenu(localization("menu.vibes")) {
            Button(localization("vibes.shuffle")) { MenuActions.shuffleTheme() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            Button(localization("vibes.cinema")) { MenuActions.toggleCinema() }
            Divider()
            Button(localization("vibes.randomEffect")) { MenuActions.randomWeatherEffect() }
            Button(localization("vibes.clearEffects")) { MenuActions.clearWeatherEffects() }
            Divider()
            Button(localization("vibes.cycleGraphics")) { MenuActions.cycleGraphicsMode() }
            Toggle(isOn: Binding(get: { prefs.reduceMotion }, set: { _ in MenuActions.toggleReduceMotion() })) {
                Text(localization("vibes.reduceMotion"))
            }
            Toggle(isOn: Binding(get: { prefs.crtMode }, set: { _ in MenuActions.toggleCRT() })) {
                Text(localization("vibes.crt"))
            }
        }
        }   // end Group

        // ── View menu ─────────────────────────────────────────────────────
        CommandGroup(after: .sidebar) {
            Button(localization("menu.cinema")) { UIChrome.shared.toggleHidden() }
                .keyboardShortcut("c", modifiers: [.command, .control])

            Divider()

            Picker(localization("menu.viewSidebar"), selection: $selectedSidebarTabRawValue) {
                ForEach(SidebarTab.allCases) { tab in
                    Text(localization(tab.titleKey)).tag(tab.rawValue)
                }
            }
        }

        // ── Help menu ─────────────────────────────────────────────────────
        CommandGroup(replacing: .help) {
            Button(localization("menu.github")) {
                NSWorkspace.shared.open(Self.githubURL)
            }
        }
    }

    // MARK: - Actions

    private func newTab() {
        terminalManager.createTab(in: terminalManager.focusedPanelIndex)
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        terminalManager.openLocalFileEditor(path: url.path)
    }

    private func saveActiveEditor() {
        let panel = terminalManager.panels[terminalManager.focusedPanelIndex]
        guard let tab = panel.selectedTab, tab.kind == .editor else { return }
        tab.saveEditor()
    }

    private static func showAboutPanel() {
        let credits = NSMutableAttributedString(string: "by Toompie\n")
        let link = NSAttributedString(
            string: "github.com/ilyaToompie/ToompieTermShell",
            attributes: [
                .link: githubURL,
                .foregroundColor: NSColor.linkColor
            ]
        )
        credits.append(link)
        NSApplication.shared.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}
