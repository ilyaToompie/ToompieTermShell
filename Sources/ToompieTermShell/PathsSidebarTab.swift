import AppKit
import SwiftData
import SwiftUI

struct PathsSidebarTab: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var terminalManager: TerminalWorkspaceManager
    @EnvironmentObject private var loc: LocalizationManager
    @EnvironmentObject private var scope: ScopeManager
    @EnvironmentObject private var prefs: AppPreferences
    @Query(sort: \PinnedPath.name) private var allPaths: [PinnedPath]
    @Query(sort: \CommandShortcut.name) private var allCommands: [CommandShortcut]
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var search = ""
    @State private var filterTag: UUID?
    @State private var editingPath: PinnedPath?

    private func matchingCommands(for path: PinnedPath) -> [CommandShortcut] {
        let pathTags = Set(path.tagIDs)
        guard !pathTags.isEmpty else { return [] }
        return allCommands.filter { command in
            command.projectID == scope.currentProjectID && !Set(command.tagIDs).isDisjoint(with: pathTags)
        }
    }

    private func runCommand(_ command: CommandShortcut, at path: PinnedPath, in panelIndex: Int) {
        guard !prefs.confirmDangerous || CommandConfirmation.shouldRun(command.command) else { return }
        terminalManager.runCommand(command.command, workingDirectory: path.absolutePath, in: panelIndex)
    }

    private var paths: [PinnedPath] {
        allPaths.filter { item in
            guard item.projectID == scope.currentProjectID else { return false }
            if let filterTag, !item.hasTag(filterTag) { return false }
            if !search.isEmpty {
                let q = search.lowercased()
                return item.name.lowercased().contains(q) || item.absolutePath.lowercased().contains(q)
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                SectionTitle(title: loc("tab.locations"), systemImage: "mappin.and.ellipse")
                ShimmerAddButton { addPath() }
            }
            SearchField(text: $search, placeholder: loc("search.placeholder"))
            TagFilterBar(tags: tags, selected: $filterTag)

            ScrollView {
                LazyVStack(spacing: 8) {
                    if paths.isEmpty { EmptyHint() }
                    ForEach(paths) { path in
                        SidebarCard {
                            HStack(alignment: .firstTextBaseline) {
                                Text(path.icon).font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(path.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                                    Text(path.absolutePath).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                                }
                                Spacer()
                                ScopeMoveMenu(
                                    currentProjectID: scope.currentProjectID,
                                    onCopy: { target in
                                        let dup = PinnedPath(name: path.name, absolutePath: path.absolutePath, icon: path.icon, tagIDsRaw: path.tagIDsRaw, projectID: target)
                                        modelContext.insert(dup)
                                    },
                                    onMove: { path.projectID = $0; path.updatedAt = Date() }
                                )
                                RowButtons(onEdit: { editingPath = path }, onDelete: { modelContext.delete(path) })
                            }
                            TagRowChips(ids: path.tagIDs, tags: tags)
                            HStack {
                                Button { Clipboard.copy(path.absolutePath) } label: { Label(loc("common.copy"), systemImage: "doc.on.doc") }
                                    .buttonStyle(.bordered).controlSize(.small)
                                TerminalTargetMenu(title: loc("paths.cd"), systemImage: "arrow.right.to.line") {
                                    terminalManager.cd(to: path.absolutePath, in: $0)
                                }
                                let matches = matchingCommands(for: path)
                                if !matches.isEmpty {
                                    Menu {
                                        ForEach(matches) { command in
                                            Button("\(command.icon) \(command.name)") {
                                                runCommand(command, at: path, in: terminalManager.focusedPanelIndex)
                                            }
                                        }
                                    } label: {
                                        Label("\(matches.count)", systemImage: "wand.and.stars")
                                    }
                                    .menuStyle(.borderlessButton)
                                    .controlSize(.small)
                                    .fixedSize()
                                    .help(loc("tab.commands"))
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $editingPath) { PinnedPathEditor(path: $0).frame(width: 600) }
    }

    private func addPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let pinned = PinnedPath(name: url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent, absolutePath: url.path, projectID: scope.currentProjectID)
            modelContext.insert(pinned)
            editingPath = pinned
        }
    }
}

struct PinnedPathEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var loc: LocalizationManager
    let path: PinnedPath
    @State private var name: String
    @State private var icon: String
    @State private var absolutePath: String
    @State private var tagIDs: [UUID]

    init(path: PinnedPath) {
        self.path = path
        _name = State(initialValue: path.name)
        _icon = State(initialValue: path.icon)
        _absolutePath = State(initialValue: path.absolutePath)
        _tagIDs = State(initialValue: path.tagIDs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(loc("common.edit")).font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 12) {
                EditorRow(loc("ssh.icon")) { EmojiField(text: $icon) }
                EditorRow(loc("common.name")) { EditorTextField(title: loc("common.name"), text: $name) }
                EditorRow(loc("paths.absolute")) {
                    HStack(spacing: 8) {
                        EditorTextField(title: loc("paths.absolute"), text: $absolutePath)
                        Button { selectDirectory() } label: { Image(systemName: "folder") }
                    }
                }
                EditorRow(loc("tags.title")) { TagPicker(selectedIDs: $tagIDs) }
            }
            HStack {
                Spacer()
                Button(loc("common.cancel")) { dismiss() }
                Button(loc("common.save")) {
                    path.name = name
                    path.icon = icon.isEmpty ? "📂" : icon
                    path.absolutePath = absolutePath
                    path.tagIDs = tagIDs
                    path.updatedAt = Date()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || absolutePath.isEmpty)
            }
        }
        .padding(22)
    }

    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            absolutePath = url.path
            if name.isEmpty { name = url.lastPathComponent }
        }
    }
}
