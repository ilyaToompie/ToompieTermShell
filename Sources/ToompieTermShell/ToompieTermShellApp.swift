import AppKit
import SwiftData
import SwiftUI

/// Handles `toompieterm://` URLs at the AppKit level. Routing here (instead of SwiftUI's
/// `.onOpenURL`) keeps URL handling out of the scene system. The main scene is a single
/// `Window` (not a `WindowGroup`) so the open/reopen event can never spawn a *second* window
/// that fights over the shared terminal NSViews and leaves one rendered as an empty frame.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        MainActor.assumeIsolated {
            for url in urls {
                CLILauncher.shared.handle(url, manager: .shared)
            }
        }
    }

    /// Single-window app: closing the one window quits, rather than leaving a headless process
    /// with no way to bring the `Window` back.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct ToompieTermShellApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var terminalManager = TerminalWorkspaceManager.shared
    @StateObject private var preferences = AppPreferences.shared
    @StateObject private var localization = LocalizationManager.shared
    @StateObject private var fontLibrary = FontLibrary.shared
    @StateObject private var gifLibrary = GifLibrary.shared
    @StateObject private var gifInstances = GifInstanceStore.shared
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
        // Single, non-duplicable window. A `WindowGroup` is a template that the system can
        // instantiate again on an open/reopen/URL event — which spawned the blank second window.
        Window("ToompieTermShell", id: "main") {
            ContentView()
                .environmentObject(terminalManager)
                .environmentObject(preferences)
                .environmentObject(localization)
                .environmentObject(fontLibrary)
                .environmentObject(gifLibrary)
                .environmentObject(gifInstances)
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
            // Drop the default ⌘N "New Window" so it can be reused for a new terminal tab.
            CommandGroup(replacing: .newItem) {}

            CommandMenu("Terminal") {
                Button("Command Palette") {
                    PaletteController.shared.present(.basic)
                }
                .keyboardShortcut("k", modifiers: [.command])

                Button("Command Palette · Advanced") {
                    PaletteController.shared.present(.advanced)
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Button("Command Palette · Super") {
                    PaletteController.shared.present(.superA)
                }
                .keyboardShortcut("k", modifiers: [.command, .option])

                Divider()

                Button(localization("common.newTab")) {
                    terminalManager.createTab(in: terminalManager.focusedPanelIndex)
                }
                .keyboardShortcut("n", modifiers: [.command])

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
                .environmentObject(gifInstances)
                .frame(width: 560, height: 680)
                .preferredColorScheme(preferences.scheme.colorScheme)
        }
    }
}
