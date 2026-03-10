import Darwin
import Foundation

enum CoreBinaryResolutionError: LocalizedError {
    case appManagedBinaryNotFound(expectedDirectory: String)
    case systemSingBoxNotFound
    case systemSingBoxMissingClashAPI(path: String)

    var errorDescription: String? {
        switch self {
        case let .appManagedBinaryNotFound(expectedDirectory):
            "No app-managed core binary was found in \(expectedDirectory)."
        case .systemSingBoxNotFound:
            "No compatible system sing-box installation was found."
        case let .systemSingBoxMissingClashAPI(path):
            "System sing-box is missing Clash API support: \(path)"
        }
    }
}

enum CoreConfigCompatibilityError: LocalizedError {
    case singBoxRequiresJSONConfig(path: String)

    var errorDescription: String? {
        switch self {
        case let .singBoxRequiresJSONConfig(path):
            "sing-box requires a JSON config file: \(path)"
        }
    }
}

enum CoreConfigValidationError: LocalizedError {
    case launchFailed(String)
    case timedOut(commandDescription: String, seconds: Int, details: String)
    case failed(commandDescription: String, exitCode: Int32, details: String)

    var errorDescription: String? {
        switch self {
        case let .launchFailed(message):
            return message
        case let .timedOut(commandDescription, seconds, details):
            let normalizedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalizedDetails.isEmpty {
                return "\(commandDescription) timed out after \(seconds) seconds."
            }
            return "\(commandDescription) timed out after \(seconds) seconds.\n\(normalizedDetails)"
        case let .failed(commandDescription, exitCode, details):
            let normalizedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalizedDetails.isEmpty {
                return "\(commandDescription) exited with code \(exitCode)."
            }
            return normalizedDetails
        }
    }
}

private struct ResolvedCoreBinary {
    let kind: CoreBinaryKind
    let source: CoreSourcePreference
    let path: String

    var logLabel: String {
        self.kind.rawValue
    }

    var validationCommandDescription: String {
        switch self.kind {
        case .mihomo:
            "mihomo -t"
        case .singBox:
            "sing-box check"
        }
    }

    var launchDescription: String {
        switch self.kind {
        case .mihomo:
            "mihomo"
        case .singBox:
            "sing-box"
        }
    }
}

private final class ProcessOutputBox: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func store(_ data: Data) {
        self.lock.withLock {
            self.data = data
        }
    }

    func load() -> Data {
        self.lock.withLock {
            self.data
        }
    }
}

/// Process callbacks run on system-managed threads. Shared mutable state is guarded by `lock`.
final class CoreProcessManager: CoreControlling, @unchecked Sendable {
    private(set) var status: CoreLifecycleStatus = .stopped
    private var process: Process?
    private var stdoutHandle: FileHandle?
    private var stderrHandle: FileHandle?
    private var intentionalStop = false
    private let lock = NSLock()
    private let stateActor = ProcessStateActor()
    private let fileManager: FileManager
    private let workingDirectoryManager: WorkingDirectoryManager
    private let lifecycleQueue: DispatchQueue
    private let validationQueue: DispatchQueue
    private let configValidationTimeout: TimeInterval
    private let systemSingBoxLocator: SystemSingBoxLocator
    private var resolvedRuntimeBinary: ResolvedCoreBinary?

    var onLog: ((String) -> Void)?
    var onTermination: ((Int32) -> Void)?
    var preferredCoreSource: CoreSourcePreference

    var detectedBinaryPath: String? {
        try? self.resolveConfiguredBinary().path
    }

    var detectedBinaryKind: CoreBinaryKind? {
        try? self.resolveConfiguredBinary().kind
    }

    var systemSingBoxAvailability: SystemSingBoxAvailability {
        self.systemSingBoxLocator.availability(fileManager: self.fileManager)
    }

    func resolvedBinaryInfo(configPath: String? = nil) -> (path: String, kind: CoreBinaryKind)? {
        guard let resolved = try? self.resolveConfiguredBinary(configPath: configPath) else {
            return nil
        }
        return (resolved.path, resolved.kind)
    }

    var isRunning: Bool {
        self.lock.withLock {
            self.process?.isRunning == true
        }
    }

