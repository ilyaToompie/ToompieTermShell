import AppKit
import Combine
import CoreImage
import Foundation
import SwiftTerm
import UniformTypeIdentifiers

enum TerminalTabKind {
    case shell
    case editor
}

final class TerminalTabModel: ObservableObject, Identifiable {
    let id: UUID
    let kind: TerminalTabKind
    @Published var title: String
    @Published var hasCustomTitle: Bool
    @Published var currentDirectory: String?
    @Published var isRunning: Bool
    let terminalView: ManagedLocalTerminalView
    let processDelegate: TerminalProcessDelegate

    @Published var editorText: String
    @Published var editorStatus: String
    var localPath: String?
    var onSave: ((String) -> Void)?

    init(title: String, kind: TerminalTabKind = .shell) {
        self.id = UUID()
        self.kind = kind
        self.title = title
        self.hasCustomTitle = kind == .editor
        self.isRunning = kind == .shell
        self.terminalView = ManagedLocalTerminalView(frame: .zero)
        self.processDelegate = TerminalProcessDelegate()
        self.editorText = ""
        self.editorStatus = ""
        self.processDelegate.owner = self
        self.terminalView.processDelegate = processDelegate
    }

    func rename(_ newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        title = trimmed
        hasCustomTitle = true
    }

    @MainActor
    func saveEditor() {
        onSave?(editorText)
        ToastCenter.shared.key("toast.saved", icon: "square.and.arrow.down.fill")
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
    /// Single shared workspace so the URL handler (AppKit delegate) and the window (SwiftUI scene)
    /// drive the same panels — a second instance would mean a second window fighting over the
    /// terminal NSViews, which renders as empty frames.
    static let shared = TerminalWorkspaceManager()

    @Published var panels: [TerminalPanelModel]
    @Published private(set) var visiblePanelCount: Int
    @Published private(set) var focusedPanelIndex: Int

    private let prefs = AppPreferences.shared
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        self.panels = (0..<4).map { TerminalPanelModel(index: $0) }
        let savedCount = UserDefaults.standard.integer(forKey: "visiblePanelCount")
        self.visiblePanelCount = savedCount == 0 ? 1 : min(max(savedCount, 1), 4)
        self.focusedPanelIndex = 0
        ensureVisiblePanelsHaveTabs()

        prefs.$revision
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyAppearanceToAll()
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(forName: .ttshellSessionsChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.updateDockBadge() }
        }
    }

    func updateDockBadge() {
        let count = panels.reduce(0) { $0 + $1.tabs.filter { $0.kind == .shell && $0.isRunning }.count }
        NSApplication.shared.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
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
    func createTab(in panelIndex: Int, title: String? = nil, commandToRun: String? = nil, workingDirectory: String? = nil) -> TerminalTabModel? {
        guard let panel = panel(panelIndex) else { return nil }
        let tabNumber = panel.tabs.count + 1
        let tab = TerminalTabModel(title: title ?? "Shell \(tabNumber)")
        configure(tab.terminalView, panelIndex: panelIndex)
        panel.tabs.append(tab)
        panel.selectedTabID = tab.id
        focusPanel(panelIndex)
        updateDockBadge()

        let shell = prefs.resolvedShell()
        let base = URL(fileURLWithPath: shell).lastPathComponent
        let shellName = prefs.loginShell ? "-" + base : base
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let startDir = workingDirectory.flatMap { dir -> String? in
            var isDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: dir, isDirectory: &isDir) && isDir.boolValue ? dir : nil
        } ?? home
        if startDir != home { tab.currentDirectory = startDir }
        tab.terminalView.startProcess(executable: shell, execName: shellName, currentDirectory: startDir)

        let startup = prefs.shellStartupCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        if !startup.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.send(startup + "\n", to: panelIndex)
            }
        }

        if let commandToRun {
            DispatchQueue.main.asyncAfter(deadline: .now() + (startup.isEmpty ? 0.35 : 0.5)) { [weak self] in
                self?.send(commandToRun, to: panelIndex)
            }
        }
        return tab
    }

    func closeActiveTab(in panelIndex: Int) {
        guard let panel = panel(panelIndex), let selected = panel.selectedTab else { return }
        if selected.kind == .shell {
            selected.terminalView.terminate()
        }
        panel.tabs.removeAll { $0.id == selected.id }
        panel.selectedTabID = panel.tabs.last?.id
        updateDockBadge()
    }

    @discardableResult
    func openLocalFileEditor(path: String, in panelIndex: Int? = nil) -> TerminalTabModel? {
        let index = panelIndex ?? focusedPanelIndex
        guard let panel = panel(index) else { return nil }
        let name = (path as NSString).lastPathComponent
        let tab = TerminalTabModel(title: name.isEmpty ? "editor" : name, kind: .editor)
        tab.localPath = path
        tab.editorText = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        tab.onSave = { text in try? text.write(toFile: path, atomically: true, encoding: .utf8) }
        panel.tabs.append(tab)
        panel.selectedTabID = tab.id
        focusPanel(index)
        return tab
    }

    func openRemoteFileEditor(shortcut: SSHShortcut, remotePath: String, in panelIndex: Int? = nil) {
        let index = panelIndex ?? focusedPanelIndex
        guard let panel = panel(index) else { return }
        let name = (remotePath as NSString).lastPathComponent
        let tab = TerminalTabModel(title: name.isEmpty ? "remote" : name, kind: .editor)
        tab.editorStatus = "fetching"
        panel.tabs.append(tab)
        panel.selectedTabID = tab.id
        focusPanel(index)
        RemoteFileService.fetch(shortcut: shortcut, remotePath: remotePath) { result in
            switch result {
            case .success(let payload):
                tab.editorText = payload.text
                tab.localPath = payload.localPath
                tab.editorStatus = ""
                tab.onSave = { newText in
                    RemoteFileService.upload(shortcut: shortcut, localPath: payload.localPath, remotePath: remotePath, text: newText) { _ in }
                }
            case .failure(let error):
                tab.editorStatus = error.localizedDescription
            }
        }
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

    func insertText(_ text: String, to panelIndex: Int? = nil) {
        let index = panelIndex ?? focusedPanelIndex
        guard let tab = activeTabCreatingIfNeeded(in: index) else { return }
        let data = Array(text.utf8)
        tab.terminalView.send(source: tab.terminalView, data: data[...])
        focusPanel(index)
    }

    func cd(to path: String, in panelIndex: Int) {
        send(ShellSafety.cdCommand(to: path), to: panelIndex)
    }

    /// Opens a directory in a panel like `code .`: reuse the panel's live shell tab with a `cd`
    /// (no new tab, no new window); only spin up a tab if the panel has no running shell.
    func openDirectory(_ path: String, in panelIndex: Int) {
        guard let panel = panel(panelIndex) else { return }
        focusPanel(panelIndex)
        if let tab = panel.selectedTab, tab.kind == .shell, tab.isRunning {
            cd(to: path, in: panelIndex)
        } else {
            let name = (path as NSString).lastPathComponent
            createTab(in: panelIndex, title: name.isEmpty ? nil : name, workingDirectory: path)
        }
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

    private func applyAppearanceToAll() {
        for (index, panel) in panels.enumerated() {
            for tab in panel.tabs {
                applyAppearance(to: tab.terminalView, panelIndex: index)
            }
        }
    }

    private func configure(_ terminal: ManagedLocalTerminalView, panelIndex: Int) {
        terminal.autoresizingMask = [.width, .height]
        terminal.wantsLayer = true
        terminal.onFilesDropped = { [weak self] paths in
            guard let self else { return }
            let joined = paths.map { ShellSafety.singleQuoted($0) }.joined(separator: " ")
            self.insertText(joined + " ", to: panelIndex)
        }
        do {
            terminal.metalBufferingMode = .perFrameAggregated
            try terminal.setUseMetal(false)
        } catch {
        }
        applyAppearance(to: terminal, panelIndex: panelIndex)
    }

    private func applyAppearance(to terminal: ManagedLocalTerminalView, panelIndex: Int) {
        terminal.font = prefs.resolvedFont()
        terminal.nativeForegroundColor = prefs.foregroundColor
        let opacity = CGFloat(min(max(prefs.terminalOpacity, 0.3), 1.0))
        let bg = prefs.backgroundColor.withAlphaComponent(opacity)
        terminal.nativeBackgroundColor = bg
        terminal.caretColor = prefs.caretColor
        terminal.getTerminal().setCursorStyle(prefs.cursorStyle.swiftTermStyle)
        terminal.layer?.backgroundColor = bg.cgColor
        terminal.layer?.isOpaque = opacity >= 0.999
        terminal.setAliased(prefs.disableAntialiasing)
        terminal.needsDisplay = true
    }

    static func defaultShell() -> String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"], FileManager.default.isExecutableFile(atPath: shell) {
            return shell
        }
        return "/bin/zsh"
    }
}

