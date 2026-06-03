import Foundation

enum ShellSafety {
    static func singleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func cdCommand(to path: String) -> String {
        "cd \(singleQuoted(path))\n"
    }

    static func commandLine(_ command: String) -> String {
        command.hasSuffix("\n") ? command : command + "\n"
    }

    static func containsObviousDangerousPattern(_ command: String) -> Bool {
        let normalized = command
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let patterns = [
            #"(^|[;&|]\s*)sudo\s+rm\s+-[^\n;|&]*r[^\n;|&]*f\s+/"#,
            #"(^|[;&|]\s*)rm\s+-[^\n;|&]*r[^\n;|&]*f\s+/"#,
            #"diskutil\s+erase"#,
            #"mkfs(\.| |\b)"#,
            #">\s*/dev/(disk|rdisk)"#
        ]

        return patterns.contains { pattern in
            normalized.range(of: pattern, options: .regularExpression) != nil
        }
    }
}

enum SSHCommandBuilder {
    static func command(for shortcut: SSHShortcut) -> String {
        var parts = ["ssh"]
        if shortcut.authType == .key, !shortcut.privateKeyPath.isEmpty {
            parts.append("-i")
            parts.append(ShellSafety.singleQuoted(shortcut.privateKeyPath))
        }
        parts.append("-p")
        parts.append("\(max(shortcut.port, 1))")
        parts.append(ShellSafety.singleQuoted("\(shortcut.username)@\(shortcut.host)"))
        return parts.joined(separator: " ")
    }

    static func startupSuffix(for shortcut: SSHShortcut) -> String {
        var lines: [String] = []
        if !shortcut.startupDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("cd \(ShellSafety.singleQuoted(shortcut.startupDirectory))")
        }
        if !shortcut.startupCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(shortcut.startupCommand)
        }
        guard !lines.isEmpty else { return "" }

        let remote = lines.joined(separator: " && ")
        return " -t \(ShellSafety.singleQuoted(remote))"
    }
}
