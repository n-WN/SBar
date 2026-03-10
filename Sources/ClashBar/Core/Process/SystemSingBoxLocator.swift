import Foundation

struct SystemSingBoxLocator {
    struct Installation: Equatable {
        let path: String
        let version: String?
        let hasClashAPI: Bool
    }

    func availability(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment) -> SystemSingBoxAvailability
    {
        var firstIncompatiblePath: String?

        for candidatePath in self.candidatePaths(environment: environment) {
            guard let installation = self.inspectBinary(at: candidatePath, fileManager: fileManager) else {
                continue
            }
            if installation.hasClashAPI {
                return .available(path: installation.path, version: installation.version)
            }
            if firstIncompatiblePath == nil {
                firstIncompatiblePath = installation.path
            }
        }

        if let firstIncompatiblePath {
            return .incompatible(path: firstIncompatiblePath)
        }
        return .unavailable
    }

    private func candidatePaths(environment: [String: String]) -> [String] {
        let explicitPaths = [
            "/opt/homebrew/bin/sing-box",
            "/opt/homebrew/sbin/sing-box",
            "/usr/local/bin/sing-box",
            "/usr/local/sbin/sing-box",
            "/usr/bin/sing-box",
            "/bin/sing-box",
        ]

        let pathCandidates = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0).appendingPathComponent("sing-box", isDirectory: false).path }

        var deduplicated: [String] = []
        var seen = Set<String>()
        for path in explicitPaths + pathCandidates {
            let normalized = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
            if seen.insert(normalized).inserted {
                deduplicated.append(normalized)
            }
        }
        return deduplicated
    }

    private func inspectBinary(at path: String, fileManager: FileManager) -> Installation? {
        let resolvedPath = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: resolvedPath, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return nil
        }
        guard fileManager.isExecutableFile(atPath: resolvedPath) else {
            return nil
        }

        let output = self.versionOutput(for: resolvedPath)
        let version = self.parseVersion(from: output)
        let hasClashAPI = output.contains("with_clash_api")
        return Installation(path: resolvedPath, version: version, hasClashAPI: hasClashAPI)
    }

    private func versionOutput(for path: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    private func parseVersion(from output: String) -> String? {
        for line in output.split(whereSeparator: \.isNewline) {
            let trimmed = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("sing-box version ") else { continue }
            let version = trimmed.replacingOccurrences(of: "sing-box version ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return version.isEmpty ? nil : version
        }
        return nil
    }
}
