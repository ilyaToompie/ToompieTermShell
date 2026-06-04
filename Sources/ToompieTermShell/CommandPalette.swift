import AppKit
import SwiftData
import SwiftUI

/// Progressive disclosure levels for the palette. Higher tiers reveal more (and more powerful)
/// built-in commands on top of everything the lower tiers show.
enum PaletteLevel: Int, CaseIterable, Identifiable {
    case basic
    case advanced
    case superA

    var id: Int { rawValue }
    var labelKey: String {
        switch self {
        case .basic: return "palette.basic"
        case .advanced: return "palette.advanced"
        case .superA: return "palette.super"
        }
    }

    func includes(_ tier: PaletteLevel) -> Bool { tier.rawValue <= rawValue }
}

/// Installs an app-local key-down monitor so arrow / return / escape / ⌘K work while a text field is focused.
/// Driven from `.onAppear`/`.onDisappear` instead of a zero-sized representable, which isn't reliably
/// realized inside a `.sheet`.
@MainActor
final class PaletteKeyMonitor: ObservableObject {
    private var monitor: Any?
    var onUp: () -> Void = {}
    var onDown: () -> Void = {}
    var onReturn: () -> Void = {}
    var onEscape: () -> Void = {}
    var onCycle: () -> Void = {}
    var isEnabled: () -> Bool = { true }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isEnabled() else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // ⌘K while the palette is open advances the highlighted command instead of opening again.
            if flags == .command, event.keyCode == 40 { self.onCycle(); return nil }
            switch event.keyCode {
            case 126: self.onUp(); return nil
            case 125: self.onDown(); return nil
            case 36, 76: self.onReturn(); return nil
            case 53: self.onEscape(); return nil
            default: return event
            }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

@MainActor
final class PaletteController: ObservableObject {
    static let shared = PaletteController()
    @Published var open = false
    @Published var level: PaletteLevel = .basic
    private init() {}

    func present(_ level: PaletteLevel = .basic) {
        self.level = level
        open = true
    }
}

struct PaletteItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    var inputPrompt: String? = nil
    var tier: PaletteLevel = .basic
    let run: (String) -> Void
}

