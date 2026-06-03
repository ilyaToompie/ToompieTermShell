import SwiftUI
import SwiftTerm

struct TerminalWorkspaceView: View {
    @EnvironmentObject private var terminalManager: TerminalWorkspaceManager
    @EnvironmentObject private var loc: LocalizationManager

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
                .help(loc("terminal.usePanels").replacingOccurrences(of: "%@", with: "\(count)"))
                .tint(terminalManager.visiblePanelCount == count ? .accentColor : .gray)
                .hoverScale(1.12)
            }

            Spacer()

            Text("\(loc("terminal.panel")) \(terminalManager.focusedPanelIndex + 1)")
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
            .environmentObject(loc)
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
    @EnvironmentObject private var loc: LocalizationManager
    @EnvironmentObject private var prefs: AppPreferences
    @State private var editingTabID: UUID?
    @State private var editingText = ""

    private var isFocused: Bool { panel.index == terminalManager.focusedPanelIndex }

    var body: some View {
        VStack(spacing: 0) {
            header

            ZStack {
                if let selectedTab = panel.selectedTab {
                    if selectedTab.kind == .editor {
                        EditorTabView(tab: selectedTab)
                            .id(selectedTab.id)
                    } else {
                        TerminalHostView(tab: selectedTab)
                            .id(selectedTab.id)
                    }
                } else {
                    emptyPanel
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if prefs.crtMode {
                    CRTOverlay()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animatedBorder(active: isFocused, cornerRadius: 12, color: prefs.accentColor)
        .shadow(color: isFocused ? prefs.accentColor.opacity(0.32) : .clear, radius: 12, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            terminalManager.focusPanel(panel.index)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isFocused)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("\(panel.index + 1)")
                .font(.caption.weight(.bold))
                .frame(width: 20, height: 20)
                .background(Circle().fill(isFocused ? Color.accentColor : Color.white.opacity(0.12)))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(panel.tabs) { tab in
                        tabChip(tab)
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
            .help(loc("common.newTab"))

            Button {
                terminalManager.closeActiveTab(in: panel.index)
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .disabled(panel.tabs.isEmpty)
            .help(loc("common.closeTab"))
        }
        .padding(.horizontal, 8)
        .frame(height: 36)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func tabChip(_ tab: TerminalTabModel) -> some View {
        if editingTabID == tab.id {
            TextField(loc("terminal.rename"), text: $editingText, onCommit: {
                tab.rename(editingText)
                editingTabID = nil
            })
            .textFieldStyle(.roundedBorder)
            .font(.caption)
            .frame(width: 120)
        } else {
            Button {
                terminalManager.selectTab(tab.id, in: panel.index)
            } label: {
                HStack(spacing: 5) {
                    if tab.kind == .editor {
                        Image(systemName: "square.and.pencil").font(.system(size: 8)).foregroundStyle(.secondary)
                    } else {
                        PulsingDot(color: .green, active: tab.isRunning)
                    }
                    Text(tab.title)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(panel.selectedTabID == tab.id ? Color.white.opacity(0.2) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(panel.selectedTabID == tab.id ? Color.white.opacity(0.18) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .help(loc("terminal.rename"))
            .onTapGesture(count: 2) {
                editingText = tab.title
                editingTabID = tab.id
            }
            .contextMenu {
                Button(loc("terminal.rename")) {
                    editingText = tab.title
                    editingTabID = tab.id
                }
            }
        }
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
        .help(loc("common.newTab"))
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

struct EditorTabView: View {
    @ObservedObject var tab: TerminalTabModel
    @EnvironmentObject private var loc: LocalizationManager

    private var statusText: String {
        if tab.editorStatus == "fetching" { return loc("ftp.fetching") }
        return tab.editorStatus
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "square.and.pencil").foregroundStyle(.secondary)
                Text(tab.title).font(.caption.weight(.semibold)).lineLimit(1)
                if !tab.editorStatus.isEmpty {
                    Text(statusText).font(.caption2).foregroundStyle(tab.editorStatus == "fetching" ? Color.secondary : Color.orange)
                }
                Spacer()
                Button { tab.saveEditor() } label: { Label(loc("common.save"), systemImage: "square.and.arrow.down") }
                    .controlSize(.small)
                    .disabled(tab.editorStatus == "fetching")
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(.ultraThinMaterial)

            TextEditor(text: $tab.editorText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.black.opacity(0.28))
        }
    }
}
