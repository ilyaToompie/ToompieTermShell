import SwiftData
import SwiftUI

let tagPalette = ["#FF5F6D", "#5E9EFF", "#39E08B", "#FFB454", "#C792EA", "#21D3D3", "#F06595", "#A0E426"]

struct TagChip: View {
    let tag: Tag
    var selected: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(Color(hex: tag.colorHex)).frame(width: 6, height: 6)
                .shadow(color: Color(hex: tag.colorHex).opacity(0.8), radius: selected ? 3 : 0)
            Text(tag.name).font(.caption2.weight(.medium)).lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            LinearGradient(
                colors: [Color(hex: tag.colorHex).opacity(selected ? 0.5 : 0.2), Color(hex: tag.colorHex).opacity(selected ? 0.28 : 0.1)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color(hex: tag.colorHex).opacity(selected ? 0.95 : 0.3)))
    }
}

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: $text).textFieldStyle(.plain).font(.callout)
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1)))
    }
}

struct TagFilterBar: View {
    @EnvironmentObject private var loc: LocalizationManager
    let tags: [Tag]
    @Binding var selected: UUID?

    var body: some View {
        if !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button { selected = nil } label: {
                        Text(loc("filter.all")).font(.caption2.weight(.medium))
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(selected == nil ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.06))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(selected == nil ? Color.accentColor : Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    ForEach(tags) { tag in
                        Button { selected = (selected == tag.id) ? nil : tag.id } label: {
                            TagChip(tag: tag, selected: selected == tag.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct TagRowChips: View {
    let ids: [UUID]
    let tags: [Tag]

    var body: some View {
        let resolved = ids.compactMap { id in tags.first { $0.id == id } }
        if !resolved.isEmpty {
            HStack(spacing: 4) {
                ForEach(resolved) { TagChip(tag: $0) }
            }
        }
    }
}

struct TagPicker: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var loc: LocalizationManager
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Binding var selectedIDs: [UUID]
    @State private var newName = ""
    @State private var newColor = tagPalette[0]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !tags.isEmpty {
                FlowChips(tags: tags, selectedIDs: $selectedIDs)
            }
            HStack(spacing: 6) {
                ForEach(tagPalette, id: \.self) { hex in
                    Circle().fill(Color(hex: hex)).frame(width: 16, height: 16)
                        .overlay(Circle().stroke(Color.white, lineWidth: newColor == hex ? 2 : 0))
                        .onTapGesture { newColor = hex }
                }
                TextField(loc("tags.add"), text: $newName).textFieldStyle(.roundedBorder).frame(maxWidth: 140)
                Button { addTag() } label: { Image(systemName: "plus.circle.fill") }
                    .buttonStyle(.plain).disabled(newName.isEmpty)
            }
        }
    }

    private func addTag() {
        let tag = Tag(name: newName, colorHex: newColor)
        modelContext.insert(tag)
        selectedIDs.append(tag.id)
        newName = ""
    }
}

struct FlowChips: View {
    let tags: [Tag]
    @Binding var selectedIDs: [UUID]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags) { tag in
                    Button {
                        if let idx = selectedIDs.firstIndex(of: tag.id) {
                            selectedIDs.remove(at: idx)
                        } else {
                            selectedIDs.append(tag.id)
                        }
                    } label: {
                        TagChip(tag: tag, selected: selectedIDs.contains(tag.id))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct TagsTab: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var loc: LocalizationManager
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var editing: Tag?
    @State private var showingAdd = false

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                SectionTitle(title: loc("tags.title"), systemImage: "tag.fill")
                ShimmerAddButton { showingAdd = true }
            }
            ScrollView {
                LazyVStack(spacing: 8) {
                    if tags.isEmpty { EmptyHint() }
                    ForEach(tags) { tag in
                        SidebarCard {
                            HStack {
                                Circle().fill(Color(hex: tag.colorHex)).frame(width: 14, height: 14)
                                Text(tag.name).font(.subheadline.weight(.semibold))
                                Spacer()
                                RowButtons(onEdit: { editing = tag }, onDelete: { modelContext.delete(tag) })
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAdd) { TagEditor(tag: nil).frame(width: 420) }
        .sheet(item: $editing) { TagEditor(tag: $0).frame(width: 420) }
    }
}

struct TagEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var loc: LocalizationManager
    let tag: Tag?

    @State private var name: String
    @State private var colorHex: String

    init(tag: Tag?) {
        self.tag = tag
        _name = State(initialValue: tag?.name ?? "")
        _colorHex = State(initialValue: tag?.colorHex ?? tagPalette[0])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tag == nil ? loc("tags.add") : loc("common.edit")).font(.title3.weight(.semibold))
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
        if let tag {
            tag.name = name
            tag.colorHex = colorHex
        } else {
            modelContext.insert(Tag(name: name, colorHex: colorHex))
        }
        dismiss()
    }
}