struct CommandPalette: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var loc: LocalizationManager
    @EnvironmentObject private var terminalManager: TerminalWorkspaceManager
    @EnvironmentObject private var scope: ScopeManager
    @EnvironmentObject private var prefs: AppPreferences
    @ObservedObject private var controller = PaletteController.shared
    @Query(sort: \SSHShortcut.name) private var ssh: [SSHShortcut]
    @Query(sort: \PinnedPath.name) private var locations: [PinnedPath]
    @Query(sort: \CommandShortcut.name) private var commands: [CommandShortcut]
    @Query(sort: \Project.name) private var projects: [Project]

    @StateObject private var keys = PaletteKeyMonitor()
    @State private var query = ""
    @State private var selection = 0
    @State private var pending: PaletteItem?
    @State private var inputText = ""
    @FocusState private var searchFocused: Bool
    @FocusState private var inputFocused: Bool

    private func runInFocused(_ command: String) {
        terminalManager.runCommand(command, workingDirectory: nil, in: terminalManager.focusedPanelIndex)
    }

    // MARK: - Built-in commands (tiered)

    private func cmd(_ tier: PaletteLevel, _ icon: String, _ title: String, _ sub: String, _ tint: Color, _ command: String) -> PaletteItem {
        PaletteItem(icon: icon, title: title, subtitle: sub, tint: tint, tier: tier) { _ in runInFocused(command) }
    }

    private func ask(_ tier: PaletteLevel, _ icon: String, _ title: String, _ sub: String, _ tint: Color, _ prompt: String, _ build: @escaping (String) -> String) -> PaletteItem {
        PaletteItem(icon: icon, title: title, subtitle: sub, tint: tint, inputPrompt: prompt, tier: tier) { v in runInFocused(build(v)) }
    }

    private var builtinItems: [PaletteItem] {
        let git = Color.orange, term = Color.accentColor, sys = Color.teal, dev = Color.green, net = Color.blue, danger = Color.red
        let commitMsg = loc("palette.commitMessage"), branch = loc("palette.branchName")
        var all: [PaletteItem] = []

        // — Basic: everyday terminal + git —
        all += [
            cmd(.basic, "clear", "Clear screen", "Terminal", term, "clear"),
            cmd(.basic, "list.bullet.indent", "List files", "Terminal", term, "ls -la"),
            cmd(.basic, "location.north.line", "Print working directory", "Terminal", term, "pwd"),
            cmd(.basic, "doc.text.magnifyingglass", "Git: Status", "Git", git, "git status"),
            cmd(.basic, "plus.square.on.square", "Git: Stage all", "Git", git, "git add ."),
            ask(.basic, "checkmark.seal.fill", "Git: Commit (add . + message)", "Git", git, commitMsg) {
                "git add . && git commit -m \(ShellSafety.singleQuoted($0))"
            },
            cmd(.basic, "arrow.up.circle.fill", "Git: Push", "Git", git, "git push"),
            cmd(.basic, "arrow.down.circle.fill", "Git: Pull", "Git", git, "git pull"),
            cmd(.basic, "text.alignleft", "Git: Diff", "Git", git, "git diff"),
            cmd(.basic, "list.bullet.rectangle", "Git: Log (20)", "Git", git, "git log --oneline --graph -20")
        ]

        // — Advanced: power git, system inspection, dev tooling, ssh —
        all += [
            cmd(.advanced, "arrow.up.to.line", "Git: Push current branch", "Git", git, "git push origin HEAD"),
            cmd(.advanced, "arrow.triangle.branch", "Git: Fetch all", "Git", git, "git fetch --all --prune"),
            cmd(.advanced, "arrow.triangle.2.circlepath", "Git: Pull --rebase", "Git", git, "git pull --rebase"),
            ask(.advanced, "arrow.branch", "Git: New branch", "Git", git, branch) { "git checkout -b \(ShellSafety.singleQuoted($0))" },
            ask(.advanced, "arrow.left.arrow.right", "Git: Checkout", "Git", git, branch) { "git checkout \(ShellSafety.singleQuoted($0))" },
            cmd(.advanced, "list.bullet", "Git: Branches", "Git", git, "git branch -a"),
            cmd(.advanced, "tray.and.arrow.down", "Git: Stash", "Git", git, "git stash"),
            cmd(.advanced, "tray.and.arrow.up", "Git: Stash pop", "Git", git, "git stash pop"),
            cmd(.advanced, "pencil.circle", "Git: Amend last commit", "Git", git, "git commit --amend"),
            cmd(.advanced, "arrow.uturn.left", "Git: Unstage all", "Git", git, "git restore --staged ."),
        ]
        all += [
            cmd(.advanced, "internaldrive", "Disk usage", "System", sys, "df -h"),
            cmd(.advanced, "folder.badge.questionmark", "Folder sizes here", "System", sys, "du -sh * | sort -h"),
            cmd(.advanced, "gauge.with.dots.needle.67percent", "Top processes", "System", sys, "top -l 1 -o cpu -n 15"),
            cmd(.advanced, "list.bullet.clipboard", "Process list", "System", sys, "ps aux | head -30"),
            cmd(.advanced, "network", "Open ports", "System", sys, "lsof -nP -iTCP -sTCP:LISTEN"),
            cmd(.advanced, "memorychip", "Memory stats", "System", sys, "vm_stat"),
            cmd(.advanced, "clock.arrow.circlepath", "Uptime", "System", sys, "uptime"),
            ask(.advanced, "wifi", "Ping host", "Network", net, loc("palette.host")) { "ping -c 5 \(ShellSafety.singleQuoted($0))" },
            cmd(.advanced, "globe", "Public IP", "Network", net, "curl -s ifconfig.me; echo")
        ]
        all += [
            cmd(.advanced, "shippingbox", "npm install", "Dev", dev, "npm install"),
            cmd(.advanced, "play.circle", "npm run dev", "Dev", dev, "npm run dev"),
            cmd(.advanced, "play.fill", "npm start", "Dev", dev, "npm start"),
            ask(.advanced, "terminal", "npm run…", "Dev", dev, loc("palette.script")) { "npm run \(ShellSafety.singleQuoted($0))" },
            cmd(.advanced, "shippingbox.fill", "pnpm install", "Dev", dev, "pnpm install"),
            ask(.advanced, "cube.box", "pip install…", "Dev", dev, loc("palette.package")) { "pip install \(ShellSafety.singleQuoted($0))" },
            cmd(.advanced, "cube", "Python venv", "Dev", dev, "python3 -m venv .venv && source .venv/bin/activate"),
            cmd(.advanced, "hammer", "make", "Dev", dev, "make"),
            cmd(.advanced, "shippingbox.and.arrow.backward", "Docker ps", "Docker", dev, "docker ps"),
            cmd(.advanced, "arrow.up.square", "Docker compose up", "Docker", dev, "docker compose up -d"),
            cmd(.advanced, "arrow.down.square", "Docker compose down", "Docker", dev, "docker compose down")
        ]
        all += [
            cmd(.advanced, "key", "Generate SSH key", "SSH", net, "ssh-keygen -t ed25519 -C \(ShellSafety.singleQuoted(prefs.defaultUser))"),
            ask(.advanced, "key.fill", "ssh-copy-id…", "SSH", net, loc("palette.host")) { "ssh-copy-id \(ShellSafety.singleQuoted($0))" },
            cmd(.advanced, "doc.badge.gearshape", "Edit SSH config", "SSH", net, "\(prefs.defaultEditor) ~/.ssh/config"),
            cmd(.advanced, "list.bullet.rectangle.portrait", "List SSH keys", "SSH", net, "ls -la ~/.ssh")
        ]

        // — Super: destructive / system power / heavy tooling —
        all += [
            cmd(.superA, "arrow.uturn.backward", "Git: Discard all changes", "Git · danger", danger, "git checkout -- . && git clean -fd"),
            cmd(.superA, "exclamationmark.arrow.circlepath", "Git: Hard reset to HEAD", "Git · danger", danger, "git reset --hard"),
            cmd(.superA, "bolt.trianglebadge.exclamationmark", "Git: Force push (lease)", "Git · danger", danger, "git push --force-with-lease"),
            cmd(.superA, "trash.slash", "Git: Clean untracked", "Git · danger", danger, "git clean -fd"),
            cmd(.superA, "sparkles", "Git: Garbage collect", "Git", git, "git gc --prune=now --aggressive"),
            cmd(.superA, "clock.badge.questionmark", "Git: Reflog", "Git", git, "git reflog -30")
        ]
        all += [
            ask(.superA, "xmark.octagon", "Kill process on port…", "System · power", danger, loc("palette.port")) { "lsof -ti:\(ShellSafety.singleQuoted($0)) | xargs kill -9" },
            cmd(.superA, "arrow.down.app", "Brew update & upgrade", "System · power", sys, "brew update && brew upgrade"),
            cmd(.superA, "trash", "Brew cleanup", "System · power", sys, "brew cleanup -s"),
            cmd(.superA, "trash.fill", "Empty Trash", "System · power", danger, "rm -rf ~/.Trash/*"),
            cmd(.superA, "eye", "Toggle hidden files", "System · power", sys, "defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"),
            cmd(.superA, "arrow.clockwise.circle", "Restart Finder", "System · power", sys, "killall Finder"),
            cmd(.superA, "dock.rectangle", "Restart Dock", "System · power", sys, "killall Dock"),
            cmd(.superA, "memorychip.fill", "Purge memory (sudo)", "System · power", danger, "sudo purge"),
            cmd(.superA, "wifi.exclamationmark", "Flush DNS cache (sudo)", "System · power", danger, "sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder")
        ]
        all += [
            cmd(.superA, "shippingbox.circle", "Docker prune system", "Docker · power", danger, "docker system prune -af --volumes"),
            cmd(.superA, "stop.circle", "Docker stop all", "Docker · power", danger, "docker stop $(docker ps -q)"),
            cmd(.superA, "trash.circle", "Docker remove all images", "Docker · power", danger, "docker rmi -f $(docker images -q)"),
            cmd(.superA, "trash.square", "Reinstall node_modules", "Dev · power", danger, "rm -rf node_modules package-lock.json && npm install"),
            cmd(.superA, "magnifyingglass.circle", "Find large files (>50M)", "Dev", dev, "find . -type f -size +50M -exec ls -lh {} \\;"),
            cmd(.superA, "xmark.circle", "Kill all node", "Dev · power", danger, "killall node")
        ]

        return all.filter { controller.level.includes($0.tier) }
    }

    private var scopeItems: [PaletteItem] {
        var result: [PaletteItem] = [
            PaletteItem(icon: "globe", title: loc("scope.global"), subtitle: loc("projects.scope"), tint: .gray) { _ in
                scope.currentProjectID = nil
            }
        ]
        for project in projects {
            result.append(PaletteItem(icon: "folder", title: "\(project.icon) \(project.name)", subtitle: loc("projects.scope"), tint: Color(hex: project.colorHex)) { _ in
                scope.currentProjectID = project.id
            })
        }
        return result
    }

    /// Saved items are visible when they're global (no project) or belong to the active project,
    /// so global shortcuts work in any project while project-specific ones stay scoped.
    private func inScope(_ projectID: UUID?) -> Bool {
        projectID == nil || projectID == scope.currentProjectID
    }

    private var savedItems: [PaletteItem] {
        var result: [PaletteItem] = []
        for s in ssh where inScope(s.projectID) {
            result.append(PaletteItem(icon: "network", title: "\(s.icon) \(s.name)", subtitle: "\(s.username)@\(s.host)", tint: .blue) { _ in
                var cmd = SSHCommandBuilder.command(for: s) + SSHCommandBuilder.startupSuffix(for: s)
                if s.authType == .password { cmd += "\n" }
                runInFocused(cmd)
            })
        }
        for l in locations where inScope(l.projectID) {
            result.append(PaletteItem(icon: "mappin.and.ellipse", title: "\(l.icon) \(l.name)", subtitle: l.absolutePath, tint: .orange) { _ in
                terminalManager.cd(to: l.absolutePath, in: terminalManager.focusedPanelIndex)
            })
        }
        for c in commands where inScope(c.projectID) {
            result.append(PaletteItem(icon: "terminal", title: "\(c.icon) \(c.name)", subtitle: c.command, tint: .green) { _ in
                let dir = c.workingDirectory.isEmpty ? nil : c.workingDirectory
                terminalManager.runCommand(c.command, workingDirectory: dir, in: terminalManager.focusedPanelIndex)
            })
        }
        return result
    }

    private var items: [PaletteItem] {
        scopeItems + builtinItems + savedItems
    }

    // MARK: - Fuzzy filtering

    private func subsequenceScore(_ text: String, _ q: [Character]) -> Int? {
        let t = Array(text)
        var ti = 0, qi = 0, score = 0, prev = -2
        while ti < t.count && qi < q.count {
            if t[ti] == q[qi] {
                score += (prev == ti - 1) ? 6 : 1
                if ti == 0 { score += 6 }
                prev = ti
                qi += 1
            }
            ti += 1
        }
        return qi == q.count ? score : nil
    }

    private func matchScore(_ item: PaletteItem, _ q: String) -> Int? {
        let title = item.title.lowercased()
        let sub = item.subtitle.lowercased()
        if title == q { return 10_000 }
        if title.hasPrefix(q) { return 5_000 - title.count }
        if title.contains(q) { return 3_000 - title.count }
        let chars = Array(q)
        if let s = subsequenceScore(title, chars) { return 1_000 + s }
        if sub.contains(q) { return 500 - sub.count }
        if let s = subsequenceScore(sub, chars) { return 200 + s }
        return nil
    }

    private var filtered: [PaletteItem] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return items }
        return items
            .compactMap { item in matchScore(item, q).map { (item, $0) } }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let pending {
                inputView(pending)
            } else {
                searchView
            }
        }
        .frame(width: 600, height: 460)
        .background(.ultraThinMaterial)
        .onAppear {
            keys.isEnabled = { pending == nil }
            keys.onUp = { move(-1) }
            keys.onDown = { move(1) }
            keys.onCycle = { cycle(1) }
            keys.onReturn = { runSelected() }
            keys.onEscape = { dismiss() }
            keys.start()
        }
        .onDisappear { keys.stop() }
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
                Picker("", selection: $controller.level) {
                    ForEach(PaletteLevel.allCases) { lvl in
                        Text(loc(lvl.labelKey)).tag(lvl)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 230)
                .onChange(of: controller.level) { _, _ in selection = 0 }
            }
            .padding(14)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                            row(item, active: index == selection)
                                .id(index)
                                .contentShape(Rectangle())
                                .onTapGesture { selection = index; runSelected() }
                        }
                    }
                    .padding(8)
                }
                .onChange(of: selection) { _, new in
                    // Spotlight-style: scroll only enough to keep the selected row on screen.
                    proxy.scrollTo(new, anchor: nil)
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
        .onAppear {
            inputFocused = true
            // The field lives inside a sheet; a deferred focus makes the auto-focus reliable.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { inputFocused = true }
        }
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
        selection = min(max(selection + delta, 0), count - 1)
    }

    /// ⌘K wraps around the list rather than stopping at the ends.
    private func cycle(_ delta: Int) {
        let count = filtered.count
        guard count > 0 else { return }
        selection = ((selection + delta) % count + count) % count
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
