import Foundation

struct RemoteFilePayload {
    let localPath: String
    let text: String
}

enum RemoteFileError: LocalizedError {
    case transferFailed(String)

    var errorDescription: String? {
        switch self {
        case .transferFailed(let message): return message.isEmpty ? "Transfer failed" : message
        }
    }
}

struct RemoteEntry: Identifiable {
    let name: String
    let isDir: Bool
    let path: String
    var id: String { path }
}

enum RemoteFileService {
    private static var cache: [String: [RemoteEntry]] = [:]
    private static let cacheLock = NSLock()

    private static func cacheKey(_ shortcut: SSHShortcut, _ path: String) -> String {
        "\(shortcut.id.uuidString):\(path)"
    }

    private static func cached(_ shortcut: SSHShortcut, _ path: String) -> [RemoteEntry]? {
        cacheLock.lock(); defer { cacheLock.unlock() }
        return cache[cacheKey(shortcut, path)]
    }

    private static func store(_ entries: [RemoteEntry], _ shortcut: SSHShortcut, _ path: String) {
        cacheLock.lock(); defer { cacheLock.unlock() }
        cache[cacheKey(shortcut, path)] = entries
    }

    static func clearCache(for shortcut: SSHShortcut) {
        cacheLock.lock(); defer { cacheLock.unlock() }
        let prefix = "\(shortcut.id.uuidString):"
        cache = cache.filter { !$0.key.hasPrefix(prefix) }
    }

    static func list(shortcut: SSHShortcut, path: String, force: Bool = false, completion: @escaping (Result<[RemoteEntry], Error>) -> Void) {
        if !force, let hit = cached(shortcut, path) {
            DispatchQueue.main.async { completion(.success(hit)) }
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let result = rawList(shortcut: shortcut, path: path)
            if case .success(let entries) = result {
                store(entries, shortcut, path)
                prefetchChildren(shortcut: shortcut, entries: entries)
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    private static func rawList(shortcut: SSHShortcut, path: String) -> Result<[RemoteEntry], Error> {
        let target = "\(shortcut.username)@\(shortcut.host)"
        let remoteCommand = "ls -1Ap -- " + ShellSafety.singleQuoted(path)
        let result = runProcess(tool: "/usr/bin/ssh", args: sshArgs(shortcut: shortcut) + [target, remoteCommand])
        switch result {
        case .success(let output):
            let entries: [RemoteEntry] = output.split(separator: "\n").compactMap { raw in
                let line = String(raw)
                guard !line.isEmpty, line != "./", line != "../" else { return nil }
                let isDir = line.hasSuffix("/")
                let name = isDir ? String(line.dropLast()) : line
                guard !name.isEmpty, name != ".", name != ".." else { return nil }
                let child: String
                if path == "." || path.isEmpty {
                    child = name
                } else if path.hasSuffix("/") {
                    child = path + name
                } else {
                    child = path + "/" + name
                }
                return RemoteEntry(name: name, isDir: isDir, path: child)
            }
            .sorted { a, b in
                a.isDir != b.isDir ? a.isDir : a.name.lowercased() < b.name.lowercased()
            }
            return .success(entries)
        case .failure(let error):
            return .failure(error)
        }
    }

    private static func prefetchChildren(shortcut: SSHShortcut, entries: [RemoteEntry]) {
        let dirs = entries.filter { $0.isDir }.prefix(12)
        for dir in dirs where cached(shortcut, dir.path) == nil {
            DispatchQueue.global(qos: .utility).async {
                if cached(shortcut, dir.path) != nil { return }
                if case .success(let children) = rawList(shortcut: shortcut, path: dir.path) {
                    store(children, shortcut, dir.path)
                }
            }
        }
    }

    static func prewarm(shortcut: SSHShortcut) {
        let path = shortcut.startupDirectory.isEmpty ? "." : shortcut.startupDirectory
        if cached(shortcut, path) != nil { return }
        DispatchQueue.global(qos: .utility).async {
            if cached(shortcut, path) != nil { return }
            if case .success(let entries) = rawList(shortcut: shortcut, path: path) {
                store(entries, shortcut, path)
                prefetchChildren(shortcut: shortcut, entries: entries)
            }
        }
    }

    static func exec(shortcut: SSHShortcut, remoteCommand: String, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let target = "\(shortcut.username)@\(shortcut.host)"
            let result = runProcess(tool: "/usr/bin/ssh", args: sshArgs(shortcut: shortcut) + [target, remoteCommand])
            DispatchQueue.main.async { completion(result.map { _ in () }) }
        }
    }

    static func uploadFile(shortcut: SSHShortcut, localPath: String, remotePath: String, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let target = "\(shortcut.username)@\(shortcut.host):\(remotePath)"
            let result = runProcess(tool: "/usr/bin/scp", args: scpArgs(shortcut: shortcut) + ["-r", localPath, target])
            DispatchQueue.main.async { completion(result.map { _ in () }) }
        }
    }

    static func download(shortcut: SSHShortcut, remotePath: String, localPath: String, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let target = "\(shortcut.username)@\(shortcut.host):\(remotePath)"
            let result = runProcess(tool: "/usr/bin/scp", args: scpArgs(shortcut: shortcut) + ["-r", target, localPath])
            DispatchQueue.main.async { completion(result.map { _ in () }) }
        }
    }

