import AppKit
import Combine
import Foundation
import SwiftTerm

final class TerminalTabModel: ObservableObject, Identifiable {
    let id: UUID
    @Published var title: String
    @Published var currentDirectory: String?
    @Published var isRunning: Bool
    let terminalView: ManagedLocalTerminalView
    let processDelegate: TerminalProcessDelegate

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.isRunning = true
        self.terminalView = ManagedLocalTerminalView(frame: .zero)
        self.processDelegate = TerminalProcessDelegate()
        self.processDelegate.owner = self
        self.terminalView.processDelegate = processDelegate
    }
}

@MainActor
final class TerminalPanelModel: ObservableObject, Identifiable {
    let id = UUID()
    let index: Int
    @Published var tabs: [TerminalTabModel] = []
    @Published var selectedTabID: UUID?

    init(index: Int) {
        self.index = index
    }

    var selectedTab: TerminalTabModel? {
        guard let selectedTabID else { return tabs.first }
        return tabs.first { $0.id == selectedTabID } ?? tabs.first
    }
}

@MainActor
final class TerminalWorkspaceManager: ObservableObject {
    @Published var panels: [TerminalPanelModel]
    @Published private(set) var visiblePanelCount: Int
    @Published private(set) var focusedPanelIndex: Int

    init() {
        self.panels = (0..<4).map { TerminalPanelModel(index: $0) }
        let savedCount = UserDefaults.standard.integer(forKey: "visiblePanelCount")
        self.visiblePanelCount = savedCount == 0 ? 1 : min(max(savedCount, 1), 4)
        self.focusedPanelIndex = 0
        ensureVisiblePanelsHaveTabs()
    }

    func setVisiblePanelCount(_ count: Int) {
        visiblePanelCount = min(max(count, 1), 4)
        UserDefaults.standard.set(visiblePanelCount, forKey: "visiblePanelCount")
        if focusedPanelIndex >= visiblePanelCount {
            focusedPanelIndex = visiblePanelCount - 1
        }
        ensureVisiblePanelsHaveTabs()
    }

    func focusPanel(_ index: Int) {
        guard index >= 0, index < visiblePanelCount else { return }
        focusedPanelIndex = index
        panel(index)?.selectedTab?.terminalView.window?.makeFirstResponder(panel(index)?.selectedTab?.terminalView)
    }

    @discardableResult
    func createTab(in panelIndex: Int, title: String? = nil, commandToRun: String? = nil) -> TerminalTabModel? {
        guard let panel = panel(panelIndex) else { return nil }
        let tabNumber = panel.tabs.count + 1
        let tab = TerminalTabModel(title: title ?? "Shell \(tabNumber)")
        configure(tab.terminalView)
        panel.tabs.append(tab)
        panel.selectedTabID = tab.id
        focusPanel(panelIndex)

        let shell = Self.defaultShell()
        let shellName = "-" + URL(fileURLWithPath: shell).lastPathComponent
        tab.terminalView.startProcess(executable: shell, execName: shellName, currentDirectory: FileManager.default.homeDirectoryForCurrentUser.path)

        if let commandToRun {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.send(commandToRun, to: panelIndex)
            }
        }
        return tab
    }

    func closeActiveTab(in panelIndex: Int) {
        guard let panel = panel(panelIndex), let selected = panel.selectedTab else { return }
        selected.terminalView.terminate()
        panel.tabs.removeAll { $0.id == selected.id }
        panel.selectedTabID = panel.tabs.last?.id
    }

    func selectTab(_ tabID: UUID, in panelIndex: Int) {
        guard let panel = panel(panelIndex), panel.tabs.contains(where: { $0.id == tabID }) else { return }
        panel.selectedTabID = tabID
        focusPanel(panelIndex)
    }

    func send(_ text: String, to panelIndex: Int? = nil) {
        let index = panelIndex ?? focusedPanelIndex
        guard let tab = activeTabCreatingIfNeeded(in: index) else { return }
        let data = Array(text.utf8)
        tab.terminalView.send(source: tab.terminalView, data: data[...])
        focusPanel(index)
    }

    func cd(to path: String, in panelIndex: Int) {
        send(ShellSafety.cdCommand(to: path), to: panelIndex)
    }

    func runCommand(_ command: String, workingDirectory: String?, in panelIndex: Int) {
        if let workingDirectory, !workingDirectory.isEmpty {
            send(ShellSafety.cdCommand(to: workingDirectory), to: panelIndex)
        }
        send(ShellSafety.commandLine(command), to: panelIndex)
    }

    func activePanelIndices() -> [Int] {
        Array(0..<visiblePanelCount)
    }

    private func activeTabCreatingIfNeeded(in panelIndex: Int) -> TerminalTabModel? {
        if let tab = panel(panelIndex)?.selectedTab {
            return tab
        }
        return createTab(in: panelIndex)
    }

    private func panel(_ index: Int) -> TerminalPanelModel? {
        guard index >= 0, index < panels.count else { return nil }
        return panels[index]
    }

    private func ensureVisiblePanelsHaveTabs() {
        for index in 0..<visiblePanelCount where panels[index].tabs.isEmpty {
            _ = createTab(in: index)
        }
    }

    private func configure(_ terminal: ManagedLocalTerminalView) {
        terminal.autoresizingMask = [.width, .height]
        terminal.nativeForegroundColor = NSColor(calibratedRed: 0.88, green: 0.90, blue: 0.92, alpha: 1)
        terminal.nativeBackgroundColor = NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.10, alpha: 1)
        terminal.caretColor = .systemGreen
        terminal.getTerminal().setCursorStyle(.steadyBlock)
        terminal.wantsLayer = true
        terminal.layer?.backgroundColor = terminal.nativeBackgroundColor.cgColor
        do {
            terminal.metalBufferingMode = .perFrameAggregated
            try terminal.setUseMetal(false)
        } catch {
            // SwiftTerm automatically falls back to its AppKit renderer.
        }
    }

    static func defaultShell() -> String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"], FileManager.default.isExecutableFile(atPath: shell) {
            return shell
        }
        return "/bin/zsh"
    }
}

final class ManagedLocalTerminalView: LocalProcessTerminalView {}

final class TerminalProcessDelegate: NSObject, LocalProcessTerminalViewDelegate {
    weak var owner: TerminalTabModel?

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        DispatchQueue.main.async { [weak self] in
            guard let owner = self?.owner else { return }
            owner.title = title.isEmpty ? owner.title : title
        }
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.owner?.currentDirectory = directory
        }
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        DispatchQueue.main.async { [weak self] in
            self?.owner?.isRunning = false
        }
    }
}
