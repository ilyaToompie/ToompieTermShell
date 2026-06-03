import AppKit
import SwiftData
import SwiftUI

struct SSHSidebarTab: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var terminalManager: TerminalWorkspaceManager
    @EnvironmentObject private var loc: LocalizationManager
    @EnvironmentObject private var scope: ScopeManager
    @Query(sort: \SSHShortcut.name) private var allShortcuts: [SSHShortcut]
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var search = ""
    @State private var filterTag: UUID?
    @State private var showingAddSheet = false
    @State private var editingShortcut: SSHShortcut?
    @State private var ftpTarget: SSHShortcut?

    private var shortcuts: [SSHShortcut] {
        allShortcuts.filter { item in
            guard item.projectID == scope.currentProjectID else { return false }
            if let filterTag, !item.hasTag(filterTag) { return false }
            if !search.isEmpty {
                let q = search.lowercased()
                return item.name.lowercased().contains(q) || item.host.lowercased().contains(q) || item.username.lowercased().contains(q)
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                SectionTitle(title: loc("tab.ssh"), systemImage: "network")
                ShimmerAddButton { showingAddSheet = true }
            }
            SearchField(text: $search, placeholder: loc("search.placeholder"))
            TagFilterBar(tags: tags, selected: $filterTag)

            ScrollView {
                LazyVStack(spacing: 8) {
                    if shortcuts.isEmpty { EmptyHint() }
                    ForEach(shortcuts) { shortcut in
                        SidebarCard {
                            HStack(alignment: .firstTextBaseline) {
                                Text(shortcut.icon).font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(shortcut.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                                    Text("\(shortcut.username)@\(shortcut.host):\(shortcut.port)")
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                ScopeMoveMenu(
                                    currentProjectID: scope.currentProjectID,
                                    onCopy: { copy(shortcut, to: $0) },
                                    onMove: { shortcut.projectID = $0; shortcut.updatedAt = Date() }
                                )
                                RowButtons(onEdit: { editingShortcut = shortcut }, onDelete: {
                                    KeychainStore.deletePassword(for: shortcut.id)
                                    modelContext.delete(shortcut)
                                })
                            }
                            TagRowChips(ids: shortcut.tagIDs, tags: tags)
                            HStack {
                                TerminalTargetMenu(title: loc("common.connect"), systemImage: "bolt.horizontal") { connect(shortcut, in: $0) }
                                Button { ftpTarget = shortcut } label: { Label(loc("ssh.files"), systemImage: "folder.fill") }
                                    .buttonStyle(.bordered).controlSize(.small)
                                    .onHover { hovering in if hovering { RemoteFileService.prewarm(shortcut: shortcut) } }
                                adminMenu(shortcut)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) { SSHShortcutEditor(shortcut: nil).frame(width: 620) }
        .sheet(item: $editingShortcut) { SSHShortcutEditor(shortcut: $0).frame(width: 620) }
        .sheet(item: $ftpTarget) { target in
            SFTPBrowserView(shortcut: target)
        }
    }

    private func copy(_ s: SSHShortcut, to project: UUID?) {
        let dup = SSHShortcut(name: s.name, host: s.host, port: s.port, username: s.username, authType: s.authType, privateKeyPath: s.privateKeyPath, rememberPassword: false, startupDirectory: s.startupDirectory, startupCommand: s.startupCommand, icon: s.icon, tagIDsRaw: s.tagIDsRaw, projectID: project)
        modelContext.insert(dup)
    }

    private func adminMenu(_ shortcut: SSHShortcut) -> some View {
        Menu {
            ForEach(AdminCommands.groups, id: \.0) { group in
                Section(group.0) {
                    ForEach(group.1) { item in
                        Button {
                            terminalManager.runCommand(item.command, workingDirectory: nil, in: terminalManager.focusedPanelIndex)
                        } label: { Label(item.title, systemImage: item.icon) }
                    }
                }
            }
            Divider()
            Button { installKey(shortcut) } label: { Label(loc("ssh.installKey"), systemImage: "key.fill") }
        } label: {
            Image(systemName: "wrench.and.screwdriver")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .controlSize(.small)
        .help(loc("ssh.admin"))
    }

    private func installKey(_ shortcut: SSHShortcut) {
        var parts = ["ssh-copy-id", "-p", "\(max(shortcut.port, 1))"]
        if shortcut.authType == .key, !shortcut.privateKeyPath.isEmpty {
            parts.append("-i")
            parts.append(ShellSafety.singleQuoted(shortcut.privateKeyPath))
        }
        parts.append(ShellSafety.singleQuoted("\(shortcut.username)@\(shortcut.host)"))
        terminalManager.runCommand(parts.joined(separator: " "), workingDirectory: nil, in: terminalManager.focusedPanelIndex)
    }

    private func connect(_ shortcut: SSHShortcut, in panelIndex: Int) {
        var command = SSHCommandBuilder.command(for: shortcut)
        command += SSHCommandBuilder.startupSuffix(for: shortcut)
        if shortcut.authType == .password {
            command += "\n"
        }
        terminalManager.runCommand(command, workingDirectory: nil, in: panelIndex)
    }
}

struct SSHShortcutEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var scope: ScopeManager
    @EnvironmentObject private var prefs: AppPreferences
    @EnvironmentObject private var loc: LocalizationManager
    let shortcut: SSHShortcut?

    @State private var name: String
    @State private var icon: String
    @State private var host: String
    @State private var port: Int
    @State private var username: String
    @State private var authType: SSHAuthType
    @State private var privateKeyPath: String
    @State private var password: String
    @State private var rememberPassword: Bool
    @State private var startupDirectory: String
    @State private var startupCommand: String
    @State private var tagIDs: [UUID]

    init(shortcut: SSHShortcut?) {
        self.shortcut = shortcut
        _name = State(initialValue: shortcut?.name ?? "")
        _icon = State(initialValue: shortcut?.icon ?? "🖥️")
        _host = State(initialValue: shortcut?.host ?? "")
        _port = State(initialValue: shortcut?.port ?? AppPreferences.shared.defaultPort)
        _username = State(initialValue: shortcut?.username ?? AppPreferences.shared.defaultUser)
        _authType = State(initialValue: shortcut?.authType ?? .key)
        _privateKeyPath = State(initialValue: shortcut?.privateKeyPath ?? "")
        _password = State(initialValue: "")
        _rememberPassword = State(initialValue: shortcut?.rememberPassword ?? false)
        _startupDirectory = State(initialValue: shortcut?.startupDirectory ?? "")
        _startupCommand = State(initialValue: shortcut?.startupCommand ?? "")
        _tagIDs = State(initialValue: shortcut?.tagIDs ?? [])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(shortcut == nil ? loc("ssh.add") : loc("common.edit"))
                    .font(.title3.weight(.semibold))

                VStack(alignment: .leading, spacing: 12) {
                    EditorRow(loc("ssh.icon")) { EmojiField(text: $icon) }
                    EditorRow(loc("common.name")) { EditorTextField(title: loc("common.name"), text: $name) }
                    EditorRow(loc("servers.host")) { EditorTextField(title: loc("servers.host"), text: $host) }
                    EditorRow(loc("servers.port")) {
                        HStack(spacing: 8) {
                            TextField("Port", value: $port, format: .number).textFieldStyle(.roundedBorder).frame(width: 90)
                            Stepper("Port", value: $port, in: 1...65535).labelsHidden()
                        }
                    }
                    EditorRow(loc("servers.user")) { EditorTextField(title: loc("servers.user"), text: $username) }
                    EditorRow(loc("ssh.auth")) {
                        Picker("", selection: $authType) {
                            ForEach(SSHAuthType.allCases) { Text($0.rawValue.capitalized).tag($0) }
                        }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 240)
                    }
                    if authType == .key {
                        EditorRow(loc("ssh.key")) {
                            HStack(spacing: 8) {
                                EditorTextField(title: loc("ssh.key"), text: $privateKeyPath)
                                Button { selectPrivateKey() } label: { Image(systemName: "folder") }
                            }
                        }
                    } else {
                        EditorRow(loc("ssh.remember")) { Toggle(loc("ssh.remember"), isOn: $rememberPassword).labelsHidden() }
                        EditorRow(loc("ssh.password")) { SecureField(loc("ssh.password"), text: $password).textFieldStyle(.roundedBorder) }
                    }
                    EditorRow(loc("ssh.startupDir")) { EditorTextField(title: loc("ssh.startupDir"), text: $startupDirectory) }
                    EditorRow(loc("ssh.startupCmd")) {
                        TextField(loc("ssh.startupCmd"), text: $startupCommand, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...4)
                    }
                    EditorRow(loc("tags.title")) { TagPicker(selectedIDs: $tagIDs) }
                }

                EditorButtons(disabled: name.isEmpty || host.isEmpty || username.isEmpty, onCancel: { dismiss() }, onSave: save)
            }
            .padding(22)
        }
    }

    private func save() {
        let target = shortcut ?? SSHShortcut(name: name, host: host, port: port, username: username, projectID: scope.currentProjectID)
        target.name = name
        target.icon = icon.isEmpty ? "🖥️" : icon
        target.host = host
        target.port = port
        target.username = username
        target.authType = authType
        target.privateKeyPath = authType == .key ? privateKeyPath : ""
        target.rememberPassword = authType == .password && rememberPassword
        target.startupDirectory = startupDirectory
        target.startupCommand = startupCommand
        target.tagIDs = tagIDs
        target.updatedAt = Date()

        if shortcut == nil { modelContext.insert(target) }

        if authType == .password, rememberPassword, !password.isEmpty {
            try? KeychainStore.savePassword(password, for: target.id)
        } else if authType != .password || !rememberPassword {
            KeychainStore.deletePassword(for: target.id)
        }
        dismiss()
    }

    private func selectPrivateKey() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = URL(fileURLWithPath: prefs.sshKeyDirectory)
        if panel.runModal() == .OK, let url = panel.url {
            privateKeyPath = url.path
        }
    }
}