    static func fetch(shortcut: SSHShortcut, remotePath: String, completion: @escaping (Result<RemoteFilePayload, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let temp = FileManager.default.temporaryDirectory
                .appendingPathComponent("ToompieTermShell-remote", isDirectory: true)
            try? FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
            let localURL = temp.appendingPathComponent((remotePath as NSString).lastPathComponent.isEmpty ? "remote.txt" : (remotePath as NSString).lastPathComponent)

            let target = remoteTarget(shortcut: shortcut, remotePath: remotePath)
            let result = runSCP(args: scpArgs(shortcut: shortcut) + [target, localURL.path])
            DispatchQueue.main.async {
                switch result {
                case .success:
                    let text = (try? String(contentsOf: localURL, encoding: .utf8)) ?? ""
                    completion(.success(RemoteFilePayload(localPath: localURL.path, text: text)))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    static func upload(shortcut: SSHShortcut, localPath: String, remotePath: String, text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            try? text.write(toFile: localPath, atomically: true, encoding: .utf8)
            let target = remoteTarget(shortcut: shortcut, remotePath: remotePath)
            let result = runSCP(args: scpArgs(shortcut: shortcut) + [localPath, target])
            DispatchQueue.main.async { completion(result) }
        }
    }

    private static func remoteTarget(shortcut: SSHShortcut, remotePath: String) -> String {
        "\(shortcut.username)@\(shortcut.host):\(remotePath)"
    }

    private static let controlPath = "/tmp/ttshell-cm-%C"

    private static var multiplexOptions: [String] {
        ["-o", "ControlMaster=auto", "-o", "ControlPath=\(controlPath)", "-o", "ControlPersist=180"]
    }

    private static func scpArgs(shortcut: SSHShortcut) -> [String] {
        var args = ["-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=accept-new", "-o", "ConnectTimeout=12"]
        args += multiplexOptions
        args += ["-P", "\(max(shortcut.port, 1))"]
        if shortcut.authType == .key, !shortcut.privateKeyPath.isEmpty {
            args.append("-i")
            args.append(shortcut.privateKeyPath)
        }
        return args
    }

    private static func sshArgs(shortcut: SSHShortcut) -> [String] {
        var args = ["-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=accept-new", "-o", "ConnectTimeout=12"]
        args += multiplexOptions
        args += ["-p", "\(max(shortcut.port, 1))"]
        if shortcut.authType == .key, !shortcut.privateKeyPath.isEmpty {
            args.append("-i")
            args.append(shortcut.privateKeyPath)
        }
        return args
    }

    private static func runProcess(tool: String, args: [String]) -> Result<String, Error> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        do {
            try process.run()
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return .success(String(data: outData, encoding: .utf8) ?? "")
            }
            let message = String(data: errData, encoding: .utf8) ?? ""
            return .failure(RemoteFileError.transferFailed(message.trimmingCharacters(in: .whitespacesAndNewlines)))
        } catch {
            return .failure(error)
        }
    }

    private static func runSCP(args: [String]) -> Result<Void, Error> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/scp")
        process.arguments = args
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return .success(())
            }
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? ""
            return .failure(RemoteFileError.transferFailed(message.trimmingCharacters(in: .whitespacesAndNewlines)))
        } catch {
            return .failure(error)
        }
    }
}
