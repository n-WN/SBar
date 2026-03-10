import Foundation

@MainActor
extension AppState {
    func resolveSelectedConfigPath() async -> String? {
        self.autoSelectAvailableCoreSourceIfNeeded()

        if let selected = configManager.selectedConfig {
            let selectedPath = self.syncSelectedConfigSelection(selected)
            self.syncConfigDisplayState()
            return selectedPath
        }

        if let selectedName = defaults.string(forKey: selectedConfigKey) ??
            defaults.string(forKey: legacySelectedConfigFilenameKey),
            let selected = configManager.availableConfigs.first(where: { $0.lastPathComponent == selectedName })
        {
            if defaults.object(forKey: selectedConfigKey) == nil {
                defaults.set(selectedName, forKey: selectedConfigKey)
                defaults.removeObject(forKey: legacySelectedConfigFilenameKey)
            }

            configManager.selectConfig(selected)
            let selectedPath = self.syncSelectedConfigSelection(selected)
            self.syncConfigDisplayState()
            return selectedPath
        }

        if let legacySelectedPath = defaults.string(forKey: legacySelectedConfigKey) {
            let legacyName = URL(fileURLWithPath: legacySelectedPath).lastPathComponent
            defaults.set(legacyName, forKey: selectedConfigKey)
            defaults.removeObject(forKey: legacySelectedConfigKey)
            if let selected = configManager.availableConfigs.first(where: { $0.lastPathComponent == legacyName }) {
                configManager.selectConfig(selected)
                let selectedPath = self.syncSelectedConfigSelection(selected)
                self.syncConfigDisplayState()
                return selectedPath
            }
        }

        _ = configManager.reloadConfigs()
        if let selected = configManager.selectedConfig {
            let selectedPath = self.syncSelectedConfigSelection(selected)
            self.syncConfigDisplayState()
            return selectedPath
        }

        return nil
    }

    func restoreSavedConfigDirectory() {
        configManager.setConfigDirectory(workingDirectoryManager.configDirectoryURL)
        if let selected = configManager.selectedConfig {
            _ = self.syncSelectedConfigSelection(selected)
        }
        self.syncConfigDisplayState()
    }

    func restoreLastSuccessfulConfigIfAvailable() {
        let lastPath = defaults.string(forKey: lastSuccessfulConfigPathKey) ??
            defaults.string(forKey: legacyLastSuccessfulConfigPathKey)
        guard let lastPath, !lastPath.isEmpty else { return }
        if defaults.object(forKey: lastSuccessfulConfigPathKey) == nil {
            defaults.set(lastPath, forKey: lastSuccessfulConfigPathKey)
            defaults.removeObject(forKey: legacyLastSuccessfulConfigPathKey)
        }
        let candidate = URL(fileURLWithPath: lastPath)
        guard FileManager.default.fileExists(atPath: candidate.path) else { return }
        guard let matched = configManager.availableConfigs.first(where: {
            $0.standardizedFileURL.resolvingSymlinksInPath().path == candidate.standardizedFileURL
                .resolvingSymlinksInPath().path
        }) else {
            return
        }
        configManager.selectConfig(matched)
        _ = self.syncSelectedConfigSelection(matched)
        self.syncConfigDisplayState()
    }

    func syncConfigDisplayState() {
        configDirectoryPath = configManager.configDirectory?.path ?? "-"
        availableConfigFileNames = configManager.availableConfigs.map(\.lastPathComponent)
        if selectedConfigName == "-", let first = availableConfigFileNames.first {
            selectedConfigName = first
        }
        self.pruneRemoteConfigSourcesIfNeeded()
        self.refreshCoreBinaryState()
    }

    func ensureAPIClient() {
        if let apiClient {
            apiClient.updateCredentials(controller: controller, secret: controllerSecret)
        } else {
            apiClient = CoreAPIClient(controller: controller, secret: controllerSecret)
        }
    }

