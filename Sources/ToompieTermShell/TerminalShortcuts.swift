import AppKit
import SwiftData
import SwiftUI

/// What a per-terminal shortcut chip does when clicked.
enum TerminalShortcutKind: String, Codable, CaseIterable, Identifiable {
    case command   // run a saved CommandShortcut (by id)
    case ssh       // connect a saved SSHShortcut (by id)
    case custom    // run an ad-hoc command string
    case folder    // cd into a directory

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .command: return "tshortcut.kind.command"
        case .ssh: return "tshortcut.kind.ssh"
        case .custom: return "tshortcut.kind.custom"
        case .folder: return "tshortcut.kind.folder"
        }
    }
}

/// A shortcut pinned to a *terminal window* (panel index, 0–3). Keyed by panel
/// index rather than the volatile per-session tab UUID, so the chips survive a
/// tab being closed and reappear on the same terminal window next launch.
struct TerminalShortcut: Identifiable, Codable, Equatable {
    var id: UUID
    var panel: Int
    var kindRaw: String
    var refID: UUID?      // saved command / ssh id, for .command / .ssh
    var raw: String       // ad-hoc command (.custom) or folder path (.folder)
    var label: String
    var icon: String      // emoji / "sf:" / "gif:" (see IconRef)
    var order: Int

    var kind: TerminalShortcutKind {
        get { TerminalShortcutKind(rawValue: kindRaw) ?? .custom }
        set { kindRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), panel: Int, kind: TerminalShortcutKind, refID: UUID? = nil,
         raw: String = "", label: String, icon: String, order: Int = 0) {
        self.id = id
        self.panel = panel
        self.kindRaw = kind.rawValue
        self.refID = refID
        self.raw = raw
        self.label = label
        self.icon = icon
        self.order = order
    }
}

@MainActor
final class TerminalShortcutStore: ObservableObject {
    static let shared = TerminalShortcutStore()
    @Published private(set) var all: [TerminalShortcut] = [] { didSet { persist() } }

