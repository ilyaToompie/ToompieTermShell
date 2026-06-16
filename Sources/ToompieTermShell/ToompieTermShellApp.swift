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
            AppCommands(terminalManager: terminalManager, localization: localization)
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
