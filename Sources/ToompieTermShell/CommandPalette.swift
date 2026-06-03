import SwiftData
import SwiftUI

@MainActor
final class PaletteController: ObservableObject {
    static let shared = PaletteController()
    @Published var open = false
    private init() {}
}

struct PaletteItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    var inputPrompt: String? = nil
    let run: (String) -> Void
}

struct CommandPalette: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var loc: LocalizationManager
    @EnvironmentObject private var terminalManager: TerminalWorkspaceManager
    @EnvironmentObject private var scope: ScopeManager
    @EnvironmentObject private var prefs: AppPreferences
    @Query(sort: \SSHShortcut.name) private var ssh: [SSHShortcut]
    @Query(sort: \PinnedPath.name) private var locations: [PinnedPath]
    @Query(sort: \CommandShortcut.name) private var commands: [CommandShortcut]
    @Query(sort: \Project.name) private var projects: [Project]

    @State private var query = ""
    @State private var selection = 0
    @State private var pending: PaletteItem?
    @State private var inputText = ""
    @FocusState private var searchFocused: Bool
    @FocusState private var inputFocused: Bool

    private func runInFocused(_ command: String) {
        terminalManager.runCommand(command, workingDirectory: nil, in: terminalManager.focusedPanelIndex)
    }

    private var gitItems: [PaletteItem] {
        let git = Color.orange
        func item(_ icon: String, _ title: String, _ command: String) -> PaletteItem {
            PaletteItem(icon: icon, title: title, subtitle: "Git", tint: git) { _ in runInFocused(command) }
        }
        return [
            PaletteItem(icon: "checkmark.seal.fill", title: "Git: Commit (add . + message)", subtitle: "Git", tint: git, inputPrompt: loc("palette.commitMessage")) { msg in
                runInFocused("git add . && git commit -m \(ShellSafety.singleQuoted(msg))")
            },
            item("arrow.up.circle.fill", "Git: Push", "git push"),
            item("arrow.up.to.line", "Git: Push origin main", "git push origin main"),
            item("arrow.up.forward", "Git: Push current branch", "git push origin HEAD"),
            item("arrow.down.circle.fill", "Git: Pull", "git pull"),
            item("arrow.triangle.2.circlepath", "Git: Pull --rebase", "git pull --rebase"),
            item("arrow.triangle.branch", "Git: Fetch all", "git fetch --all --prune"),
            item("doc.text.magnifyingglass", "Git: Status", "git status"),
            item("list.bullet.rectangle", "Git: Log (20)", "git log --oneline --graph -20"),
            item("text.alignleft", "Git: Diff", "git diff"),
            PaletteItem(icon: "arrow.branch", title: "Git: New branch", subtitle: "Git", tint: git, inputPrompt: loc("palette.branchName")) { name in
                runInFocused("git checkout -b \(ShellSafety.singleQuoted(name))")
            },
            PaletteItem(icon: "arrow.left.arrow.right", title: "Git: Checkout", subtitle: "Git", tint: git, inputPrompt: loc("palette.branchName")) { name in
                runInFocused("git checkout \(ShellSafety.singleQuoted(name))")
            },
            item("list.bullet", "Git: Branches", "git branch -a"),
            item("tray.and.arrow.down", "Git: Stash", "git stash"),
            item("tray.and.arrow.up", "Git: Stash pop", "git stash pop"),
            item("pencil.circle", "Git: Amend last commit", "git commit --amend"),
            PaletteItem(icon: "arrow.uturn.backward", title: "Git: Discard all changes", subtitle: "Git", tint: .red) { _ in
                runInFocused("git checkout -- . && git clean -fd")
            }
        ]
    }

    private var items: [PaletteItem] {
        var result: [PaletteItem] = []
        result.append(PaletteItem(icon: "plus.rectangle", title: loc("common.newTab"), subtitle: "", tint: .accentColor) { _ in
            terminalManager.createTab(in: terminalManager.focusedPanelIndex)
        })
        result.append(contentsOf: gitItems)
        result.append(PaletteItem(icon: "globe", title: loc("scope.global"), subtitle: loc("projects.scope"), tint: .gray) { _ in
            scope.currentProjectID = nil
        })
        for project in projects {
            result.append(PaletteItem(icon: "folder", title: "\(project.icon) \(project.name)", subtitle: loc("projects.scope"), tint: Color(hex: project.colorHex)) { _ in
                scope.currentProjectID = project.id
            })
        }
        for s in ssh where s.projectID == scope.currentProjectID {
            result.append(PaletteItem(icon: "network", title: "\(s.icon) \(s.name)", subtitle: "\(s.username)@\(s.host)", tint: .blue) { _ in
                var cmd = SSHCommandBuilder.command(for: s) + SSHCommandBuilder.startupSuffix(for: s)
                if s.authType == .password { cmd += "\n" }
                runInFocused(cmd)
            })
        }
        for l in locations where l.projectID == scope.currentProjectID {
            result.append(PaletteItem(icon: "mappin.and.ellipse", title: "\(l.icon) \(l.name)", subtitle: l.absolutePath, tint: .orange) { _ in
                terminalManager.cd(to: l.absolutePath, in: terminalManager.focusedPanelIndex)
            })
        }
        for c in commands where c.projectID == scope.currentProjectID {
            result.append(PaletteItem(icon: "terminal", title: "\(c.icon) \(c.name)", subtitle: c.command, tint: .green) { _ in
                let dir = c.workingDirectory.isEmpty ? nil : c.workingDirectory
                terminalManager.runCommand(c.command, workingDirectory: dir, in: terminalManager.focusedPanelIndex)
            })
        }
        return result
    }

    private var filtered: [PaletteItem] {
        guard !query.isEmpty else { return items }
        let q = query.lowercased()
        return items.filter { $0.title.lowercased().contains(q) || $0.subtitle.lowercased().contains(q) }
    }

    var body: some View {
        Group {
            if let pending {
                inputView(pending)
            } else {
                searchView
            }
        }
        .frame(width: 600, height: 440)
        .background(.ultraThinMaterial)
    }

    private var searchView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(loc("search.placeholder"), text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($searchFocused)
                    .onSubmit(runSelected)
                    .onChange(of: query) { _, _ in selection = 0 }
                    .onKeyPress(.downArrow) { move(1); return .handled }
                    .onKeyPress(.upArrow) { move(-1); return .handled }
            }
            .padding(14)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                            row(item, active: index == selection)
                                .id(index)
                                .onTapGesture { selection = index; runSelected() }
                        }
                    }
                    .padding(8)
                }
                .onChange(of: selection) { _, new in
                    withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(new, anchor: .center) }
                }
            }
        }
        .onAppear { searchFocused = true; selection = 0 }
        .onExitCommand { dismiss() }
    }

    private func inputView(_ item: PaletteItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: item.icon).foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(LinearGradient(colors: [item.tint, item.tint.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(item.title).font(.headline)
                Spacer()
            }
            TextField(item.inputPrompt ?? "", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .focused($inputFocused)
                .onSubmit { confirmInput(item) }
            HStack {
                Spacer()
                Button(loc("common.cancel")) { pending = nil; inputText = "" }
                Button(loc("common.run")) { confirmInput(item) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(inputText.isEmpty)
            }
        }
        .padding(22)
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear { inputFocused = true }
        .onExitCommand { pending = nil; inputText = "" }
    }

    private func row(_ item: PaletteItem, active: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(LinearGradient(colors: [item.tint, item.tint.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.callout.weight(.medium)).lineLimit(1)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if item.inputPrompt != nil { Image(systemName: "character.cursor.ibeam").font(.caption2).foregroundStyle(.secondary) }
            if active { Image(systemName: "return").font(.caption2).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(active ? Color.accentColor.opacity(0.22) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
    }

    private func move(_ delta: Int) {
        let count = filtered.count
        guard count > 0 else { return }
        selection = (selection + delta + count) % count
    }

    private func runSelected() {
        let list = filtered
        guard list.indices.contains(selection) else { return }
        let item = list[selection]
        if item.inputPrompt != nil {
            inputText = ""
            pending = item
        } else {
            item.run("")
            dismiss()
        }
    }

    private func confirmInput(_ item: PaletteItem) {
        guard !inputText.isEmpty else { return }
        item.run(inputText)
        pending = nil
        inputText = ""
        dismiss()
    }
}