    init(
        workingDirectoryManager: WorkingDirectoryManager = WorkingDirectoryManager(),
        fileManager: FileManager = .default,
        preferredCoreSource: CoreSourcePreference = .appManaged,
        systemSingBoxLocator: SystemSingBoxLocator = SystemSingBoxLocator(),
        configValidationTimeout: TimeInterval = 10,
        lifecycleQueue: DispatchQueue? = nil,
        validationQueue: DispatchQueue? = nil)
    {
        self.workingDirectoryManager = workingDirectoryManager
        self.fileManager = fileManager
        self.preferredCoreSource = preferredCoreSource
        self.systemSingBoxLocator = systemSingBoxLocator
        self.configValidationTimeout = configValidationTimeout
        self.lifecycleQueue = lifecycleQueue
            ?? DispatchQueue(label: "com.clashbar.mihomo-process.operations", qos: .userInitiated)
        self.validationQueue = validationQueue
            ?? DispatchQueue(label: "com.clashbar.mihomo-process.validation", qos: .userInitiated)
    }

    deinit {
        stop()
    }

    func validateConfig(configPath: String) throws {
        let resolvedBinary = try self.resolveConfiguredBinary(configPath: configPath)

        let configFileURL = URL(fileURLWithPath: configPath).standardizedFileURL.resolvingSymlinksInPath()
        let configDirectoryURL = configFileURL.deletingLastPathComponent()
        let workingDirectoryURL: URL = if configDirectoryURL.lastPathComponent == "config" {
            configDirectoryURL.deletingLastPathComponent()
        } else {
            configDirectoryURL
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: resolvedBinary.path)
        proc.currentDirectoryURL = workingDirectoryURL
        proc.arguments = self.validationArguments(
            for: resolvedBinary,
            configPath: configPath,
            workingDirectoryURL: workingDirectoryURL)

        let outputPipe = Pipe()
        proc.standardOutput = outputPipe
        proc.standardError = outputPipe
        let outputBox = ProcessOutputBox()
        let outputDrainGroup = DispatchGroup()
        outputDrainGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            outputBox.store(outputData)
            outputDrainGroup.leave()
        }

        do {
            try proc.run()
        } catch {
            throw CoreConfigValidationError.launchFailed(
                "Failed to run \(resolvedBinary.validationCommandDescription): \(error.localizedDescription)")
        }

        let didExit = self.waitForProcessExit(proc, timeout: self.configValidationTimeout)
        if !didExit {
            self
                .onLog?(
                    "[\(resolvedBinary.logLabel) config test] timeout after \(self.normalizedValidationTimeoutSeconds())s")
            proc.terminate()
            if !self.waitForProcessExit(proc, timeout: 1.0) {
                _ = Darwin.kill(proc.processIdentifier, SIGKILL)
                _ = self.waitForProcessExit(proc, timeout: 0.5)
            }
        }

        _ = outputDrainGroup.wait(timeout: .now() + 1.0)
        let outputData = outputBox.load()
        let outputText = String(data: outputData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard didExit else {
            throw CoreConfigValidationError.timedOut(
                commandDescription: resolvedBinary.validationCommandDescription,
                seconds: self.normalizedValidationTimeoutSeconds(),
                details: outputText)
        }

        guard proc.terminationStatus == 0 else {
            throw CoreConfigValidationError.failed(
                commandDescription: resolvedBinary.validationCommandDescription,
                exitCode: proc.terminationStatus,
                details: outputText)
        }

        if !outputText.isEmpty {
            self.onLog?("[\(resolvedBinary.logLabel) config test] \(outputText)")
        }
    }

    func validateConfigAsync(configPath: String) async throws {
        try await self.runBlockingOperation(on: self.validationQueue) {
            try self.validateConfig(configPath: configPath)
        }
    }

    @discardableResult
    func start(configPath: String, controller: String) throws -> CoreLifecycleStatus {
        if let runningPid = lock.withLock({ process?.isRunning == true ? process?.processIdentifier : nil }) {
            return .running(pid: runningPid)
        }

        self.lock.withLock {
            self.intentionalStop = false
            self.status = .starting
        }
        Task {
            await self.stateActor.setIntentionalStop(false)
            await self.stateActor.setStatus(.starting)
        }

        let resolvedBinary = try self.resolveConfiguredBinary(configPath: configPath)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: resolvedBinary.path)

        let configFileURL = URL(fileURLWithPath: configPath).standardizedFileURL.resolvingSymlinksInPath()
        let configDirectoryURL = configFileURL.deletingLastPathComponent()
        let workingDirectoryURL: URL = if configDirectoryURL.lastPathComponent == "config" {
            configDirectoryURL.deletingLastPathComponent()
        } else {
            configDirectoryURL
        }
        proc.currentDirectoryURL = workingDirectoryURL

