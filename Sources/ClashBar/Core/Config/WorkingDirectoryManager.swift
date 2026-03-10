import Foundation

struct WorkingDirectoryManager {
    static let currentRootDirectoryName = "singbar"
    static let previousRootDirectoryName = "sbar"
    static let legacyRootDirectoryName = "clashbar"

    let homeDirectory: URL

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    var rootDirectoryURL: URL {
        self.currentRootDirectoryURL
    }

    var currentRootDirectoryURL: URL {
        self.homeDirectory.appendingPathComponent(
            "Library/Application Support/\(Self.currentRootDirectoryName)",
            isDirectory: true)
    }

    var legacyRootDirectoryURL: URL {
        self.homeDirectory.appendingPathComponent(
            "Library/Application Support/\(Self.legacyRootDirectoryName)",
            isDirectory: true)
    }

    var previousRootDirectoryURL: URL {
        self.homeDirectory.appendingPathComponent(
            "Library/Application Support/\(Self.previousRootDirectoryName)",
            isDirectory: true)
    }

    var configDirectoryURL: URL {
        self.rootDirectoryURL.appendingPathComponent("config", isDirectory: true)
    }

    var logsDirectoryURL: URL {
        self.rootDirectoryURL.appendingPathComponent("logs", isDirectory: true)
    }

    var stateDirectoryURL: URL {
        self.rootDirectoryURL.appendingPathComponent("state", isDirectory: true)
    }

    var coreDirectoryURL: URL {
        self.rootDirectoryURL.appendingPathComponent("core", isDirectory: true)
    }

    var managedMihomoBinaryURL: URL {
        self.coreDirectoryURL.appendingPathComponent("mihomo", isDirectory: false)
    }

    var managedSingBoxBinaryURL: URL {
        self.coreDirectoryURL.appendingPathComponent("sing-box", isDirectory: false)
    }

    func bootstrapDirectories(fileManager: FileManager = .default) throws {
        try self.migrateLegacyRootsIfNeeded(fileManager: fileManager)
        try self.createDirectoryIfNeeded(self.rootDirectoryURL, fileManager: fileManager)
        try self.createDirectoryIfNeeded(self.configDirectoryURL, fileManager: fileManager)
        try self.createDirectoryIfNeeded(self.logsDirectoryURL, fileManager: fileManager)
        try self.createDirectoryIfNeeded(self.stateDirectoryURL, fileManager: fileManager)
        try self.createDirectoryIfNeeded(self.coreDirectoryURL, fileManager: fileManager)
    }

    func migrateLegacyRootsIfNeeded(fileManager: FileManager = .default) throws {
        guard !fileManager.fileExists(atPath: self.rootDirectoryURL.path) else { return }

        let sources = [self.previousRootDirectoryURL, self.legacyRootDirectoryURL]
        guard let sourceRoot = sources.first(where: { fileManager.fileExists(atPath: $0.path) }) else { return }

        try self.createDirectoryIfNeeded(self.rootDirectoryURL, fileManager: fileManager)

        for directoryName in ["config", "core", "state", "logs"] {
            let sourceDirectory = sourceRoot.appendingPathComponent(directoryName, isDirectory: true)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: sourceDirectory.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }

            let destinationDirectory = self.rootDirectoryURL.appendingPathComponent(directoryName, isDirectory: true)
            try self.createDirectoryIfNeeded(destinationDirectory, fileManager: fileManager)
            try self.copyDirectoryContents(
                from: sourceDirectory,
                to: destinationDirectory,
                fileManager: fileManager)
        }
    }

    func normalizeAndValidateWithinRoot(_ url: URL, mustBeDirectory: Bool? = nil) throws -> URL {
        let standardized = url.standardizedFileURL.resolvingSymlinksInPath()
        let root = self.rootDirectoryURL.standardizedFileURL.resolvingSymlinksInPath()
        guard self.isDescendantOrEqual(standardized, parent: root) else {
            throw NSError(
                domain: "SingBar.PathSecurity",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Path escapes SingBar working directory: \(standardized.path)"])
        }

        if let mustBeDirectory {
            let values = try standardized.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory != mustBeDirectory {
                throw NSError(
                    domain: "SingBar.PathSecurity",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: mustBeDirectory
                        ? "Expected directory path: \(standardized.path)"
                        : "Expected file path: \(standardized.path)"])
            }
        }

        return standardized
    }

    private func createDirectoryIfNeeded(_ url: URL, fileManager: FileManager) throws {
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                throw NSError(
                    domain: "SingBar.PathSecurity",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "Expected directory but found file: \(url.path)"])
            }
            return
        }

        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func isDescendantOrEqual(_ child: URL, parent: URL) -> Bool {
        let childComponents = child.pathComponents
        let parentComponents = parent.pathComponents

        guard parentComponents.count <= childComponents.count else { return false }
        return zip(parentComponents, childComponents).allSatisfy { $0 == $1 }
    }

    private func copyDirectoryContents(from source: URL, to destination: URL, fileManager: FileManager) throws {
        let items = try fileManager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles])

        for item in items {
            let target = destination.appendingPathComponent(item.lastPathComponent, isDirectory: false)
            if fileManager.fileExists(atPath: target.path) {
                continue
            }
            try fileManager.copyItem(at: item, to: target)
        }
    }
}