    private let key = "terminalShortcuts"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([TerminalShortcut].self, from: data) {
            all = decoded
        }
    }

    func shortcuts(for panel: Int) -> [TerminalShortcut] {
        all.filter { $0.panel == panel }.sorted { $0.order < $1.order }
    }

    func add(_ shortcut: TerminalShortcut) {
        var s = shortcut
        s.order = (shortcuts(for: s.panel).map(\.order).max() ?? -1) + 1
        all.append(s)
    }

    func update(_ shortcut: TerminalShortcut) {
        guard let idx = all.firstIndex(where: { $0.id == shortcut.id }) else { return }
        all[idx] = shortcut
    }

    func remove(_ id: UUID) {
        all.removeAll { $0.id == id }
    }

    /// Reorders within a panel, dropping `movedID` onto `targetID` — after it when
    /// dragged down, before it when dragged up. Inserting at the target's *original*
    /// index (computed before removal) gives that, and never no-ops an adjacent swap.
    func move(in panel: Int, movedID: UUID, ontoID targetID: UUID) {
        guard movedID != targetID else { return }
        var ordered = shortcuts(for: panel)
        guard let from = ordered.firstIndex(where: { $0.id == movedID }),
              let to = ordered.firstIndex(where: { $0.id == targetID }) else { return }
        let moved = ordered.remove(at: from)
        ordered.insert(moved, at: min(to, ordered.count))
        var rank: [UUID: Int] = [:]
        for (i, s) in ordered.enumerated() { rank[s.id] = i }
        for i in all.indices where all[i].panel == panel {
            if let r = rank[all[i].id] { all[i].order = r }
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

/// The row of shortcut chips (always visible) plus the add button (hover-only),
/// dropped into a terminal panel's header next to the new-tab / close buttons.
struct TerminalShortcutBar: View {
    let panelIndex: Int
    let showAddButton: Bool

    @EnvironmentObject private var terminalManager: TerminalWorkspaceManager
    @EnvironmentObject private var loc: LocalizationManager
    @ObservedObject private var store = TerminalShortcutStore.shared
    @Query(sort: \CommandShortcut.name) private var commands: [CommandShortcut]
    @Query(sort: \SSHShortcut.name) private var ssh: [SSHShortcut]

    @State private var showingEditor = false
    @State private var editing: TerminalShortcut?

    private var shortcuts: [TerminalShortcut] { store.shortcuts(for: panelIndex) }

    var body: some View {
        HStack(spacing: 4) {
            // "+" sits to the LEFT of the chips: the bar is right-anchored (against
            // the new-tab/close buttons), so a left-side add button grows leftward
            // when it appears on hover and the existing chips don't shift.
            if showAddButton {
                Button {
                    editing = nil
                    showingEditor = true
                } label: {
                    Image(systemName: "plus.app")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help(loc("tshortcut.add"))
            }
            ForEach(shortcuts) { shortcut in
                chip(shortcut)
            }
        }
        .sheet(isPresented: $showingEditor) {
            TerminalShortcutEditor(panelIndex: panelIndex, existing: editing).frame(width: 480)
        }
    }

    private func chip(_ shortcut: TerminalShortcut) -> some View {
        Button { run(shortcut) } label: {
            IconView(shortcut.icon, size: 18)
                .frame(width: 20, height: 20)
                // GIF icons render via a passthrough NSView (nil hit-test); an explicit
                // content shape keeps the chip itself tappable to run the shortcut.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(shortcut.label)
        .contextMenu {
            Button(loc("common.edit")) { editing = shortcut; showingEditor = true }
            Button(role: .destructive) { store.remove(shortcut.id) } label: { Text(loc("common.delete")) }
        }
        // Hold Control to rearrange; a plain click just runs the shortcut. SwiftUI
        // supplies its own floating drag preview, so no manual highlight state is
        // tracked (which previously could get stuck if a drag was cancelled).
        .onDrag {
            guard NSEvent.modifierFlags.contains(.control) else { return NSItemProvider() }
            return NSItemProvider(object: shortcut.id.uuidString as NSString)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let movedID = UUID(uuidString: raw), movedID != shortcut.id else { return false }
            store.move(in: panelIndex, movedID: movedID, ontoID: shortcut.id)
            return true
        }
    }

    private func run(_ shortcut: TerminalShortcut) {
        switch shortcut.kind {
        case .command:
            if let c = commands.first(where: { $0.id == shortcut.refID }) {
                let dir = c.workingDirectory.isEmpty ? nil : c.workingDirectory
                terminalManager.runCommand(c.command, workingDirectory: dir, in: panelIndex, clearLine: true)
            } else if !shortcut.raw.isEmpty {
                terminalManager.runCommand(shortcut.raw, workingDirectory: nil, in: panelIndex, clearLine: true)
            }
        case .ssh:
            guard let host = ssh.first(where: { $0.id == shortcut.refID }) else { return }
            var cmd = SSHCommandBuilder.command(for: host) + SSHCommandBuilder.startupSuffix(for: host)
            if host.authType == .password { cmd += "\n" }
            terminalManager.runCommand(cmd, workingDirectory: nil, in: panelIndex, clearLine: true)
        case .custom:
            let cmd = shortcut.raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cmd.isEmpty else { return }
            terminalManager.runCommand(cmd, workingDirectory: nil, in: panelIndex, clearLine: true)
        case .folder:
            guard !shortcut.raw.isEmpty else { return }
            terminalManager.cd(to: shortcut.raw, in: panelIndex, clearLine: true)
        }
    }
}

struct TerminalShortcutEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var loc: LocalizationManager
    @ObservedObject private var store = TerminalShortcutStore.shared
    @Query(sort: \CommandShortcut.name) private var commands: [CommandShortcut]
    @Query(sort: \SSHShortcut.name) private var ssh: [SSHShortcut]

    let panelIndex: Int
    let existing: TerminalShortcut?

    @State private var kind: TerminalShortcutKind
    @State private var refID: UUID?
    @State private var raw: String
    @State private var label: String
    @State private var icon: String

    init(panelIndex: Int, existing: TerminalShortcut?) {
        self.panelIndex = panelIndex
        self.existing = existing
        _kind = State(initialValue: existing?.kind ?? .command)
        _refID = State(initialValue: existing?.refID)
        _raw = State(initialValue: existing?.raw ?? "")
        _label = State(initialValue: existing?.label ?? "")
        _icon = State(initialValue: existing?.icon ?? "⚡️")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? loc("tshortcut.add") : loc("common.edit"))
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 12) {
                EditorRow(loc("tshortcut.kind")) {
                    Picker("", selection: $kind) {
                        ForEach(TerminalShortcutKind.allCases) { k in Text(loc(k.labelKey)).tag(k) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .onChange(of: kind) { _, _ in refID = nil }
                }

                switch kind {
                case .command:
                    EditorRow(loc("tab.commands")) {
                        Picker("", selection: $refID) {
                            Text(loc("common.choose")).tag(UUID?.none)
                            ForEach(commands) { c in Text(c.name).tag(UUID?.some(c.id)) }
                        }
                        .labelsHidden()
                        .onChange(of: refID) { _, id in applyDefaults(commandID: id, sshID: nil) }
                    }
                case .ssh:
                    EditorRow(loc("tab.ssh")) {
                        Picker("", selection: $refID) {
                            Text(loc("common.choose")).tag(UUID?.none)
                            ForEach(ssh) { s in Text(s.name).tag(UUID?.some(s.id)) }
                        }
                        .labelsHidden()
                        .onChange(of: refID) { _, id in applyDefaults(commandID: nil, sshID: id) }
                    }
                case .custom:
                    EditorRow(loc("commands.command")) {
                        TextField(loc("commands.command"), text: $raw, axis: .vertical)
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...5)
                    }
                case .folder:
                    EditorRow(loc("commands.dir")) {
                        HStack(spacing: 8) {
                            EditorTextField(title: loc("commands.dir"), text: $raw)
                            Button { pickFolder() } label: { Image(systemName: "folder") }
                        }
                    }
                }

                EditorRow(loc("common.name")) { EditorTextField(title: loc("common.name"), text: $label) }
                EditorRow(loc("ssh.icon")) { IconPicker(icon: $icon, allowGif: true) }
            }

            EditorButtons(disabled: !isValid, onCancel: { dismiss() }, onSave: save)
        }
        .padding(22)
    }

    private var isValid: Bool {
        switch kind {
        case .command, .ssh: return refID != nil
        case .custom, .folder: return !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func applyDefaults(commandID: UUID?, sshID: UUID?) {
        if let c = commands.first(where: { $0.id == commandID }) {
            if label.isEmpty { label = c.name }
            if icon.isEmpty || icon == "⚡️" { icon = c.icon }
        } else if let s = ssh.first(where: { $0.id == sshID }) {
            if label.isEmpty { label = s.name }
            if icon.isEmpty || icon == "⚡️" { icon = s.icon }
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            raw = url.path
            if label.isEmpty { label = url.lastPathComponent }
        }
    }

    private func save() {
        let finalLabel = label.isEmpty ? defaultLabel() : label
        let finalIcon = icon.isEmpty ? "⚡️" : icon
        // A command/ssh shortcut resolves via refID; don't persist a leftover folder
        // path / custom string typed before switching kind — run() would otherwise
        // fall back to it as a shell command if the referenced entity is deleted.
        let finalRaw = (kind == .command || kind == .ssh) ? "" : raw
        if var entity = existing {
            entity.kind = kind
            entity.refID = refID
            entity.raw = finalRaw
            entity.label = finalLabel
            entity.icon = finalIcon
            store.update(entity)
        } else {
            store.add(TerminalShortcut(panel: panelIndex, kind: kind, refID: refID, raw: finalRaw, label: finalLabel, icon: finalIcon))
        }
        dismiss()
    }

    private func defaultLabel() -> String {
        switch kind {
        case .command: return commands.first(where: { $0.id == refID })?.name ?? "cmd"
        case .ssh: return ssh.first(where: { $0.id == refID })?.name ?? "ssh"
        case .custom: return String(raw.prefix(18))
        case .folder: return (raw as NSString).lastPathComponent
        }
    }
}