        let args = self.launchArguments(
            for: resolvedBinary,
            configPath: configPath,
            controller: controller,
            workingDirectoryURL: workingDirectoryURL)
        proc.arguments = args

        let stdout = Pipe()
        let stderr = Pipe()
        proc.standardOutput = stdout
        proc.standardError = stderr
        self.stdoutHandle = stdout.fileHandleForReading
        self.stderrHandle = stderr.fileHandleForReading

        self.wireLogPipe(stdout.fileHandleForReading)
        self.wireLogPipe(stderr.fileHandleForReading)

        proc.terminationHandler = { [weak self] terminatedProcess in
            guard let self else { return }
            let code = terminatedProcess.terminationStatus
            self.handleProcessTermination(terminatedProcess, code: code)
        }

        do {
            try proc.run()
            self.lock.withLock {
                self.process = proc
                self.status = .running(pid: proc.processIdentifier)
                self.resolvedRuntimeBinary = resolvedBinary
            }
            Task {
                await self.stateActor.setStatus(.running(pid: proc.processIdentifier))
            }
            let startMessage =
                "[\(resolvedBinary.logLabel) started] pid=\(proc.processIdentifier) " +
                "controller=\(controller) " +
                "binary=\(resolvedBinary.path) " +
                "workdir=\(workingDirectoryURL.path)"
            self.onLog?(startMessage)
            return self.status
        } catch {
            let reason = "Failed to launch \(resolvedBinary.launchDescription): \(error.localizedDescription)"
            self.lock.withLock {
                self.status = .failed(reason: reason)
                self.intentionalStop = false
                self.resolvedRuntimeBinary = nil
                self.releasePipeHandlesLocked()
            }
            Task {
                await self.stateActor.setIntentionalStop(false)
                await self.stateActor.setStatus(.failed(reason: reason))
            }
            self.onLog?("[\(resolvedBinary.logLabel) error] \(reason)")
            throw error
        }
    }

    @discardableResult
    func startAsync(configPath: String, controller: String) async throws -> CoreLifecycleStatus {
        try await self.runBlockingOperation(on: self.lifecycleQueue) {
            try self.start(configPath: configPath, controller: controller)
        }
    }

    func stop() {
        let runningState = self.lock.withLock { () -> (process: Process?, label: String) in
            self.intentionalStop = true
            return (self.process, self.resolvedRuntimeBinary?.logLabel ?? "core")
        }
        Task {
            await self.stateActor.setIntentionalStop(true)
        }

        let running = runningState.process
        guard let running else {
            self.lock.withLock {
                self.status = .stopped
                self.intentionalStop = false
                self.resolvedRuntimeBinary = nil
                self.releasePipeHandlesLocked()
            }
            Task {
                await self.stateActor.setIntentionalStop(false)
                await self.stateActor.setStatus(.stopped)
            }
            return
        }

        guard running.isRunning else {
            self.handleProcessTermination(running, code: running.terminationStatus)
            return
        }

        self.onLog?("[\(runningState.label) stop] terminate signal sent pid=\(running.processIdentifier)")
        running.terminate()

        if self.waitForProcessExit(running, timeout: 2.0) {
            self.handleProcessTermination(running, code: running.terminationStatus)
            return
        }

        self.onLog?("[\(runningState.label) stop] force kill pid=\(running.processIdentifier)")
        _ = Darwin.kill(running.processIdentifier, SIGKILL)
        _ = self.waitForProcessExit(running, timeout: 1.0)
        self.handleProcessTermination(running, code: running.terminationStatus)
    }

    func stopAsync() async {
        await self.runBlockingOperation(on: self.lifecycleQueue) {
            self.stop()
        }
    }

    @discardableResult
    func restart(configPath: String, controller: String) throws -> CoreLifecycleStatus {
        self.stop()
        return try self.start(configPath: configPath, controller: controller)
    }

    @discardableResult
    func restartAsync(configPath: String, controller: String) async throws -> CoreLifecycleStatus {
        try await self.runBlockingOperation(on: self.lifecycleQueue) {
            try self.restart(configPath: configPath, controller: controller)
        }
    }

    private func handleProcessTermination(_ terminatedProcess: Process, code: Int32) {
        let outcome = self.lock.withLock { () -> (handled: Bool, intentional: Bool, label: String) in
            guard let current = process, current === terminatedProcess else {
                return (false, false, "core")
            }

            let intentional = self.intentionalStop
            let label = self.resolvedRuntimeBinary?.logLabel ?? "core"
            self.intentionalStop = false
            self.process = nil
            self.resolvedRuntimeBinary = nil
            self.status = .stopped
            self.releasePipeHandlesLocked()
            return (true, intentional, label)
        }

        guard outcome.handled else { return }
        Task {
            await self.stateActor.setIntentionalStop(false)
            await self.stateActor.setStatus(.stopped)
        }

        if outcome.intentional {
            self.onLog?("[\(outcome.label) stopped] exit=\(code)")
        } else {
            self.onLog?("[\(outcome.label) terminated] exit=\(code)")
            self.onTermination?(code)
        }
    }

    private func waitForProcessExit(_ process: Process, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            usleep(50000)
        }
        return !process.isRunning
    }

    private func runBlockingOperation<Value: Sendable>(
        on queue: DispatchQueue,
        _ operation: @escaping @Sendable () throws -> Value) async throws -> Value
    {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try continuation.resume(returning: operation())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func runBlockingOperation(
        on queue: DispatchQueue,
        _ operation: @escaping @Sendable () -> Void) async
    {
        await withCheckedContinuation { continuation in
            queue.async {
                operation()
                continuation.resume()
            }
        }
    }

    private func normalizedValidationTimeoutSeconds() -> Int {
        max(1, Int(self.configValidationTimeout.rounded(.awayFromZero)))
    }

    private func validationArguments(
        for resolvedBinary: ResolvedCoreBinary,
        configPath: String,
        workingDirectoryURL: URL) -> [String]
    {
        switch resolvedBinary.kind {
        case .mihomo:
            // `-d` pins mihomo runtime home directory to the managed working root.
            ["-d", workingDirectoryURL.path, "-f", configPath, "-t"]
        case .singBox:
            ["check", "-D", workingDirectoryURL.path, "-c", configPath]
        }
    }

    private func launchArguments(
        for resolvedBinary: ResolvedCoreBinary,
        configPath: String,
        controller: String,
        workingDirectoryURL: URL) -> [String]
    {
        switch resolvedBinary.kind {
        case .mihomo:
            // `-d` pins mihomo runtime home directory to ClashBar working root.
            // This prevents fallback to ~/.config/mihomo for provider/cache updates.
            ["-d", workingDirectoryURL.path, "-f", configPath, "-ext-ctl", controller]
        case .singBox:
            ["run", "-D", workingDirectoryURL.path, "-c", configPath]
        }
    }

    private func resolveConfiguredBinary(configPath: String? = nil) throws -> ResolvedCoreBinary {
        let resolved: ResolvedCoreBinary = switch self.preferredCoreSource {
        case .appManaged:
            try self.resolveAppManagedBinary(configPath: configPath)
        case .systemSingBox:
            try self.resolveSystemSingBoxBinary()
        }

        if let configPath, resolved.kind == .singBox {
            let fileExtension = URL(fileURLWithPath: configPath).pathExtension.lowercased()
            guard fileExtension == "json" else {
                throw CoreConfigCompatibilityError.singBoxRequiresJSONConfig(path: configPath)
            }
        }

        return resolved
    }

    private func resolveAppManagedBinary(configPath: String?) throws -> ResolvedCoreBinary {
        try self.workingDirectoryManager.bootstrapDirectories(fileManager: self.fileManager)

        for kind in self.preferredAppManagedKinds(for: configPath) {
            if let path = try self.resolveManagedBinary(kind: kind) {
                return ResolvedCoreBinary(kind: kind, source: .appManaged, path: path)
            }
        }

        throw CoreBinaryResolutionError.appManagedBinaryNotFound(
            expectedDirectory: self.workingDirectoryManager.coreDirectoryURL.path)
    }

    private func resolveSystemSingBoxBinary() throws -> ResolvedCoreBinary {
        switch self.systemSingBoxAvailability {
        case let .available(path, _):
            try self.validateBinarySecurity(at: path)
            return ResolvedCoreBinary(kind: .singBox, source: .systemSingBox, path: path)
        case let .incompatible(path):
            throw CoreBinaryResolutionError.systemSingBoxMissingClashAPI(path: path)
        case .unavailable:
            throw CoreBinaryResolutionError.systemSingBoxNotFound
        }
    }

    private func preferredAppManagedKinds(for configPath: String?) -> [CoreBinaryKind] {
        let fileExtension = configPath.map { URL(fileURLWithPath: $0).pathExtension.lowercased() }

        switch fileExtension {
        case "json":
            return [CoreBinaryKind.singBox]
        case "yaml", "yml":
            return [CoreBinaryKind.mihomo]
        default:
            return [CoreBinaryKind.singBox, CoreBinaryKind.mihomo]
        }
    }

    private func resolveManagedBinary(kind: CoreBinaryKind) throws -> String? {
        let binaryName = self.binaryName(for: kind)
        let managedBinaryPath = self.managedBinaryURL(for: kind).path

        if self.fileManager.fileExists(atPath: managedBinaryPath) {
            try self.ensureExecutableIfNeeded(at: managedBinaryPath)
            if self.fileManager.isExecutableFile(atPath: managedBinaryPath) {
                try self.validateBinarySecurity(at: managedBinaryPath)
                return managedBinaryPath
            }
        }

        if let bundledBinaryPath = self.firstBundledExecutableBinaryPath(named: binaryName) {
            try self.validateBinarySecurity(at: bundledBinaryPath)
            let migratedBinaryPath = try self.copyBundledBinaryToManagedCore(
                bundledPath: bundledBinaryPath,
                managedPath: managedBinaryPath,
                binaryName: binaryName)
            try self.validateBinarySecurity(at: migratedBinaryPath)
            return migratedBinaryPath
        }

        if let bundledCompressedBinaryPath = self.firstBundledCompressedBinaryPath(named: binaryName) {
            try self.validateBinarySecurity(at: bundledCompressedBinaryPath)
            let migratedBinaryPath = try self.decompressBundledBinaryToManagedCore(
                compressedPath: bundledCompressedBinaryPath,
                managedPath: managedBinaryPath,
                binaryName: binaryName)
            try self.validateBinarySecurity(at: migratedBinaryPath)
            return migratedBinaryPath
        }

        return nil
    }

    private func binaryName(for kind: CoreBinaryKind) -> String {
        switch kind {
        case .mihomo:
            "mihomo"
        case .singBox:
            "sing-box"
        }
    }

    private func managedBinaryURL(for kind: CoreBinaryKind) -> URL {
        switch kind {
        case .mihomo:
            self.workingDirectoryManager.managedMihomoBinaryURL
        case .singBox:
            self.workingDirectoryManager.managedSingBoxBinaryURL
        }
    }

    private func firstBundledExecutableBinaryPath(named binaryName: String) -> String? {
        for candidate in self.bundledBinaryCandidates(named: binaryName)
            where self.fileManager.isExecutableFile(atPath: candidate)
        {
            return candidate
        }
        return nil
    }

    private func firstBundledCompressedBinaryPath(named binaryName: String) -> String? {
        for candidate in self.bundledCompressedBinaryCandidates(named: binaryName)
            where self.fileManager.fileExists(atPath: candidate)
        {
            return candidate
        }
        return nil
    }

    private func bundledBinaryCandidates(named binaryName: String) -> [String] {
        let resourceRoots = AppResourceBundleLocator.candidateResourceRoots()
        var candidates: [String] = []

        for root in resourceRoots {
            candidates.append(root.appendingPathComponent("bin/\(binaryName)").path)
            candidates.append(root.appendingPathComponent("Resources/bin/\(binaryName)").path)
            candidates.append(root.appendingPathComponent(binaryName).path)
        }

        return self.deduplicatedPaths(candidates)
    }

    private func bundledCompressedBinaryCandidates(named binaryName: String) -> [String] {
        let resourceRoots = AppResourceBundleLocator.candidateResourceRoots()
        var candidates: [String] = []

        for root in resourceRoots {
            candidates.append(root.appendingPathComponent("bin/\(binaryName).gz").path)
            candidates.append(root.appendingPathComponent("Resources/bin/\(binaryName).gz").path)
            candidates.append(root.appendingPathComponent("\(binaryName).gz").path)
        }

        return self.deduplicatedPaths(candidates)
    }

    private func deduplicatedPaths(_ candidates: [String]) -> [String] {
        var deduplicated: [String] = []
        var seen = Set<String>()
        for path in candidates {
            let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
            if seen.insert(normalized).inserted {
                deduplicated.append(normalized)
            }
        }
        return deduplicated
    }

    private func copyBundledBinaryToManagedCore(
        bundledPath: String,
        managedPath: String,
        binaryName: String) throws -> String
    {
        if self.fileManager.fileExists(atPath: managedPath) {
            try self.fileManager.removeItem(atPath: managedPath)
        }

        // Keep signed app bundle immutable: only copy core out to user-managed directory.
        do {
            try self.fileManager.copyItem(atPath: bundledPath, toPath: managedPath)
            self.onLog?("[\(binaryName) binary] copied bundled core to \(managedPath)")
            try self.ensureExecutableIfNeeded(at: managedPath)
            return managedPath
        } catch {
            throw NSError(
                domain: "ClashBar.Core",
                code: 500,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "failed to migrate \(binaryName) binary to \(managedPath): \(error.localizedDescription)",
                ])
        }
    }

    private func decompressBundledBinaryToManagedCore(
        compressedPath: String,
        managedPath: String,
        binaryName: String) throws -> String
    {
        let temporaryPath = managedPath + ".tmp"
        if self.fileManager.fileExists(atPath: temporaryPath) {
            try self.fileManager.removeItem(atPath: temporaryPath)
        }
        if self.fileManager.fileExists(atPath: managedPath) {
            try self.fileManager.removeItem(atPath: managedPath)
        }

        self.fileManager.createFile(atPath: temporaryPath, contents: nil)
        let outputURL = URL(fileURLWithPath: temporaryPath)
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        let errorPipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
        process.arguments = ["-c", compressedPath]
        process.standardOutput = outputHandle
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
            try outputHandle.close()

            guard process.terminationStatus == 0 else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorText = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown error"
                try? self.fileManager.removeItem(atPath: temporaryPath)
                throw NSError(
                    domain: "ClashBar.Core",
                    code: 500,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "failed to decompress bundled \(binaryName) binary from \(compressedPath): \(errorText)",
                    ])
            }

            try self.fileManager.moveItem(atPath: temporaryPath, toPath: managedPath)
            self.onLog?("[\(binaryName) binary] decompressed bundled core to \(managedPath)")
            try self.ensureExecutableIfNeeded(at: managedPath)
            return managedPath
        } catch {
            try? outputHandle.close()
            try? self.fileManager.removeItem(atPath: temporaryPath)
            if let error = error as NSError?, error.domain == "ClashBar.Core" {
                throw error
            }
            throw NSError(
                domain: "ClashBar.Core",
                code: 500,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "failed to migrate compressed \(binaryName) binary to \(managedPath): \(error.localizedDescription)",
                ])
        }
    }

    private func ensureExecutableIfNeeded(at path: String) throws {
        guard self.fileManager.fileExists(atPath: path) else {
            throw NSError(
                domain: "ClashBar.Core",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "core binary not found at \(path)"])
        }

        guard !self.fileManager.isExecutableFile(atPath: path) else { return }
        try self.fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
    }

    private func validateBinarySecurity(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])

        if values.isSymbolicLink == true {
            throw NSError(
                domain: "ClashBar.Core",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "core binary path must not be a symbolic link: \(path)"])
        }
        if values.isRegularFile != true {
            throw NSError(
                domain: "ClashBar.Core",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "core binary must be a regular file: \(path)"])
        }

        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        let uid = Int(getuid())
        if let owner = attrs[.ownerAccountID] as? NSNumber {
            let ownerID = owner.intValue
            if ownerID != 0, ownerID != uid {
                throw NSError(
                    domain: "ClashBar.Core",
                    code: 403,
                    userInfo: [NSLocalizedDescriptionKey: "core binary owner must be current user or root: \(path)"])
            }
        }

        if let perm = attrs[.posixPermissions] as? NSNumber {
            let mode = perm.intValue
            // Refuse group-writable or world-writable executables.
            if (mode & 0o022) != 0 {
                throw NSError(
                    domain: "ClashBar.Core",
                    code: 403,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "core binary permissions are too permissive " +
                            "(writable by group/others): \(path)",
                    ])
            }
        }
    }

    private func wireLogPipe(_ handle: FileHandle) {
        handle.readabilityHandler = { [weak self] readable in
            let data = readable.availableData
            if data.isEmpty { return }
            guard let line = String(data: data, encoding: .utf8) else { return }
            self?.onLog?(line.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func releasePipeHandlesLocked() {
        self.stdoutHandle?.readabilityHandler = nil
        self.stderrHandle?.readabilityHandler = nil
        self.stdoutHandle?.closeFile()
        self.stderrHandle?.closeFile()
        self.stdoutHandle = nil
        self.stderrHandle = nil
    }
}

typealias MihomoProcessManager = CoreProcessManager