final class ManagedLocalTerminalView: LocalProcessTerminalView {
    var onFilesDropped: (([String]) -> Void)?
    private var dropConfigured = false
    private var aliased = false

    func setAliased(_ value: Bool) {
        aliased = value
        applyAliasing()
        needsDisplay = true
    }

    private func applyAliasing() {
        wantsLayer = true
        guard let layer else { return }
        let backing = window?.backingScaleFactor ?? 2.0
        if aliased {
            layer.shouldRasterize = true
            layer.rasterizationScale = 1.0
            layer.magnificationFilter = .nearest
            layer.minificationFilter = .nearest
        } else {
            layer.shouldRasterize = false
            layer.rasterizationScale = backing
            layer.magnificationFilter = .linear
            layer.minificationFilter = .linear
        }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        applyAliasing()
    }

    private func configureDropIfNeeded() {
        guard !dropConfigured else { return }
        dropConfigured = true
        registerForDraggedTypes([.fileURL])
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureDropIfNeeded()
    }

    override var isOpaque: Bool { false }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return hasFileURLs(sender) ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return hasFileURLs(sender) ? .copy : []
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return hasFileURLs(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = fileURLs(from: sender)
        guard !urls.isEmpty else { return false }
        onFilesDropped?(urls.map { $0.path })
        return true
    }

    private func hasFileURLs(_ sender: NSDraggingInfo) -> Bool {
        sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
    }

    private func fileURLs(from sender: NSDraggingInfo) -> [URL] {
        let objects = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        return objects ?? []
    }
}

final class TerminalProcessDelegate: NSObject, LocalProcessTerminalViewDelegate {
    weak var owner: TerminalTabModel?

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        DispatchQueue.main.async { [weak self] in
            guard let owner = self?.owner, !owner.hasCustomTitle else { return }
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
            NotificationCenter.default.post(name: .ttshellSessionsChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let ttshellSessionsChanged = Notification.Name("ttshellSessionsChanged")
}
