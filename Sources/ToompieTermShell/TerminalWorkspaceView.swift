import SwiftUI
import SwiftTerm

struct TerminalWorkspaceView: View {
    @EnvironmentObject private var terminalManager: TerminalWorkspaceManager

    var body: some View {
        VStack(spacing: 10) {
            layoutToolbar
            terminalLayout
        }
        .padding(10)
    }

    private var layoutToolbar: some View {
        HStack(spacing: 8) {
            ForEach(1...4, id: \.self) { count in
                Button {
                    terminalManager.setVisiblePanelCount(count)
                } label: {
                    Image(systemName: layoutIcon(for: count))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Use \(count) terminal panel\(count == 1 ? "" : "s")")
                .tint(terminalManager.visiblePanelCount == count ? .accentColor : .gray)
            }

            Spacer()

            Text("Panel \(terminalManager.focusedPanelIndex + 1)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var terminalLayout: some View {
        switch terminalManager.visiblePanelCount {
        case 1:
            panel(0)
        case 2:
            HStack(spacing: 10) {
                panel(0)
                panel(1)
            }
        case 3:
            HStack(spacing: 10) {
                VStack(spacing: 10) {
                    panel(0)
                    panel(1)
                }
                panel(2)
            }
        default:
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    panel(0)
                    panel(1)
                }
                HStack(spacing: 10) {
                    panel(2)
                    panel(3)
                }
            }
        }
    }

    private func panel(_ index: Int) -> some View {
        TerminalPanelView(panel: terminalManager.panels[index])
            .environmentObject(terminalManager)
    }

    private func layoutIcon(for count: Int) -> String {
        switch count {
        case 1: "rectangle"
        case 2: "rectangle.split.2x1"
        case 3: "rectangle.split.3x1"
        default: "square.grid.2x2"
        }
    }
}

struct TerminalPanelView: View {
    @ObservedObject var panel: TerminalPanelModel
    @EnvironmentObject private var terminalManager: TerminalWorkspaceManager

    var body: some View {
        VStack(spacing: 0) {
            header

            ZStack {
                if let selectedTab = panel.selectedTab {
                    TerminalHostView(tab: selectedTab)
                        .id(selectedTab.id)
                } else {
                    emptyPanel
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.07, green: 0.08, blue: 0.10))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(panel.index == terminalManager.focusedPanelIndex ? Color.accentColor : Color.white.opacity(0.12), lineWidth: panel.index == terminalManager.focusedPanelIndex ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            terminalManager.focusPanel(panel.index)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("\(panel.index + 1)")
                .font(.caption.weight(.bold))
                .frame(width: 20, height: 20)
                .background(Circle().fill(panel.index == terminalManager.focusedPanelIndex ? Color.accentColor : Color.white.opacity(0.12)))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(panel.tabs) { tab in
                        Button {
                            terminalManager.selectTab(tab.id, in: panel.index)
                        } label: {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(tab.isRunning ? Color.green : Color.gray)
                                    .frame(width: 6, height: 6)
                                Text(tab.title)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                            .frame(height: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(panel.selectedTabID == tab.id ? Color.white.opacity(0.18) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                terminalManager.createTab(in: panel.index)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("New tab")

            Button {
                terminalManager.closeActiveTab(in: panel.index)
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .disabled(panel.tabs.isEmpty)
            .help("Close tab")
        }
        .padding(.horizontal, 8)
        .frame(height: 36)
        .background(Color(red: 0.11, green: 0.12, blue: 0.15))
    }

    private var emptyPanel: some View {
        Button {
            terminalManager.createTab(in: panel.index)
        } label: {
            Image(systemName: "plus")
                .font(.title3)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.bordered)
        .help("Create terminal tab")
    }
}

struct TerminalHostView: NSViewRepresentable {
    @ObservedObject var tab: TerminalTabModel

    func makeNSView(context: Context) -> ManagedLocalTerminalView {
        tab.terminalView
    }

    func updateNSView(_ nsView: ManagedLocalTerminalView, context: Context) {
    }
}
