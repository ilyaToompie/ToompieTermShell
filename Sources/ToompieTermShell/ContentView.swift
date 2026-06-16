import SwiftData
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var terminalManager: TerminalWorkspaceManager
    @EnvironmentObject private var prefs: AppPreferences
    @StateObject private var palette = PaletteController.shared
    @StateObject private var gifStore = GifInstanceStore.shared
    @StateObject private var cli = CLILauncher.shared
    @StateObject private var chrome = UIChrome.shared
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
        Group {
            if chrome.hidden {
                // Cinema mode: only the background (and effects/GIFs) remain.
                Color.clear
            } else {
                HStack(spacing: 0) {
                    SidebarView(selectedTab: selectedSidebarTab)
                        .frame(width: min(max(sidebarWidth, 300), 360))

                    Divider()
                        .overlay(Color.white.opacity(0.08))

                    TerminalWorkspaceView()
                        .environmentObject(terminalManager)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BackgroundContainer(prefs: prefs))
        .overlay(alignment: .top) {
            if !prefs.activeEffects.isEmpty {
                WeatherLayer(
                    effects: prefs.activeEffects.map(\.rawValue).sorted().compactMap(WeatherEffect.init),
                    tints: prefs.activeEffectTints,
                    wind: prefs.weatherWindAcceleration,
                    birthRateScale: prefs.graphicsQuality.particleScale
                )
            }
        }
        .overlay {
            if !chrome.hidden { ToastOverlay() }
        }
        .overlay {
            // Always present so a "hide UI" GIF stays tappable to restore.
            ZStack {
                ForEach($gifStore.instances) { $inst in
                    GifWidget(instance: $inst, editable: prefs.gifEditable)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .bottomLeading) {
            if cli.shouldShowPrompt && !chrome.hidden {
                CLIInstallPrompt()
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: cli.shouldShowPrompt)
        .animation(.easeInOut(duration: 0.25), value: chrome.hidden)
        .navigationTitle(windowTitle)
        .sheet(isPresented: $palette.open) {
            CommandPalette()
        }
        .tint(prefs.accentColor)
        .dynamicTypeSize(prefs.textCase == .large ? .xxLarge : .large)
        // Safety net: Escape restores the UI if it was hidden via a GIF tap.
        .onExitCommand { if chrome.hidden { chrome.hidden = false } }
    }

    private var windowTitle: String {
        let panel = terminalManager.panels[terminalManager.focusedPanelIndex]
        if let title = panel.selectedTab?.title, !title.isEmpty {
            return "ToompieTermShell — \(title)"
        }
        return "ToompieTermShell"
    }
}

/// Hosts the particle overlay and freezes the emitters when the window is
/// hidden. Observing the motion controller here (rather than on ContentView)
/// keeps occlusion changes from re-rendering the whole window.
private struct WeatherLayer: View {
    let effects: [WeatherEffect]
    let tints: [String: String]
    var wind: CGVector = .zero
    var birthRateScale: Double = 1
    @ObservedObject private var motion = MotionController.shared

    var body: some View {
        WeatherOverlay(effects: effects, tints: tints, wind: wind,
                       birthRateScale: birthRateScale, running: motion.animate)
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }
}
