import AppKit
import SwiftData
import SwiftUI

struct ConfigTab: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var loc: LocalizationManager
    @EnvironmentObject private var prefs: AppPreferences
    @EnvironmentObject private var scope: ScopeManager
    @EnvironmentObject private var terminalManager: TerminalWorkspaceManager
    @Query(sort: \ConfigFile.name) private var allFiles: [ConfigFile]

    private var files: [ConfigFile] { allFiles.filter { $0.projectID == scope.currentProjectID } }

    private var rcFiles: [(String, String)] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            (".zshrc", "\(home)/.zshrc"),
            (".zshenv", "\(home)/.zshenv"),
            (".bashrc", "\(home)/.bashrc"),
            (".bash_profile", "\(home)/.bash_profile"),
            (".profile", "\(home)/.profile"),
            (".gitconfig", "\(home)/.gitconfig"),
            ("ssh config", "\(home)/.ssh/config"),
            ("hosts", "/etc/hosts")
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                defaultsCard
                rcCard
                filesCard
            }
        }
    }

    private var defaultsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(loc("config.defaults"), systemImage: "slider.horizontal.3").font(.headline)
            field(loc("config.keyDir"), text: $prefs.sshKeyDirectory, pick: true)
            field(loc("config.user"), text: $prefs.defaultUser)
            HStack {
                Text(loc("config.port")).font(.callout.weight(.medium)).frame(width: 130, alignment: .leading)
                TextField("22", value: $prefs.defaultPort, format: .number).textFieldStyle(.roundedBorder).frame(width: 90)
                Spacer()
            }
            field(loc("config.editor"), text: $prefs.defaultEditor)
            field(loc("config.workdir"), text: $prefs.defaultWorkingDir, pick: true)
        }
        .padding(14)
        .glass()
    }

    private func field(_ title: String, text: Binding<String>, pick: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.callout.weight(.medium)).frame(width: 130, alignment: .leading)
            TextField(title, text: text).textFieldStyle(.roundedBorder)
            if pick {
                Button { chooseDir(text) } label: { Image(systemName: "folder") }
            }
        }
    }

    private var rcCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(loc("config.rc"), systemImage: "doc.text").font(.headline)
            ForEach(rcFiles, id: \.1) { entry in
                fileRow(name: entry.0, path: entry.1)
            }
        }
        .padding(14)
        .glass()
    }

    private var filesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(loc("config.env"), systemImage: "doc.badge.gearshape").font(.headline)
                Spacer()
                Button { addFile() } label: { Image(systemName: "plus") }.help(loc("config.add"))
            }
            if files.isEmpty { EmptyHint() }
            ForEach(files) { file in
                fileRow(name: file.name, path: file.path, onDelete: { modelContext.delete(file) })
            }
        }
        .padding(14)
        .glass()
    }

    private func fileRow(name: String, path: String, onDelete: (() -> Void)? = nil) -> some View {
        let exists = FileManager.default.fileExists(atPath: path)
        return HStack(spacing: 8) {
            Image(systemName: exists ? "doc.text.fill" : "doc.badge.plus").foregroundStyle(exists ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.subheadline.weight(.medium)).lineLimit(1)
                Text(path).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Button { terminalManager.openLocalFileEditor(path: path) } label: { Image(systemName: "square.and.pencil") }
                .buttonStyle(.bordered).controlSize(.small)
            Button {
                terminalManager.runCommand("\(editorCommand) \(ShellSafety.singleQuoted(path))", workingDirectory: nil, in: terminalManager.focusedPanelIndex)
            } label: { Image(systemName: "terminal") }
                .buttonStyle(.bordered).controlSize(.small).help(loc("config.openTerminal"))
            if let onDelete {
                Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }.buttonStyle(.plain).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 3)
    }

    private var editorCommand: String {
        prefs.defaultEditor.isEmpty ? "${EDITOR:-nano}" : prefs.defaultEditor
    }

    private func addFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.showsHiddenFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            modelContext.insert(ConfigFile(name: url.lastPathComponent, path: url.path, projectID: scope.currentProjectID))
        }
    }

    private func chooseDir(_ binding: Binding<String>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.showsHiddenFiles = true
        if panel.runModal() == .OK, let url = panel.url { binding.wrappedValue = url.path }
    }
}
