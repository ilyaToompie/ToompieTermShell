import Foundation
import SwiftData

enum SidebarTab: String, CaseIterable, Identifiable {
    case projects = "Projects"
    case ssh = "SSH"
    case locations = "Locations"
    case commands = "Commands"
    case config = "Config"
    case tags = "Tags"

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .projects: return "tab.projects"
        case .ssh: return "tab.ssh"
        case .locations: return "tab.locations"
        case .commands: return "tab.commands"
        case .config: return "tab.config"
        case .tags: return "tab.tags"
        }
    }

    var systemImage: String {
        switch self {
        case .projects: return "square.stack.3d.up.fill"
        case .ssh: return "network"
        case .locations: return "mappin.and.ellipse"
        case .commands: return "terminal.fill"
        case .config: return "slider.horizontal.3"
        case .tags: return "tag.fill"
        }
    }
}

enum ProjectSection: String, CaseIterable, Identifiable {
    case ssh
    case locations
    case commands
    case notes

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .ssh: return "tab.ssh"
        case .locations: return "tab.locations"
        case .commands: return "tab.commands"
        case .notes: return "projects.notes"
        }
    }

    var systemImage: String {
        switch self {
        case .ssh: return "network"
        case .locations: return "mappin.and.ellipse"
        case .commands: return "terminal.fill"
        case .notes: return "note.text"
        }
    }
}

enum SSHAuthType: String, CaseIterable, Identifiable, Codable {
    case key
    case password

    var id: String { rawValue }
}

protocol Taggable: AnyObject {
    var tagIDsRaw: String { get set }
}

extension Taggable {
    var tagIDs: [UUID] {
        get { tagIDsRaw.split(separator: ",").compactMap { UUID(uuidString: String($0)) } }
        set { tagIDsRaw = newValue.map { $0.uuidString }.joined(separator: ",") }
    }

    func hasTag(_ id: UUID) -> Bool { tagIDs.contains(id) }
}

@Model
final class Tag {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, colorHex: String = "#5E9EFF") {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
    }
}

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var icon: String = "📁"
    var createdAt: Date

    init(id: UUID = UUID(), name: String, colorHex: String = "#5E9EFF", icon: String = "📁") {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.createdAt = Date()
    }
}

@Model
final class SSHShortcut {
    @Attribute(.unique) var id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var authTypeRawValue: String
    var privateKeyPath: String
    var rememberPassword: Bool
    var startupDirectory: String
    var startupCommand: String
    var icon: String = "🖥️"
    var tagIDsRaw: String = ""
    var projectID: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 22,
        username: String,
        authType: SSHAuthType = .key,
        privateKeyPath: String = "",
        rememberPassword: Bool = false,
        startupDirectory: String = "",
        startupCommand: String = "",
        icon: String = "🖥️",
        tagIDsRaw: String = "",
        projectID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authTypeRawValue = authType.rawValue
        self.privateKeyPath = privateKeyPath
        self.rememberPassword = rememberPassword
        self.startupDirectory = startupDirectory
        self.startupCommand = startupCommand
        self.icon = icon
        self.tagIDsRaw = tagIDsRaw
        self.projectID = projectID
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var authType: SSHAuthType {
        get { SSHAuthType(rawValue: authTypeRawValue) ?? .key }
        set { authTypeRawValue = newValue.rawValue }
    }
}

extension SSHShortcut: Taggable {}

@Model
final class PinnedPath {
    @Attribute(.unique) var id: UUID
    var name: String
    var absolutePath: String
    var icon: String = "📂"
    var tagIDsRaw: String = ""
    var projectID: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, absolutePath: String, icon: String = "📂", tagIDsRaw: String = "", projectID: UUID? = nil) {
        self.id = id
        self.name = name
        self.absolutePath = absolutePath
        self.icon = icon
        self.tagIDsRaw = tagIDsRaw
        self.projectID = projectID
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

extension PinnedPath: Taggable {}

@Model
final class CommandShortcut {
    @Attribute(.unique) var id: UUID
    var name: String
    var command: String
    var workingDirectory: String
    var commandDescription: String
    var icon: String = "⚡️"
    var tagIDsRaw: String = ""
    var projectID: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        workingDirectory: String = "",
        commandDescription: String = "",
        icon: String = "⚡️",
        tagIDsRaw: String = "",
        projectID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
        self.commandDescription = commandDescription
        self.icon = icon
        self.tagIDsRaw = tagIDsRaw
        self.projectID = projectID
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

extension CommandShortcut: Taggable {}

@Model
final class ProjectNote {
    @Attribute(.unique) var id: UUID
    var title: String
    var body: String
    var tagIDsRaw: String = ""
    var projectID: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, body: String = "", tagIDsRaw: String = "", projectID: UUID? = nil) {
        self.id = id
        self.title = title
        self.body = body
        self.tagIDsRaw = tagIDsRaw
        self.projectID = projectID
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

extension ProjectNote: Taggable {}

@Model
final class ConfigFile {
    @Attribute(.unique) var id: UUID
    var name: String
    var path: String
    var projectID: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, path: String, projectID: UUID? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.projectID = projectID
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class TerminalLayoutPreference {
    @Attribute(.unique) var id: UUID
    var visiblePanelCount: Int
    var threePanelMode: String
    var updatedAt: Date

    init(id: UUID = UUID(), visiblePanelCount: Int = 1, threePanelMode: String = "twoLeftOneRight") {
        self.id = id
        self.visiblePanelCount = visiblePanelCount
        self.threePanelMode = threePanelMode
        self.updatedAt = Date()
    }
}

@Model
final class AppSettings {
    @Attribute(.unique) var id: UUID
    var lastSelectedSidebarTab: String
    var sidebarWidth: Double
    var confirmDangerousCommands: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        lastSelectedSidebarTab: String = SidebarTab.ssh.rawValue,
        sidebarWidth: Double = 310,
        confirmDangerousCommands: Bool = true
    ) {
        self.id = id
        self.lastSelectedSidebarTab = lastSelectedSidebarTab
        self.sidebarWidth = sidebarWidth
        self.confirmDangerousCommands = confirmDangerousCommands
        self.updatedAt = Date()
    }
}
