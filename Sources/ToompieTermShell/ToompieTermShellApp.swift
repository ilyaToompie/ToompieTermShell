import SwiftData
import SwiftUI

@main
struct ToompieTermShellApp: App {
    @StateObject private var terminalManager = TerminalWorkspaceManager()
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(
                for: SSHShortcut.self,
                PinnedPath.self,
                CommandShortcut.self,
                TerminalLayoutPreference.self,
                AppSettings.self
            )
        } catch {
            fatalError("Failed to initialize persistent store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(terminalManager)
                .modelContainer(modelContainer)
                .preferredColorScheme(.dark)
                .frame(minWidth: 980, minHeight: 640)
        }
        .commands {
            CommandMenu("Terminal") {
                Button("New Tab") {
                    terminalManager.createTab(in: terminalManager.focusedPanelIndex)
                }
                .keyboardShortcut("t", modifiers: [.command])

                Button("Close Tab") {
                    terminalManager.closeActiveTab(in: terminalManager.focusedPanelIndex)
                }
                .keyboardShortcut("w", modifiers: [.command])

                Divider()

                ForEach(0..<4, id: \.self) { index in
                    Button("Focus Terminal \(index + 1)") {
                        terminalManager.focusPanel(index)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command])

                    Button("Use \(index + 1) Panel\(index == 0 ? "" : "s")") {
                        terminalManager.setVisiblePanelCount(index + 1)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command, .shift])
                }
            }
        }
    }
}
