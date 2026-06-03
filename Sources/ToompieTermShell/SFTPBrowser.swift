import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class RemoteNode: ObservableObject, Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isDir: Bool
    let depth: Int
    let shortcut: SSHShortcut
    weak var parent: RemoteNode?

    @Published var children: [RemoteNode]? = nil
    @Published var expanded = false
    @Published var loading = false
    @Published var error = ""

    init(name: String, path: String, isDir: Bool, depth: Int, shortcut: SSHShortcut, parent: RemoteNode? = nil) {
        self.name = name
        self.path = path
        self.isDir = isDir
        self.depth = depth
        self.shortcut = shortcut
        self.parent = parent
    }

    func toggle() {
        expanded.toggle()
        if expanded, children == nil { load() }
    }

    func reload() {
        children = nil
        load(force: true)
    }

    func load(force: Bool = false) {
        loading = true
        error = ""
        RemoteFileService.list(shortcut: shortcut, path: path, force: force) { [weak self] result in
            guard let self else { return }
            self.loading = false
            switch result {
            case .success(let entries):
                self.children = entries.map {
                    RemoteNode(name: $0.name, path: $0.path, isDir: $0.isDir, depth: self.depth + 1, shortcut: self.shortcut, parent: self)
                }
            case .failure(let err):
                self.error = err.localizedDescription
                self.children = []
            }
        }
    }

    func delete() {
        RemoteFileService.exec(shortcut: shortcut, remoteCommand: "rm -rf -- " + ShellSafety.singleQuoted(path)) { [weak self] _ in
            self?.parent?.reload()
        }
    }

    func rename(to newName: String) {
        let dir = (path as NSString).deletingLastPathComponent
        let dst = dir.isEmpty ? newName : dir + "/" + newName
        RemoteFileService.exec(shortcut: shortcut, remoteCommand: "mv -- " + ShellSafety.singleQuoted(path) + " " + ShellSafety.singleQuoted(dst)) { [weak self] _ in
            self?.parent?.reload()
        }
    }

    func createChild(name: String, isDir: Bool) {
        let childPath = path + "/" + name
        let cmd = isDir ? "mkdir -p -- " + ShellSafety.singleQuoted(childPath) : "touch -- " + ShellSafety.singleQuoted(childPath)
        RemoteFileService.exec(shortcut: shortcut, remoteCommand: cmd) { [weak self] _ in
            self?.expanded = true
            self?.reload()
        }
    }

    func download(to localPath: String) {
        RemoteFileService.download(shortcut: shortcut, remotePath: path, localPath: localPath) { _ in }
    }

    func upload(localPath: String) {
        RemoteFileService.uploadFile(shortcut: shortcut, localPath: localPath, remotePath: path) { [weak self] result in
            if case .success = result {
                ToastCenter.shared.key("toast.uploaded", icon: "arrow.up.doc.fill")
            }
            self?.reload()
        }
    }
}

struct SFTPBrowserView: View {
    @EnvironmentObject private var loc: LocalizationManager
    @EnvironmentObject private var terminalManager: TerminalWorkspaceManager
    @Environment(\.dismiss) private var dismiss
    let shortcut: SSHShortcut

    @State private var rootPath: String
    @State private var refresh = 0

    init(shortcut: SSHShortcut) {
        self.shortcut = shortcut
        _rootPath = State(initialValue: shortcut.startupDirectory.isEmpty ? "." : shortcut.startupDirectory)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(shortcut.icon).font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(shortcut.username)@\(shortcut.host)").font(.subheadline.weight(.semibold))
                    Text(loc("ssh.files")).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button { RemoteFileService.clearCache(for: shortcut); refresh += 1 } label: { Image(systemName: "arrow.clockwise") }
                Button(loc("common.cancel")) { dismiss() }
            }

            HStack(spacing: 6) {
                Image(systemName: "folder").foregroundStyle(.secondary)
                TextField("/path or .", text: $rootPath, onCommit: { refresh += 1 }).textFieldStyle(.plain).font(.callout.monospaced())
                Button { refresh += 1 } label: { Image(systemName: "arrow.right.circle.fill") }.buttonStyle(.plain)
            }
            .padding(.horizontal, 8).frame(height: 30)
            .background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 8))

            RemoteTree(shortcut: shortcut, path: rootPath, onOpenFile: openFile)
                .id("\(rootPath)#\(refresh)")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.black.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(18)
        .frame(width: 580, height: 600)
    }

    private func openFile(_ node: RemoteNode) {
        terminalManager.openRemoteFileEditor(shortcut: shortcut, remotePath: node.path)
        dismiss()
    }
}

struct RemoteTree: View {
    @EnvironmentObject private var loc: LocalizationManager
    @StateObject private var root: RemoteNode
    let onOpenFile: (RemoteNode) -> Void
    @State private var newFolder = false
    @State private var newName = ""

