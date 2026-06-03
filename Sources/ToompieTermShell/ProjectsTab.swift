import AppKit
import SwiftData
import SwiftUI

struct ProjectsTab: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var loc: LocalizationManager
    @EnvironmentObject private var scope: ScopeManager
    @Query(sort: \Project.name) private var projects: [Project]
    @State private var showingAddProject = false
    @State private var editingProject: Project?

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                SectionTitle(title: loc("tab.projects"), systemImage: "square.stack.3d.up.fill")
                ShimmerAddButton { showingAddProject = true }
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    globalCard
                    ForEach(projects) { project in
                        projectCard(project)
                    }
                    NotesSection()
                        .padding(.top, 8)
                }
            }
        }
        .sheet(isPresented: $showingAddProject) { ProjectEditor(project: nil).frame(width: 460) }
        .sheet(item: $editingProject) { ProjectEditor(project: $0).frame(width: 460) }
    }

    private var globalCard: some View {
        Button { scope.currentProjectID = nil } label: {
            HStack(spacing: 10) {
                Text("🌐").font(.title3)
                Text(loc("scope.global")).font(.subheadline.weight(.semibold))
                Spacer()
                if scope.isGlobal { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor) }
            }
            .padding(10)
            .background(scope.isGlobal ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(scope.isGlobal ? Color.accentColor.opacity(0.6) : Color.white.opacity(0.1)))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverScale(1.01, lift: true)
    }

    private func projectCard(_ project: Project) -> some View {
        let active = scope.currentProjectID == project.id
        return Button { scope.currentProjectID = project.id } label: {
            HStack(spacing: 10) {
                Text(project.icon).font(.title3)
                Circle().fill(Color(hex: project.colorHex)).frame(width: 8, height: 8)
                Text(project.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer()
                if active { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: project.colorHex)) }
                Menu {
                    Button(loc("common.edit")) { editingProject = project }
                    Button(loc("common.delete"), role: .destructive) { deleteProject(project) }
                } label: { Image(systemName: "ellipsis") }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            }
            .padding(10)
            .background(active ? Color(hex: project.colorHex).opacity(0.16) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? Color(hex: project.colorHex).opacity(0.6) : Color.white.opacity(0.1)))
            .shadow(color: active ? Color(hex: project.colorHex).opacity(0.3) : .clear, radius: 7, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverScale(1.01, lift: true)
    }

    private func deleteProject(_ project: Project) {
        let pid = project.id
        try? deleteMatching(SSHShortcut.self, pid)
        try? deleteMatching(PinnedPath.self, pid)
        try? deleteMatching(CommandShortcut.self, pid)
        try? deleteMatching(ProjectNote.self, pid)
        try? deleteMatching(ConfigFile.self, pid)
        modelContext.delete(project)
        if scope.currentProjectID == pid { scope.currentProjectID = nil }
    }

    private func deleteMatching<T: PersistentModel>(_ type: T.Type, _ pid: UUID) throws {
        let all = try modelContext.fetch(FetchDescriptor<T>())
        for item in all {
            if let scoped = item as? any ProjectScoped, scoped.projectID == pid {
                modelContext.delete(item)
            }
        }
    }
}

protocol ProjectScoped {
    var projectID: UUID? { get }
}

extension SSHShortcut: ProjectScoped {}
extension PinnedPath: ProjectScoped {}
extension CommandShortcut: ProjectScoped {}
extension ProjectNote: ProjectScoped {}
extension ConfigFile: ProjectScoped {}

