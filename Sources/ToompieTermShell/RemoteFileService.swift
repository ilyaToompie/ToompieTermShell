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

enum RemoteFileService {
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

    private static func scpArgs(shortcut: SSHShortcut) -> [String] {
        var args = ["-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=accept-new", "-P", "\(max(shortcut.port, 1))"]
        if shortcut.authType == .key, !shortcut.privateKeyPath.isEmpty {
            args.append("-i")
            args.append(shortcut.privateKeyPath)
        }
        return args
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