    init(shortcut: SSHShortcut, path: String, onOpenFile: @escaping (RemoteNode) -> Void) {
        _root = StateObject(wrappedValue: RemoteNode(name: path, path: path, isDir: true, depth: 0, shortcut: shortcut))
        self.onOpenFile = onOpenFile
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { newName = ""; newFolder = true } label: { Label(loc("ftp.newFolder"), systemImage: "folder.badge.plus") }
                    .controlSize(.small)
                Button { uploadHere() } label: { Label(loc("ftp.upload"), systemImage: "arrow.up.doc") }
                    .controlSize(.small)
                Spacer()
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            Divider().opacity(0.3)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    nodeRows(root, isRoot: true)
                }
                .padding(.vertical, 4)
            }
        }
        .onAppear { if root.children == nil { root.load() } }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url { DispatchQueue.main.async { root.upload(localPath: url.path) } }
                }
            }
            return true
        }
        .alert(loc("ftp.newFolder"), isPresented: $newFolder) {
            TextField(loc("common.name"), text: $newName)
            Button(loc("config.create")) { if !newName.isEmpty { root.createChild(name: newName, isDir: true) } }
            Button(loc("common.cancel"), role: .cancel) {}
        }
    }

    private func uploadHere() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            root.upload(localPath: url.path)
        }
    }

    private func nodeRows(_ node: RemoteNode, isRoot: Bool = false) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 0) {
                if !isRoot {
                    RemoteRow(node: node, onOpenFile: onOpenFile)
                }
                if node.expanded || isRoot {
                    if node.loading {
                        HStack(spacing: 6) { ProgressView().controlSize(.small); Text(loc("ftp.fetching")).font(.caption2).foregroundStyle(.secondary) }
                            .padding(.leading, CGFloat(node.depth + 1) * 16 + 8).padding(.vertical, 3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !node.error.isEmpty {
                        Text(node.error).font(.caption2).foregroundStyle(.orange)
                            .padding(.leading, CGFloat(node.depth + 1) * 16 + 8).padding(.vertical, 3).lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(node.children ?? []) { child in
                        nodeRows(child)
                    }
                }
            }
        )
    }
}

struct RemoteRow: View {
    @EnvironmentObject private var loc: LocalizationManager
    @ObservedObject var node: RemoteNode
    let onOpenFile: (RemoteNode) -> Void

    @State private var renaming = false
    @State private var renameText = ""
    @State private var newChild = false
    @State private var newChildIsDir = true
    @State private var newName = ""
    @State private var confirmDelete = false

    var body: some View {
        Button {
            if node.isDir { node.toggle() } else { onOpenFile(node) }
        } label: {
            HStack(spacing: 6) {
                if node.isDir {
                    Image(systemName: node.expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).frame(width: 12)
                } else {
                    Color.clear.frame(width: 12, height: 1)
                }
                Image(systemName: node.isDir ? (node.expanded ? "folder.fill" : "folder") : fileIcon)
                    .foregroundStyle(node.isDir ? Color.accentColor : Color.secondary)
                    .frame(width: 16)
                Text(node.name).font(.callout).lineLimit(1)
                Spacer()
                if !node.isDir { Image(systemName: "square.and.pencil").font(.caption2).foregroundStyle(.tertiary) }
            }
            .padding(.leading, CGFloat(node.depth) * 16 + 6)
            .padding(.vertical, 4)
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if node.isDir {
                Button(loc("ftp.newFolder")) { newName = ""; newChildIsDir = true; newChild = true }
                Button(loc("ftp.newFile")) { newName = ""; newChildIsDir = false; newChild = true }
                Divider()
            } else {
                Button(loc("ftp.open")) { onOpenFile(node) }
                Button(loc("ftp.download")) { downloadFile() }
                Divider()
            }
            Button(loc("ftp.rename")) { renameText = node.name; renaming = true }
            Button(loc("ftp.delete"), role: .destructive) { confirmDelete = true }
        }
        .alert(loc("ftp.rename"), isPresented: $renaming) {
            TextField(loc("common.name"), text: $renameText)
            Button(loc("common.save")) { if !renameText.isEmpty { node.rename(to: renameText) } }
            Button(loc("common.cancel"), role: .cancel) {}
        }
        .alert(newChildIsDir ? loc("ftp.newFolder") : loc("ftp.newFile"), isPresented: $newChild) {
            TextField(loc("common.name"), text: $newName)
            Button(loc("config.create")) { if !newName.isEmpty { node.createChild(name: newName, isDir: newChildIsDir) } }
            Button(loc("common.cancel"), role: .cancel) {}
        }
        .alert(loc("ftp.deleteConfirm"), isPresented: $confirmDelete) {
            Button(loc("ftp.delete"), role: .destructive) { node.delete() }
            Button(loc("common.cancel"), role: .cancel) {}
        }
    }

    private func downloadFile() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = node.name
        if panel.runModal() == .OK, let url = panel.url {
            node.download(to: url.path)
        }
    }

    private var fileIcon: String {
        let ext = (node.name as NSString).pathExtension.lowercased()
        switch ext {
        case "txt", "md", "log", "conf", "cfg", "ini", "yml", "yaml", "json", "env": return "doc.text"
        case "sh", "zsh", "bash", "py", "js", "ts", "rb", "go", "rs", "c", "cpp", "swift": return "chevron.left.forwardslash.chevron.right"
        case "png", "jpg", "jpeg", "gif", "svg": return "photo"
        case "zip", "tar", "gz", "tgz": return "archivebox"
        default: return "doc"
        }
    }
}
