import SwiftData
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var terminalManager: TerminalWorkspaceManager
    @AppStorage("lastSelectedSidebarTab") private var selectedSidebarTabRawValue = SidebarTab.ssh.rawValue
    @AppStorage("sidebarWidth") private var sidebarWidth = 310.0

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
                .frame(width: min(max(sidebarWidth, 280), 340))

            Divider()

            TerminalWorkspaceView()
                .environmentObject(terminalManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(red: 0.07, green: 0.08, blue: 0.10))
    }
}