struct ProjectEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var loc: LocalizationManager
    @EnvironmentObject private var scope: ScopeManager
    let project: Project?

    @State private var name: String
    @State private var icon: String
    @State private var colorHex: String

    init(project: Project?) {
        self.project = project
        _name = State(initialValue: project?.name ?? "")
        _icon = State(initialValue: project?.icon ?? "📁")
        _colorHex = State(initialValue: project?.colorHex ?? tagPalette[1])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(project == nil ? loc("projects.add") : loc("projects.rename")).font(.title3.weight(.semibold))
            EditorRow(loc("ssh.icon")) { EmojiField(text: $icon) }
            EditorRow(loc("common.name")) { EditorTextField(title: loc("common.name"), text: $name) }
            HStack(spacing: 8) {
                ForEach(tagPalette, id: \.self) { hex in
                    Circle().fill(Color(hex: hex)).frame(width: 24, height: 24)
                        .overlay(Circle().stroke(Color.white, lineWidth: colorHex == hex ? 2 : 0))
                        .onTapGesture { colorHex = hex }
                }
            }
            EditorButtons(disabled: name.isEmpty, onCancel: { dismiss() }, onSave: save)
        }
        .padding(22)
    }

    private func save() {
        if let project {
            project.name = name
            project.icon = icon.isEmpty ? "📁" : icon
            project.colorHex = colorHex
        } else {
            let created = Project(name: name, colorHex: colorHex, icon: icon.isEmpty ? "📁" : icon)
            modelContext.insert(created)
            scope.currentProjectID = created.id
        }
        dismiss()
    }
}

struct NotesSection: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var loc: LocalizationManager
    @EnvironmentObject private var scope: ScopeManager
    @Query(sort: \ProjectNote.updatedAt, order: .reverse) private var allNotes: [ProjectNote]
    @State private var editing: ProjectNote?

    private var notes: [ProjectNote] { allNotes.filter { $0.projectID == scope.currentProjectID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(loc("projects.notes"), systemImage: "note.text").font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    let note = ProjectNote(title: loc("notes.title"), projectID: scope.currentProjectID)
                    modelContext.insert(note)
                    editing = note
                } label: { Image(systemName: "plus") }.help(loc("notes.add"))
            }
            if notes.isEmpty { EmptyHint() }
            ForEach(notes) { note in
                Button { editing = note } label: {
                    SidebarCard {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                                if !note.body.isEmpty {
                                    Text(note.body).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }
                            Spacer()
                            ScopeMoveMenu(
                                currentProjectID: scope.currentProjectID,
                                onCopy: { target in
                                    let dup = ProjectNote(title: note.title, body: note.body, tagIDsRaw: note.tagIDsRaw, projectID: target)
                                    modelContext.insert(dup)
                                },
                                onMove: { note.projectID = $0; note.updatedAt = Date() }
                            )
                            Button(role: .destructive) { modelContext.delete(note) } label: { Image(systemName: "trash") }
                                .buttonStyle(.plain).foregroundStyle(.red)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(item: $editing) { NoteEditor(note: $0).frame(width: 620, height: 480) }
    }
}

struct NoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var loc: LocalizationManager
    let note: ProjectNote

    @State private var title: String
    @State private var body_: String
    @State private var tagIDs: [UUID]

    init(note: ProjectNote) {
        self.note = note
        _title = State(initialValue: note.title)
        _body_ = State(initialValue: note.body)
        _tagIDs = State(initialValue: note.tagIDs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(loc("notes.title"), text: $title).textFieldStyle(.roundedBorder).font(.title3)
            TagPicker(selectedIDs: $tagIDs)
            TextEditor(text: $body_)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.black.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            HStack {
                Spacer()
                Button(loc("common.save")) {
                    note.title = title.isEmpty ? loc("notes.title") : title
                    note.body = body_
                    note.tagIDs = tagIDs
                    note.updatedAt = Date()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
    }
}

struct RowButtons: View {
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onEdit) { Image(systemName: "pencil") }.buttonStyle(.plain)
            Button(action: onDelete) { Image(systemName: "trash") }.buttonStyle(.plain).foregroundStyle(.red)
        }
    }
}

struct EditorButtons: View {
    @EnvironmentObject private var loc: LocalizationManager
    let disabled: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(loc("common.cancel"), action: onCancel)
            Button(loc("common.save"), action: onSave)
                .keyboardShortcut(.defaultAction)
                .disabled(disabled)
        }
    }
}

struct EmptyHint: View {
    @EnvironmentObject private var loc: LocalizationManager
    var icon: String = "sparkles"
    @State private var appear = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.4)], startPoint: .top, endPoint: .bottom))
                .scaleEffect(appear ? 1 : 0.7)
                .opacity(appear ? 1 : 0)
            Text(loc("common.empty"))
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appear = true }
        }
    }
}
