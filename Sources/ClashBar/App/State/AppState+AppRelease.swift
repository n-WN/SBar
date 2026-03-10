import Foundation

@MainActor
extension AppState {
    var currentAppVersionText: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let short, !short.isEmpty { return short }
        if let build, !build.isEmpty { return build }
        return "0.0.1"
    }

    var availableAppUpdate: AppReleaseInfo? {
        guard let latestAppReleaseInfo else { return nil }
        guard !latestAppReleaseInfo.isDraft, !latestAppReleaseInfo.isPrerelease else { return nil }
        guard AppSemanticVersion.isNewerRelease(
            tagName: latestAppReleaseInfo.tagName,
            than: self.currentAppVersionText)
        else {
            return nil
        }
        return latestAppReleaseInfo
    }

    var appReleaseIndexURL: URL? {
        URL(string: "https://github.com/n-WN/SBar/releases")
    }

    func refreshLatestAppReleaseIfNeeded(force: Bool = false) async {
        guard force || self.shouldRefreshLatestAppRelease else { return }
        guard !self.isLatestAppReleaseCheckInFlight else { return }

        self.isLatestAppReleaseCheckInFlight = true
        var didFinishCheck = false
        defer {
            self.isLatestAppReleaseCheckInFlight = false
            if didFinishCheck {
                self.lastLatestAppReleaseCheckAt = Date()
            }
        }

        do {
            let release = try await AppReleaseService.fetchLatestRelease(currentVersion: self.currentAppVersionText)
            guard !Task.isCancelled else { return }
            didFinishCheck = true
            guard self.latestAppReleaseInfo != release else { return }
            self.latestAppReleaseInfo = release
        } catch {
            guard !Task.isCancelled else { return }
            didFinishCheck = true
        }
    }

    private var shouldRefreshLatestAppRelease: Bool {
        guard let lastLatestAppReleaseCheckAt else { return true }
        let refreshInterval = self.latestAppReleaseInfo == nil
            ? self.latestAppReleaseRetryInterval
            : self.latestAppReleaseRefreshInterval
        return Date().timeIntervalSince(lastLatestAppReleaseCheckAt) >= refreshInterval
    }
}
