import SwiftData
import SwiftUI

enum Snippet {
    static func variables(in command: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "\\{\\{\\s*([A-Za-z0-9_]+)\\s*\\}\\}") else { return [] }
        let range = NSRange(command.startIndex..., in: command)
        var seen: [String] = []
        regex.enumerateMatches(in: command, range: range) { match, _, _ in
            guard let match, let r = Range(match.range(at: 1), in: command) else { return }
            let name = String(command[r])
            if !seen.contains(name) { seen.append(name) }
        }
        return seen
    }

    static func substitute(_ command: String, values: [String: String]) -> String {
        var result = command
        for (key, value) in values {
            for pattern in ["{{\(key)}}", "{{ \(key) }}"] {
                result = result.replacingOccurrences(of: pattern, with: value)
            }
        }
        guard let regex = try? NSRegularExpression(pattern: "\\{\\{\\s*([A-Za-z0-9_]+)\\s*\\}\\}") else { return result }
        let range = NSRange(result.startIndex..., in: result)
        return regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
    }
}

struct SnippetFillSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var loc: LocalizationManager
    @EnvironmentObject private var prefs: AppPreferences
    @Query(sort: \SSHShortcut.name) private var servers: [SSHShortcut]

    let commandText: String
    let variables: [String]
    let onRun: (String) -> Void

    @State private var values: [String: String] = [:]
    @State private var serverID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(loc("snippet.fill")).font(.title3.weight(.semibold))

            if !servers.isEmpty {
                HStack {
                    Text(loc("snippet.fromServer")).font(.callout.weight(.medium)).frame(width: 120, alignment: .leading)
                    Picker("", selection: $serverID) {
                        Text("—").tag(UUID?.none)
                        ForEach(servers) { server in
                            Text("\(server.icon) \(server.name)").tag(UUID?.some(server.id))
                        }
                    }
                    .labelsHidden()
                    .onChange(of: serverID) { _, id in fillFromServer(id) }
                }
            }

            ForEach(variables, id: \.self) { variable in
                HStack {
                    Text(variable).font(.callout.weight(.medium).monospaced()).frame(width: 120, alignment: .leading)
                    TextField(variable, text: binding(for: variable)).textFieldStyle(.roundedBorder)
                }
            }

            Text(preview).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).lineLimit(3)
                .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.25)).clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Spacer()
                Button(loc("common.cancel")) { dismiss() }
                Button(loc("common.run")) { onRun(preview); dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 540)
        .onAppear(perform: prefill)
    }

    private var preview: String {
        Snippet.substitute(commandText, values: values)
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(get: { values[key] ?? "" }, set: { values[key] = $0 })
    }

    private func prefill() {
        for v in variables {
            switch v.lowercased() {
            case "user", "username": values[v] = prefs.defaultUser
            case "port": values[v] = "\(prefs.defaultPort)"
            default: values[v] = values[v] ?? ""
            }
        }
    }

    private func fillFromServer(_ id: UUID?) {
        guard let id, let server = servers.first(where: { $0.id == id }) else { return }
        for v in variables {
            switch v.lowercased() {
            case "host", "server", "ip": values[v] = server.host
            case "port": values[v] = "\(server.port)"
            case "user", "username": values[v] = server.username
            default: break
            }
        }
    }
}
