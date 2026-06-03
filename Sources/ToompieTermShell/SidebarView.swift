import AppKit
import SwiftData
import SwiftUI

struct SidebarView: View {
    @Binding var selectedTab: SidebarTab

    var body: some View {
        VStack(spacing: 12) {
            Picker("Sidebar", selection: $selectedTab) {
                ForEach(SidebarTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Group {
                switch selectedTab {
                case .ssh:
                    SSHSidebarTab()
                case .paths:
                    PathsSidebarTab()
                case .commands:
                    CommandsSidebarTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
        .background(Color(red: 0.10, green: 0.11, blue: 0.14))
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
    static func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

enum CommandConfirmation {
    static func shouldRun(_ command: String) -> Bool {
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

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(10)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.10)))
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
