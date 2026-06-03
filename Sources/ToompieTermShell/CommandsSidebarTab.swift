import AppKit
import SwiftData
import SwiftUI

struct CommandsSidebarTab: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var terminalManager: TerminalWorkspaceManager
    @EnvironmentObject private var loc: LocalizationManager
    @EnvironmentObject private var prefs: AppPreferences
    @EnvironmentObject private var scope: ScopeManager
    @Query(sort: \CommandShortcut.name) private var allCommands: [CommandShortcut]
    @Query(sort: \Tag.name) private var tags: [Tag]
    @AppStorage("commandsSimple") private var simple = false
    @State private var search = ""
    @State private var filterTag: UUID?
    @State private var showingAddSheet = false
    @State private var editingCommand: CommandShortcut?
    @State private var fillRequest: FillRequest?

    struct FillRequest: Identifiable {
        let id = UUID()
        let command: String
        let workingDirectory: String
        let variables: [String]
        let panelIndex: Int
    }

    private var commands: [CommandShortcut] {
        allCommands.filter { command in
            guard command.projectID == scope.currentProjectID else { return false }
            if let filterTag, !command.hasTag(filterTag) { return false }
            if !search.isEmpty {
                let q = search.lowercased()
                return command.name.lowercased().contains(q) || command.command.lowercased().contains(q) || command.commandDescription.lowercased().contains(q)
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                SectionTitle(title: loc("tab.commands"), systemImage: "terminal.fill")
                Toggle(loc("view.simple"), isOn: $simple).toggleStyle(.switch).controlSize(.mini)
                ShimmerAddButton { showingAddSheet = true }
            }
            SearchField(text: $search, placeholder: loc("search.placeholder"))
            TagFilterBar(tags: tags, selected: $filterTag)

            ScrollView {
                LazyVStack(spacing: 6) {
                    if commands.isEmpty { EmptyHint() }
                    ForEach(commands) { command in
                        if simple { simpleRow(command) } else { detailedRow(command) }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) { CommandShortcutEditor(command: nil).frame(width: 640) }
        .sheet(item: $editingCommand) { CommandShortcutEditor(command: $0).frame(width: 640) }
        .sheet(item: $fillRequest) { request in
            SnippetFillSheet(commandText: request.command, variables: request.variables) { finalCommand in
                runResolved(finalCommand, workingDirectory: request.workingDirectory, in: request.panelIndex)
            }
        }
    }

    private func simpleRow(_ command: CommandShortcut) -> some View {
        HStack(spacing: 8) {
            Text(command.icon).font(.callout)
            Text(command.name).font(.subheadline.weight(.medium)).lineLimit(1)
            Spacer(minLength: 4)
            TerminalTargetMenu(title: loc("common.run"), systemImage: "play.fill") { run(command, in: $0) }
            Button(role: .destructive) { modelContext.delete(command) } label: { Image(systemName: "trash") }
                .buttonStyle(.plain).foregroundStyle(.red)
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08)))
    }

    private func detailedRow(_ command: CommandShortcut) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(command.icon)
                VStack(alignment: .leading, spacing: 1) {
                    Text(command.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                    if !command.commandDescription.isEmpty {
                        Text(command.commandDescription).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                ScopeMoveMenu(
                    currentProjectID: scope.currentProjectID,
                    onCopy: { target in
                        let dup = CommandShortcut(name: command.name, command: command.command, workingDirectory: command.workingDirectory, commandDescription: command.commandDescription, icon: command.icon, tagIDsRaw: command.tagIDsRaw, projectID: target)
                        modelContext.insert(dup)
                    },
                    onMove: { command.projectID = $0; command.updatedAt = Date() }
                )
                RowButtons(onEdit: { editingCommand = command }, onDelete: { modelContext.delete(command) })
            }
            Text(command.command)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
            TagRowChips(ids: command.tagIDs, tags: tags)
            HStack {
                Button { Clipboard.copy(command.command) } label: { Label(loc("common.copy"), systemImage: "doc.on.doc") }
                    .buttonStyle(.bordered).controlSize(.small)
                TerminalTargetMenu(title: loc("common.run"), systemImage: "play.fill") { run(command, in: $0) }
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08)))
    }

    private func run(_ command: CommandShortcut, in panelIndex: Int) {
        let variables = Snippet.variables(in: command.command)
        if variables.isEmpty {
            runResolved(command.command, workingDirectory: command.workingDirectory, in: panelIndex)
        } else {
            fillRequest = FillRequest(command: command.command, workingDirectory: command.workingDirectory, variables: variables, panelIndex: panelIndex)
        }
    }

    private func runResolved(_ command: String, workingDirectory: String, in panelIndex: Int) {
        guard !prefs.confirmDangerous || CommandConfirmation.shouldRun(command) else { return }
        let dir = workingDirectory.isEmpty ? nil : workingDirectory
        terminalManager.runCommand(command, workingDirectory: dir, in: panelIndex)
    }
}

struct CommandShortcutEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var loc: LocalizationManager
    @EnvironmentObject private var scope: ScopeManager
    let command: CommandShortcut?

    @State private var name: String
    @State private var icon: String
    @State private var commandText: String
    @State private var workingDirectory: String
    @State private var description: String
    @State private var tagIDs: [UUID]

    init(command: CommandShortcut?) {
        self.command = command
        _name = State(initialValue: command?.name ?? "")
        _icon = State(initialValue: command?.icon ?? "⚡️")
        _commandText = State(initialValue: command?.command ?? "")
        _workingDirectory = State(initialValue: command?.workingDirectory ?? "")
        _description = State(initialValue: command?.commandDescription ?? "")
        _tagIDs = State(initialValue: command?.tagIDs ?? [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(command == nil ? loc("commands.add") : loc("common.edit"))
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 12) {
                EditorRow(loc("ssh.icon")) { EmojiField(text: $icon) }
                EditorRow(loc("common.name")) { EditorTextField(title: loc("common.name"), text: $name) }
                EditorRow(loc("commands.command")) {
                    TextField(loc("commands.command"), text: $commandText, axis: .vertical)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(5...10)
                        .frame(minHeight: 110)
                }
                EditorRow(loc("commands.dir")) {
                    HStack(spacing: 8) {
                        EditorTextField(title: loc("commands.dir"), text: $workingDirectory)
                        Button { selectDirectory() } label: { Image(systemName: "folder") }
                    }
                }
                EditorRow(loc("commands.description")) {
                    TextField(loc("commands.description"), text: $description, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...4)
                }
                EditorRow(loc("tags.title")) { TagPicker(selectedIDs: $tagIDs) }
            }

            EditorButtons(disabled: name.isEmpty || commandText.isEmpty, onCancel: { dismiss() }, onSave: save)
        }
        .padding(22)
    }

    private func save() {
        let target = command ?? CommandShortcut(name: name, command: commandText, projectID: scope.currentProjectID)
        target.name = name
        target.icon = icon.isEmpty ? "⚡️" : icon
        target.command = commandText
        target.workingDirectory = workingDirectory
        target.commandDescription = description
        target.tagIDs = tagIDs
        target.updatedAt = Date()
        if command == nil { modelContext.insert(target) }
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

struct EmojiField: View {
    @Binding var text: String

    var body: some View {
        TextField("🙂", text: $text)
            .textFieldStyle(.roundedBorder)
            .frame(width: 60)
            .onChange(of: text) { _, newValue in
                if newValue.count > 2 { text = String(newValue.prefix(2)) }
            }
    }
}
