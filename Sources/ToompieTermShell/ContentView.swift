import SwiftData
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var terminalManager: TerminalWorkspaceManager
    @EnvironmentObject private var prefs: AppPreferences
    @StateObject private var palette = PaletteController.shared
    @StateObject private var gifStore = GifInstanceStore.shared
    @State private var parallax: CGSize = .zero
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
        .background(
            AppBackground(prefs: prefs, parallax: parallax)
                .onContinuousHover { phase in
                    if case .active(let loc) = phase {
                        withAnimation(.easeOut(duration: 0.4)) {
                            parallax = CGSize(width: (loc.x - 500) * 0.03, height: (loc.y - 380) * 0.03)
                        }
                    }
                }
        )
        .overlay(alignment: .top) {
            if !prefs.activeEffects.isEmpty {
                WeatherOverlay(effects: prefs.activeEffects.map(\.rawValue).sorted().compactMap(WeatherEffect.init))
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .overlay(ToastOverlay())
        .overlay {
            ZStack {
                ForEach($gifStore.instances) { $inst in
                    GifWidget(instance: $inst, editable: prefs.gifEditable)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(prefs.gifEditable)
        }
        .navigationTitle(windowTitle)
        .sheet(isPresented: $palette.open) {
            CommandPalette()
        }
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
