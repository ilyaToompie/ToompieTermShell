import AppKit
import SwiftData
import SwiftUI

struct SidebarView: View {
    @Binding var selectedTab: SidebarTab
    @EnvironmentObject private var loc: LocalizationManager

    var body: some View {
        VStack(spacing: 10) {
            ScopeSelector()
            tabBar

            Group {
                switch selectedTab {
                case .projects:
                    ProjectsTab()
                case .ssh:
                    SSHSidebarTab()
                case .locations:
                    PathsSidebarTab()
                case .commands:
                    CommandsSidebarTab()
                case .config:
                    ConfigTab()
                case .tags:
                    TagsTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(selectedTab)
            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .animation(.easeInOut(duration: 0.22), value: selectedTab)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(SidebarTab.allCases) { tab in
                tabButton(tab)
            }
        }
    }

    private func tabButton(_ tab: SidebarTab) -> some View {
        let active = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 15))
                Text(loc(tab.titleKey))
                    .font(.system(size: 9.5, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .padding(.horizontal, 1)
            .background(
                Group {
                    if active {
                        LinearGradient(colors: [Color.accentColor.opacity(0.28), Color.accentColor.opacity(0.12)], startPoint: .top, endPoint: .bottom)
                    } else {
                        Color.white.opacity(0.04)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(active ? Color.accentColor.opacity(0.6) : Color.white.opacity(0.08)))
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .shadow(color: active ? Color.accentColor.opacity(0.45) : .clear, radius: 7, y: 1)
        }
        .buttonStyle(.plain)
        .foregroundStyle(active ? Color.accentColor : Color.secondary)
        .hoverScale(1.06)
    }
}

struct ScopeSelector: View {
    @EnvironmentObject private var scope: ScopeManager
    @EnvironmentObject private var loc: LocalizationManager
    @Query(sort: \Project.name) private var projects: [Project]

    private var currentName: String {
        if let id = scope.currentProjectID, let project = projects.first(where: { $0.id == id }) {
            return project.name
        }
        return loc("scope.global")
    }

    private var currentColor: Color {
        if let id = scope.currentProjectID, let project = projects.first(where: { $0.id == id }) {
            return Color(hex: project.colorHex)
        }
        return .secondary
    }

    var body: some View {
        Menu {
            Button {
                scope.currentProjectID = nil
            } label: {
                Label(loc("scope.global"), systemImage: scope.isGlobal ? "checkmark" : "globe")
            }
            if !projects.isEmpty { Divider() }
            ForEach(projects) { project in
                Button {
                    scope.currentProjectID = project.id
                } label: {
                    Label(project.name, systemImage: scope.currentProjectID == project.id ? "checkmark" : "folder")
                }
            }
        } label: {
            HStack(spacing: 8) {
                Circle().fill(currentColor).frame(width: 9, height: 9)
                Text(currentName).font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [currentColor.opacity(0.18), Color.white.opacity(0.05)], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(currentColor.opacity(0.4)))
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .shadow(color: currentColor.opacity(0.3), radius: 6, y: 2)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
}

struct TerminalTargetMenu: View {
    @EnvironmentObject private var terminalManager: TerminalWorkspaceManager
    @EnvironmentObject private var loc: LocalizationManager
    let title: String
    let systemImage: String
    let prominent: Bool
    let action: (Int) -> Void

    init(title: String, systemImage: String = "play.fill", prominent: Bool = false, action: @escaping (Int) -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.prominent = prominent
        self.action = action
    }

    var body: some View {
        Menu {
            Button(loc("common.focused")) { action(terminalManager.focusedPanelIndex) }
            Divider()
            ForEach(0..<terminalManager.visiblePanelCount, id: \.self) { index in
                Button("\(loc("terminal.panel")) \(index + 1)") { action(index) }
            }
        } label: {
            Label(title, systemImage: systemImage)
        } primaryAction: {
            action(terminalManager.focusedPanelIndex)
        }
        .menuStyle(.borderlessButton)
        .controlSize(.small)
        .fixedSize()
    }
}

struct TargetSegments: View {
    @EnvironmentObject private var terminalManager: TerminalWorkspaceManager
    let action: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                Button {
                    action(index)
                } label: {
                    Text("\(index + 1)")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                }
                .buttonStyle(.plain)
                .disabled(index >= terminalManager.visiblePanelCount)
                .background(index < terminalManager.visiblePanelCount ? Color.white.opacity(0.10) : Color.white.opacity(0.03))
                .foregroundStyle(index < terminalManager.visiblePanelCount ? Color.primary : Color.secondary)

                if index < 3 {
                    Rectangle()
                        .fill(Color.black.opacity(0.45))
                        .frame(width: 1, height: 24)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12)))
        .help("Send to terminal panel 1, 2, 3, or 4")
    }
}

enum Clipboard {
    @MainActor
    static func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        ToastCenter.shared.key("toast.copied", icon: "doc.on.doc.fill")
    }
}

enum CommandConfirmation {
    @MainActor
    static func shouldRun(_ command: String) -> Bool {
        guard AppPreferences.shared.confirmDangerous else { return true }
        guard ShellSafety.containsObviousDangerousPattern(command) else { return true }

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Run destructive command?"
        alert.informativeText = "This command matches a dangerous pattern. Review it before running."
        alert.addButton(withTitle: "Run")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}

struct SidebarCard<Content: View>: View {
    let content: Content
    @State private var appeared = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(10)
        .background(
            LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.12)))
        .hoverScale(1.01, lift: true)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .onAppear { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { appeared = true } }
    }
}

struct EditorRow<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .trailing)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct EditorTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        TextField(title, text: $text)
            .textFieldStyle(.roundedBorder)
    }
}
