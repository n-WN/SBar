import Foundation

enum AppDefaultsMigrator {
    private static let migrationMarkerKey = "sbar.migrations.defaults.v1"

    static func migrateIfNeeded(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: self.migrationMarkerKey) else { return }

        let directMappings: [(legacy: String, current: String)] = [
            ("clashbar.auto.start.core", "sbar.auto.start.core"),
            ("clashbar.auto.core.network.recovery", "sbar.auto.core.network.recovery"),
            ("clashbar.statusbar.display.mode", "sbar.statusbar.display.mode"),
            ("clashbar.proxy.node.hide_unavailable", "sbar.proxy.node.hide_unavailable"),
            ("clashbar.proxy.group.hide_hidden", "sbar.proxy.group.hide_hidden"),
            ("clashbar.config.selected.filename", "sbar.config.selected.filename"),
            ("clashbar.config.remote.sources.v1", "sbar.config.remote.sources.v1"),
            ("clashbar.last.success.config.path", "sbar.last.success.config.path"),
            ("clashbar.settings.editable.snapshot.v1", "sbar.settings.editable.snapshot.v1"),
            ("clashbar.core.source.preference.v1", "sbar.core.source.preference.v1"),
            ("clashbar.ui.language", "sbar.ui.language"),
            ("clashbar.ui.appearance.mode", "sbar.ui.appearance.mode"),
            ("clashbar.core.install.guide.shown.v1", "sbar.core.install.guide.shown.v1"),
        ]

        for (legacyKey, currentKey) in directMappings {
            guard defaults.object(forKey: currentKey) == nil else { continue }
            guard let value = defaults.object(forKey: legacyKey) else { continue }
            defaults.set(value, forKey: currentKey)
        }

        // Older versions stored selected config as a full path.
        let legacyPathKey = "clashbar.config.selected"
        let currentFileNameKey = "sbar.config.selected.filename"
        if defaults.object(forKey: currentFileNameKey) == nil,
           let legacyPath = defaults.string(forKey: legacyPathKey),
           !legacyPath.isEmpty
        {
            defaults.set(URL(fileURLWithPath: legacyPath).lastPathComponent, forKey: currentFileNameKey)
        }

        defaults.set(true, forKey: Self.migrationMarkerKey)
    }
}