    func persistEditableSettingsSnapshot() {
        guard !suppressSettingsPersistence else { return }
        let snapshot = currentEditableSettingsSnapshot()
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: editableSettingsSnapshotKey)
    }

    func loadPersistedEditableSettingsSnapshot() -> EditableSettingsSnapshot? {
        if let data = defaults.data(forKey: editableSettingsSnapshotKey) {
            return try? JSONDecoder().decode(EditableSettingsSnapshot.self, from: data)
        }

        guard let legacyData = defaults.data(forKey: legacyEditableSettingsSnapshotKey) else { return nil }
        defaults.set(legacyData, forKey: editableSettingsSnapshotKey)
        defaults.removeObject(forKey: legacyEditableSettingsSnapshotKey)
        return try? JSONDecoder().decode(EditableSettingsSnapshot.self, from: legacyData)
    }

    func loadPersistedUILanguage() -> AppLanguage {
        if let raw = defaults.string(forKey: uiLanguageKey),
           let language = AppLanguage(rawValue: raw)
        {
            return language
        }
        if let raw = defaults.string(forKey: legacyUILanguageKey),
           let language = AppLanguage(rawValue: raw)
        {
            defaults.set(raw, forKey: uiLanguageKey)
            defaults.removeObject(forKey: legacyUILanguageKey)
            return language
        }
        defaults.set(AppLanguage.zhHans.rawValue, forKey: uiLanguageKey)
        return .zhHans
    }

    func loadPersistedAppearanceMode() -> AppAppearanceMode {
        if let raw = defaults.string(forKey: appearanceModeKey),
           let mode = AppAppearanceMode(rawValue: raw)
        {
            return mode
        }
        if let raw = defaults.string(forKey: legacyAppearanceModeKey),
           let mode = AppAppearanceMode(rawValue: raw)
        {
            defaults.set(raw, forKey: appearanceModeKey)
            defaults.removeObject(forKey: legacyAppearanceModeKey)
            return mode
        }
        defaults.set(AppAppearanceMode.system.rawValue, forKey: appearanceModeKey)
        return .system
    }

    func loadPersistedCoreSourcePreference() -> CoreSourcePreference {
        if let raw = defaults.string(forKey: coreSourcePreferenceKey),
           let preference = CoreSourcePreference(rawValue: raw)
        {
            return preference
        }
        if let raw = defaults.string(forKey: legacyCoreSourcePreferenceKey),
           let preference = CoreSourcePreference(rawValue: raw)
        {
            defaults.set(raw, forKey: coreSourcePreferenceKey)
            defaults.removeObject(forKey: legacyCoreSourcePreferenceKey)
            return preference
        }

        defaults.set(CoreSourcePreference.appManaged.rawValue, forKey: coreSourcePreferenceKey)
        return .appManaged
    }

    func loadPersistedRemoteConfigSources() -> [String: String] {
        let stored: [String: String]
        if let current = defaults.dictionary(forKey: remoteConfigSourcesKey) as? [String: String] {
            stored = current
        } else if let legacy = defaults.dictionary(forKey: legacyRemoteConfigSourcesKey) as? [String: String] {
            defaults.set(legacy, forKey: remoteConfigSourcesKey)
            defaults.removeObject(forKey: legacyRemoteConfigSourcesKey)
            stored = legacy
        } else {
            return [:]
        }

        var result: [String: String] = [:]
        for (fileName, urlString) in stored {
            guard let normalizedName = normalizedConfigFileName(fileName), normalizedName == fileName else { continue }
            guard let url = URL(string: urlString), isSupportedRemoteConfigURL(url) else { continue }
            result[normalizedName] = url.absoluteString
        }
        return result
    }

    func persistRemoteConfigSources() {
        defaults.set(remoteConfigSources, forKey: remoteConfigSourcesKey)
    }

    func pruneRemoteConfigSourcesIfNeeded() {
        let availableNames = Set(availableConfigFileNames)
        let filtered = remoteConfigSources.filter { availableNames.contains($0.key) }
        guard filtered != remoteConfigSources else { return }
        remoteConfigSources = filtered
        self.persistRemoteConfigSources()
    }
}
