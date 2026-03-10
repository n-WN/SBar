import AppKit
import Foundation

@MainActor
extension AppState {
    func hasInstalledManagedCore() -> Bool {
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: workingDirectoryManager.managedMihomoBinaryURL.path) ||
            fileManager.fileExists(atPath: workingDirectoryManager.managedSingBoxBinaryURL.path)
    }

    func shouldDeferAutoStartForMissingManagedCore() -> Bool {
        guard self.coreSourcePreference == .appManaged else { return false }
        return !bundlesManagedCore && !self.hasInstalledManagedCore()
    }

    func autoSelectAvailableCoreSourceIfNeeded() {
        self.refreshCoreBinaryState()

        guard self.coreSourcePreference == .appManaged else { return }
        guard !self.hasInstalledManagedCore() else { return }
        guard self.isSystemSingBoxAvailable else { return }

        self.coreSourcePreference = .systemSingBox
        self.defaults.set(CoreSourcePreference.systemSingBox.rawValue, forKey: self.coreSourcePreferenceKey)
        self.alignSelectedConfigWithCurrentCoreIfNeeded()
        self.refreshCoreBinaryState()
    }

    func refreshCoreBinaryState() {
        guard let managedProcess = self.processManager as? CoreProcessManager else {
            self.coreBinaryPath = self.processManager.detectedBinaryPath ?? "-"
            return
        }

        managedProcess.preferredCoreSource = self.coreSourcePreference

        switch managedProcess.systemSingBoxAvailability {
        case let .available(path, version):
            self.isSystemSingBoxAvailable = true
            self.systemSingBoxPath = path
            self.systemSingBoxVersion = version ?? "-"
        case let .incompatible(path):
            self.isSystemSingBoxAvailable = false
            self.systemSingBoxPath = path
            self.systemSingBoxVersion = "-"
        case .unavailable:
            self.isSystemSingBoxAvailable = false
            self.systemSingBoxPath = "-"
            self.systemSingBoxVersion = "-"
        }

        let selectedConfigPath = self.configManager.selectedConfig?.path
        if let resolved = managedProcess.resolvedBinaryInfo(configPath: selectedConfigPath) {
            self.coreBinaryKind = resolved.kind
            self.coreBinaryPath = resolved.path
            return
        }

        self.coreBinaryKind = self.fallbackCoreBinaryKind(for: selectedConfigPath)
        self.coreBinaryPath = self.coreSourcePreference == .systemSingBox ? self.systemSingBoxPath : "-"
    }

    func setCoreSourcePreference(_ preference: CoreSourcePreference) async {
        guard self.coreSourcePreference != preference else { return }

        self.refreshCoreBinaryState()
        if preference == .systemSingBox, !self.isSystemSingBoxAvailable {
            return
        }

        self.coreSourcePreference = preference
        self.defaults.set(preference.rawValue, forKey: self.coreSourcePreferenceKey)
        self.alignSelectedConfigWithCurrentCoreIfNeeded()
        self.refreshCoreBinaryState()

        if !self.supportsTunRuntimeManagement, self.isTunEnabled {
            self.isTunEnabled = false
            self.persistEditableSettingsSnapshot()
        }

        guard self.isRuntimeRunning else { return }
        await self.restartCore()
    }

    func alignSelectedConfigWithCurrentCoreIfNeeded() {
        guard self.coreSourcePreference == .systemSingBox else { return }

        if let selected = self.configManager.selectedConfig,
           selected.pathExtension.lowercased() == "json"
        {
            return
        }

        guard let jsonConfig = self.preferredJSONConfigForSingBox() else {
            return
        }

        self.configManager.selectConfig(jsonConfig)
        _ = self.syncSelectedConfigSelection(jsonConfig)
        self.syncConfigDisplayState()
    }

    private func preferredJSONConfigForSingBox() -> URL? {
        let jsonConfigs = self.configManager.availableConfigs.filter {
            $0.pathExtension.lowercased() == "json"
        }
        guard !jsonConfigs.isEmpty else { return nil }

        if let selected = self.configManager.selectedConfig,
           selected.pathExtension.lowercased() == "json",
           jsonConfigs.contains(selected)
        {
            return selected
        }

        let nonTemplateConfigs = jsonConfigs.filter {
            $0.lastPathComponent.caseInsensitiveCompare("SBar.json") != .orderedSame
        }
        let candidates = nonTemplateConfigs.isEmpty ? jsonConfigs : nonTemplateConfigs

        return candidates.max { lhs, rhs in
            self.configModificationDate(for: lhs) < self.configModificationDate(for: rhs)
        } ?? candidates.first
    }

    private func configModificationDate(for url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private func fallbackCoreBinaryKind(for configPath: String?) -> CoreBinaryKind {
        if self.coreSourcePreference == .systemSingBox {
            return CoreBinaryKind.singBox
        }

        let fileExtension = configPath.map { URL(fileURLWithPath: $0).pathExtension.lowercased() }
        switch fileExtension {
        case "json":
            return CoreBinaryKind.singBox
        default:
            return CoreBinaryKind.mihomo
        }
    }

    func coreErrorMessage(_ error: Error) -> String {
        if let binaryResolutionError = error as? CoreBinaryResolutionError {
            switch binaryResolutionError {
            case let .appManagedBinaryNotFound(expectedDirectory):
                return tr("app.core.error.binary_not_found", expectedDirectory)
            case .systemSingBoxNotFound:
                return tr("app.core.error.system_sing_box_not_found")
            case let .systemSingBoxMissingClashAPI(path):
                return tr("app.core.error.system_sing_box_missing_clash_api", path)
            }
        }

        if let compatibilityError = error as? CoreConfigCompatibilityError {
            switch compatibilityError {
            case let .singBoxRequiresJSONConfig(path):
                return tr("app.core.error.system_sing_box_requires_json", path)
            }
        }

        return error.localizedDescription
    }

    func presentInitialNoCoreSetupGuideIfNeeded() {
        guard self.shouldPresentInitialNoCoreSetupGuide() else { return }
        guard !didPresentInitialNoCoreSetupGuide else { return }

        didPresentInitialNoCoreSetupGuide = true
        defaults.set(true, forKey: initialNoCoreSetupGuideShownKey)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = tr("app.core.setup_required.title")
        alert.informativeText = tr("app.core.setup_required.message", workingDirectoryManager.coreDirectoryURL.path)
        alert.addButton(withTitle: tr("ui.action.open_core_directory"))
        alert.addButton(withTitle: tr("ui.action.ok"))
        self.prepareModalWindowPresentation()
        self.configureModalWindow(alert.window)

        if alert.runModal() == .alertFirstButtonReturn {
            self.showCoreDirectoryInFinder()
        }
    }

    func shouldPresentInitialNoCoreSetupGuide() -> Bool {
        guard self.coreSourcePreference == .appManaged else { return false }
        guard !self.isSystemSingBoxAvailable else { return false }
        guard self.shouldDeferAutoStartForMissingManagedCore() else { return false }
        if defaults.bool(forKey: legacyInitialNoCoreSetupGuideShownKey),
           !defaults.bool(forKey: initialNoCoreSetupGuideShownKey)
        {
            defaults.set(true, forKey: initialNoCoreSetupGuideShownKey)
            defaults.removeObject(forKey: legacyInitialNoCoreSetupGuideShownKey)
        }
        guard !defaults.bool(forKey: initialNoCoreSetupGuideShownKey) else { return false }
        return true
    }
}
