import AppKit
import SwiftData
import SwiftUI

struct PathsSidebarTab: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var terminalManager: TerminalWorkspaceManager
    @Query(sort: \PinnedPath.name) private var paths: [PinnedPath]
    @State private var editingPath: PinnedPath?

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Paths", systemImage: "folder")
                    .font(.headline)
                Spacer()
                Button {
                    addPath()
                } label: {
                    Image(systemName: "plus")
                }
                .help("Pin directory")
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    if paths.isEmpty {
                        Text("No pinned paths")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ForEach(paths) { path in
                        SidebarCard {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(path.name)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Text(path.absolutePath)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button {
                                    editingPath = path
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.plain)
                                .help("Edit")

                                Button {
                                    modelContext.delete(path)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.red)
                                .help("Delete")
                            }

                            HStack {
                                Button {
                                    Clipboard.copy(path.absolutePath)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button {
                                    terminalManager.cd(to: path.absolutePath, in: terminalManager.focusedPanelIndex)
                                } label: {
                                    Label("CD", systemImage: "arrow.right.to.line")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            TargetSegments { index in
                                terminalManager.cd(to: path.absolutePath, in: index)
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $editingPath) { path in
            PinnedPathEditor(path: path)
                .frame(width: 600)
        }
    }

    private func addPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let pinned = PinnedPath(name: url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent, absolutePath: url.path)
            modelContext.insert(pinned)
        }
    }
}

struct PinnedPathEditor: View {
    @Environment(\.dismiss) private var dismiss
    let path: PinnedPath
    @State private var name: String
    @State private var absolutePath: String

    init(path: PinnedPath) {
        self.path = path
        _name = State(initialValue: path.name)
        _absolutePath = State(initialValue: path.absolutePath)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Path")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 12) {
                EditorRow("Name") {
                    EditorTextField(title: "Name", text: $name)
                }

                EditorRow("Absolute Path") {
                    HStack(spacing: 8) {
                        EditorTextField(title: "Absolute Path", text: $absolutePath)
                        Button {
                            selectDirectory()
                        } label: {
                            Image(systemName: "folder")
                        }
                        .help("Choose directory")
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    path.name = name
                    path.absolutePath = absolutePath
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
            if name.isEmpty {
                name = url.lastPathComponent
            }
        }
    }
}
