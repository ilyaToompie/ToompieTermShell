import AppKit
import SwiftData
import SwiftUI

struct SSHSidebarTab: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var terminalManager: TerminalWorkspaceManager
    @Query(sort: \SSHShortcut.name) private var shortcuts: [SSHShortcut]
    @State private var showingAddSheet = false
    @State private var editingShortcut: SSHShortcut?

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("SSH", systemImage: "network")
                    .font(.headline)
                Spacer()
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add SSH shortcut")
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    if shortcuts.isEmpty {
                        Text("No SSH shortcuts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ForEach(shortcuts) { shortcut in
                        SidebarCard {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(shortcut.name)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Text("\(shortcut.username)@\(shortcut.host):\(shortcut.port)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button {
                                    editingShortcut = shortcut
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.plain)
                                .help("Edit")

                                Button {
                                    KeychainStore.deletePassword(for: shortcut.id)
                                    modelContext.delete(shortcut)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.red)
                                .help("Delete")
                            }

                            HStack {
                                Button {
                                    connect(shortcut, in: terminalManager.focusedPanelIndex)
                                } label: {
                                    Label("Connect", systemImage: "bolt.horizontal")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button {
                                    terminalManager.createTab(in: terminalManager.focusedPanelIndex)
                                    connect(shortcut, in: terminalManager.focusedPanelIndex)
                                } label: {
                                    Image(systemName: "plus.square.on.square")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("Open in new tab of focused terminal")
                            }

                            TargetSegments { index in
                                connect(shortcut, in: index)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            SSHShortcutEditor(shortcut: nil)
                .frame(width: 620)
        }
        .sheet(item: $editingShortcut) { shortcut in
            SSHShortcutEditor(shortcut: shortcut)
                .frame(width: 620)
        }
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
    let shortcut: SSHShortcut?

    @State private var name: String
    @State private var host: String
    @State private var port: Int
    @State private var username: String
    @State private var authType: SSHAuthType
    @State private var privateKeyPath: String
    @State private var password: String
    @State private var rememberPassword: Bool
    @State private var startupDirectory: String
    @State private var startupCommand: String

    init(shortcut: SSHShortcut?) {
        self.shortcut = shortcut
        _name = State(initialValue: shortcut?.name ?? "")
        _host = State(initialValue: shortcut?.host ?? "")
        _port = State(initialValue: shortcut?.port ?? 22)
        _username = State(initialValue: shortcut?.username ?? NSUserName())
        _authType = State(initialValue: shortcut?.authType ?? .key)
        _privateKeyPath = State(initialValue: shortcut?.privateKeyPath ?? "")
        _password = State(initialValue: "")
        _rememberPassword = State(initialValue: shortcut?.rememberPassword ?? false)
        _startupDirectory = State(initialValue: shortcut?.startupDirectory ?? "")
        _startupCommand = State(initialValue: shortcut?.startupCommand ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(shortcut == nil ? "Add SSH Shortcut" : "Edit SSH Shortcut")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 12) {
                EditorRow("Name") {
                    EditorTextField(title: "Name", text: $name)
                }

                EditorRow("Host") {
                    EditorTextField(title: "Host", text: $host)
                }

                EditorRow("Port") {
                    HStack(spacing: 8) {
                        TextField("Port", value: $port, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                        Stepper("Port", value: $port, in: 1...65535)
                            .labelsHidden()
                    }
                }

                EditorRow("Username") {
                    EditorTextField(title: "Username", text: $username)
                }

                EditorRow("Auth Type") {
                    Picker("Auth Type", selection: $authType) {
                        ForEach(SSHAuthType.allCases) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 260)
                }

                if authType == .key {
                    EditorRow("Private Key Path") {
                        HStack(spacing: 8) {
                            EditorTextField(title: "Private Key Path", text: $privateKeyPath)
                            Button {
                                selectPrivateKey()
                            } label: {
                                Image(systemName: "folder")
                            }
                            .help("Choose private key")
                        }
                    }
                } else {
                    EditorRow("Remember") {
                        Toggle("Store password in Keychain", isOn: $rememberPassword)
                    }

                    EditorRow("Password") {
                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                EditorRow("Startup Directory") {
                    EditorTextField(title: "Startup Directory", text: $startupDirectory)
                }

                EditorRow("Startup Command") {
                    TextField("Startup Command", text: $startupCommand, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || host.isEmpty || username.isEmpty)
            }
        }
        .padding(22)
    }

    private func save() {
        let target = shortcut ?? SSHShortcut(name: name, host: host, port: port, username: username)
        target.name = name
        target.host = host
        target.port = port
        target.username = username
        target.authType = authType
        target.privateKeyPath = authType == .key ? privateKeyPath : ""
        target.rememberPassword = authType == .password && rememberPassword
        target.startupDirectory = startupDirectory
        target.startupCommand = startupCommand
        target.updatedAt = Date()

        if shortcut == nil {
            modelContext.insert(target)
        }

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
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
        if panel.runModal() == .OK, let url = panel.url {
            privateKeyPath = url.path
        }
    }
}
