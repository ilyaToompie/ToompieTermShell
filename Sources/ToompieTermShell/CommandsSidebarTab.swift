import AppKit
import SwiftData
import SwiftUI

struct CommandsSidebarTab: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var terminalManager: TerminalWorkspaceManager
    @Query(sort: \CommandShortcut.name) private var commands: [CommandShortcut]
    @State private var showingAddSheet = false
    @State private var editingCommand: CommandShortcut?

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Commands", systemImage: "terminal")
                    .font(.headline)
                Spacer()
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add command shortcut")
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    if commands.isEmpty {
                        Text("No command shortcuts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ForEach(commands) { command in
                        SidebarCard {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(command.name)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    if !command.commandDescription.isEmpty {
                                        Text(command.commandDescription)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    if !command.tags.isEmpty {
                                        Text(command.tags)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Button {
                                    editingCommand = command
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.plain)
                                .help("Edit")

                                Button {
                                    modelContext.delete(command)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.red)
                                .help("Delete")
                            }

                            Text(command.command)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(3)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)

                            HStack {
                                Button {
                                    Clipboard.copy(command.command)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button {
                                    run(command, in: terminalManager.focusedPanelIndex)
                                } label: {
                                    Label("Run", systemImage: "play.fill")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            TargetSegments { index in
                                run(command, in: index)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            CommandShortcutEditor(command: nil)
                .frame(width: 640)
        }
        .sheet(item: $editingCommand) { command in
            CommandShortcutEditor(command: command)
                .frame(width: 640)
        }
    }

    private func run(_ command: CommandShortcut, in panelIndex: Int) {
        guard CommandConfirmation.shouldRun(command.command) else { return }
        let workingDirectory = command.workingDirectory.isEmpty ? nil : command.workingDirectory
        terminalManager.runCommand(command.command, workingDirectory: workingDirectory, in: panelIndex)
    }
}

struct CommandShortcutEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let command: CommandShortcut?

    @State private var name: String
    @State private var commandText: String
    @State private var workingDirectory: String
    @State private var description: String
    @State private var tags: String

    init(command: CommandShortcut?) {
        self.command = command
        _name = State(initialValue: command?.name ?? "")
        _commandText = State(initialValue: command?.command ?? "")
        _workingDirectory = State(initialValue: command?.workingDirectory ?? "")
        _description = State(initialValue: command?.commandDescription ?? "")
        _tags = State(initialValue: command?.tags ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(command == nil ? "Add Command Shortcut" : "Edit Command Shortcut")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 12) {
                EditorRow("Name") {
                    EditorTextField(title: "Name", text: $name)
                }

                EditorRow("Command") {
                    TextField("Command", text: $commandText, axis: .vertical)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(5...10)
                        .frame(minHeight: 120)
                }

                EditorRow("Working Directory") {
                    HStack(spacing: 8) {
                        EditorTextField(title: "Working Directory", text: $workingDirectory)
                        Button {
                            selectDirectory()
                        } label: {
                            Image(systemName: "folder")
                        }
                        .help("Choose working directory")
                    }
                }

                EditorRow("Description") {
                    TextField("Description", text: $description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                }

                EditorRow("Tags / Group") {
                    EditorTextField(title: "Tags / Group", text: $tags)
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
                .disabled(name.isEmpty || commandText.isEmpty)
            }
        }
        .padding(22)
    }

    private func save() {
        let target = command ?? CommandShortcut(name: name, command: commandText)
        target.name = name
        target.command = commandText
        target.workingDirectory = workingDirectory
        target.commandDescription = description
        target.tags = tags
        target.updatedAt = Date()
        if command == nil {
            modelContext.insert(target)
        }
        dismiss()
    }

    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            workingDirectory = url.path
        }
    }
}
