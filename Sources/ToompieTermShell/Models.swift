import Foundation
import SwiftData

enum SidebarTab: String, CaseIterable, Identifiable {
    case ssh = "SSH"
    case paths = "Paths"
    case commands = "Commands"

    var id: String { rawValue }
}

enum SSHAuthType: String, CaseIterable, Identifiable, Codable {
    case key
    case password

    var id: String { rawValue }
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
        startupCommand: String = ""
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
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var authType: SSHAuthType {
        get { SSHAuthType(rawValue: authTypeRawValue) ?? .key }
        set { authTypeRawValue = newValue.rawValue }
    }
}

@Model
final class PinnedPath {
    @Attribute(.unique) var id: UUID
    var name: String
    var absolutePath: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, absolutePath: String) {
        self.id = id
        self.name = name
        self.absolutePath = absolutePath
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class CommandShortcut {
    @Attribute(.unique) var id: UUID
    var name: String
    var command: String
    var workingDirectory: String
    var commandDescription: String
    var tags: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        workingDirectory: String = "",
        commandDescription: String = "",
        tags: String = ""
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
        self.commandDescription = commandDescription
        self.tags = tags
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
