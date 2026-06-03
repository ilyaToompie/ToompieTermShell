import AppKit
import SwiftData
import SwiftUI

@main
struct ToompieTermShellApp: App {
    @StateObject private var terminalManager = TerminalWorkspaceManager()
    @StateObject private var preferences = AppPreferences.shared
    @StateObject private var localization = LocalizationManager.shared
    @StateObject private var fontLibrary = FontLibrary.shared
    @StateObject private var gifLibrary = GifLibrary.shared
    @StateObject private var scope = ScopeManager.shared
    private let modelContainer: ModelContainer

    init() {
        modelContainer = Self.makeContainer()
    }

    private static func makeContainer() -> ModelContainer {
        let types: [any PersistentModel.Type] = [
            Tag.self,
            Project.self,
            SSHShortcut.self,
            PinnedPath.self,
            CommandShortcut.self,
            ProjectNote.self,
            ConfigFile.self,
            TerminalLayoutPreference.self,
            AppSettings.self
        ]
        let schema = Schema(types)
        do {
            return try ModelContainer(for: schema)
        } catch {
            let url = URL.applicationSupportDirectory.appending(path: "default.store")
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
            }
            do {
                return try ModelContainer(for: schema)
            } catch {
                fatalError("Failed to initialize persistent store: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(terminalManager)
                .environmentObject(preferences)
                .environmentObject(localization)
                .environmentObject(fontLibrary)
                .environmentObject(gifLibrary)
                .environmentObject(scope)
                .modelContainer(modelContainer)
                .preferredColorScheme(preferences.scheme.colorScheme)
                .frame(minWidth: 1000, minHeight: 660)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About ToompieTermShell") {
                    let credits = NSMutableAttributedString(string: "by Toompie\n")
                    let link = NSAttributedString(
                        string: "github.com/ilyaToompie/ToompieTermShell",
                        attributes: [
                            .link: URL(string: "https://github.com/ilyaToompie/ToompieTermShell")!,
                            .foregroundColor: NSColor.linkColor
                        ]
                    )
                    credits.append(link)
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [.credits: credits])
                }
            }
            CommandMenu("Terminal") {
                Button("Command Palette") {
                    PaletteController.shared.open = true
                }
                .keyboardShortcut("k", modifiers: [.command])

                Divider()

                Button(localization("common.newTab")) {
                    terminalManager.createTab(in: terminalManager.focusedPanelIndex)
                }
                .keyboardShortcut("t", modifiers: [.command])

                Button(localization("common.closeTab")) {
                    terminalManager.closeActiveTab(in: terminalManager.focusedPanelIndex)
                }
                .keyboardShortcut("w", modifiers: [.command])

                Divider()

                ForEach(0..<4, id: \.self) { index in
                    Button("\(localization("terminal.panel")) \(index + 1)") {
                        terminalManager.focusPanel(index)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command])

                    Button("\(localization("terminal.usePanels").replacingOccurrences(of: "%@", with: "\(index + 1)"))") {
                        terminalManager.setVisiblePanelCount(index + 1)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command, .shift])
                }
            }
        }

        Settings {
            SettingsTab()
                .environmentObject(preferences)
                .environmentObject(localization)
                .environmentObject(fontLibrary)
                .environmentObject(gifLibrary)
                .frame(width: 560, height: 680)
                .preferredColorScheme(preferences.scheme.colorScheme)
        }
    }
}
