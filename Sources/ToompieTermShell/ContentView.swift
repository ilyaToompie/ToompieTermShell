import SwiftData
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var terminalManager: TerminalWorkspaceManager
    @EnvironmentObject private var prefs: AppPreferences
    @AppStorage("lastSelectedSidebarTab") private var selectedSidebarTabRawValue = SidebarTab.ssh.rawValue
    @AppStorage("sidebarWidth") private var sidebarWidth = 320.0

    private var selectedSidebarTab: Binding<SidebarTab> {
        Binding {
            SidebarTab(rawValue: selectedSidebarTabRawValue) ?? .ssh
        } set: { newValue in
            selectedSidebarTabRawValue = newValue.rawValue
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selectedTab: selectedSidebarTab)
                .frame(width: min(max(sidebarWidth, 300), 360))

            Divider()
                .overlay(Color.white.opacity(0.08))

            TerminalWorkspaceView()
                .environmentObject(terminalManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppBackground(prefs: prefs))
        .overlay(alignment: .top) {
            if prefs.weatherEffect != .off {
                WeatherOverlay(effect: prefs.weatherEffect)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .overlay(alignment: .bottomLeading) {
            GifWidget(prefs: prefs)
                .padding(16)
                .allowsHitTesting(prefs.gifEditable)
        }
        .navigationTitle(windowTitle)
        .tint(prefs.accentColor)
        .dynamicTypeSize(prefs.textCase == .large ? .xxLarge : .large)
    }

    private var windowTitle: String {
        let panel = terminalManager.panels[terminalManager.focusedPanelIndex]
        if let title = panel.selectedTab?.title, !title.isEmpty {
            return "ToompieTermShell — \(title)"
        }
        return "ToompieTermShell"
    }
}
