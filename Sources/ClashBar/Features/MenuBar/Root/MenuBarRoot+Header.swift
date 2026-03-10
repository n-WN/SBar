import SwiftUI

extension MenuBarRoot {
    var topHeader: some View {
        VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space6) {
            HStack(alignment: .top, spacing: MenuBarLayoutTokens.space6) {
                HStack(alignment: .center, spacing: MenuBarLayoutTokens.space6) {
                    ZStack {
                        RoundedRectangle(
                            cornerRadius: MenuBarLayoutTokens.cardRadius,
                            style: .continuous)
                            .fill(nativeAccent.opacity(0.12))
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: MenuBarLayoutTokens.cardRadius,
                                    style: .continuous)
                                    .stroke(nativeAccent.opacity(0.22), lineWidth: MenuBarLayoutTokens.stroke)
                            }

                        if let brandImage = BrandIcon.image {
                            Image(nsImage: brandImage)
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "bolt.horizontal.circle.fill")
                                .font(.app(size: MenuBarLayoutTokens.FontSize.hero, weight: .bold))
                                .foregroundStyle(nativeAccent)
                        }
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space2) {
                        Text("SBar")
                            .font(.app(size: MenuBarLayoutTokens.FontSize.title, weight: .bold))
                            .foregroundStyle(nativePrimaryLabel)

                        Text(appState.runtimeStatusText)
                            .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                            .foregroundStyle(nativeSecondaryLabel)
                    }
                }

                Spacer(minLength: MenuBarLayoutTokens.space6)

                HStack(spacing: MenuBarLayoutTokens.space2) {
                    self.headerToolbarButton("arrow.clockwise", label: appState.primaryCoreActionLabel) {
                        await appState.performPrimaryCoreAction()
                    }
                    .disabled(!appState.isPrimaryCoreActionEnabled)
                    .opacity(appState.isPrimaryCoreActionEnabled ? 1 : 0.56)

                    self.headerToolbarButton(
                        appState.isRuntimeRunning ? "stop.fill" : "play.fill",
                        label: appState.isRuntimeRunning ? tr("ui.action.stop") : tr("app.primary.start"),
                        tint: appState.isRuntimeRunning ? nativeWarning : nativePositive)
                    {
                        if appState.isRuntimeRunning {
                            await appState.stopCore()
                        } else {
                            await appState.startCore(trigger: .manual)
                        }
                    }
                    .disabled(appState.isCoreActionProcessing)
                    .opacity(appState.isCoreActionProcessing ? 0.56 : 1)

                    self.headerToolbarButton(
                        "rectangle.portrait.and.arrow.right",
                        label: tr("ui.action.quit"),
                        tint: nativeCritical)
                    {
                        await appState.quitApp()
                    }
                }
            }

            HStack(spacing: MenuBarLayoutTokens.space4) {
                self.headerStatusPill

                self.headerControllerLink(
                    symbol: "link",
                    text: appState.externalControllerDisplay)

                if appState.isExternalControllerWildcardIPv4 {
                    self.headerControllerWarningIcon
                }
            }
        }
        .padding(MenuBarLayoutTokens.sectionInset)
        .background(self.sectionCardBackground(prominent: true))
    }

    func headerMetaLabel(symbol: String, text: String) -> some View {
        HStack(spacing: MenuBarLayoutTokens.space4) {
            Image(systemName: symbol)
                .font(.app(size: MenuBarLayoutTokens.FontSize.micro, weight: .semibold))
                .foregroundStyle(nativeTertiaryLabel)
            Text(text)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.appMono(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
        .foregroundStyle(nativeSecondaryLabel)
        .padding(.horizontal, MenuBarLayoutTokens.space6)
        .padding(.vertical, MenuBarLayoutTokens.space4)
        .background(self.nativeBadgeCapsule())
    }

    @ViewBuilder
    func headerControllerLink(symbol: String, text: String) -> some View {
        if let url = makeMetaCubeXDSetupURL(
            controller: appState.controller,
            secret: appState.controllerSecret)
        {
            Link(destination: url) {
                self.headerMetaLabel(symbol: symbol, text: text)
            }
            .buttonStyle(.plain)
            .help(url.absoluteString)
        } else {
            self.headerMetaLabel(symbol: symbol, text: text)
        }
    }

    var headerStatusPill: some View {
        HStack(spacing: MenuBarLayoutTokens.space4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(runtimeBadgeText)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                .foregroundStyle(nativePrimaryLabel)
        }
        .padding(.horizontal, MenuBarLayoutTokens.space6)
        .padding(.vertical, MenuBarLayoutTokens.space4)
        .background(self.softTintBackground(statusColor, intensity: 1.2))
    }

    var headerControllerWarningIcon: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
            .foregroundStyle(nativeWarning)
            .padding(.horizontal, MenuBarLayoutTokens.space6)
            .padding(.vertical, MenuBarLayoutTokens.space4)
            .background(self.softTintBackground(nativeWarning))
            .help("external-controller is 0.0.0.0 and can be accessed from your LAN.")
            .accessibilityLabel("Warning: external-controller is bound to 0.0.0.0")
    }

    func headerToolbarButton(
        _ symbol: String,
        label: String,
        tint: Color? = nil,
        action: @escaping () async -> Void) -> some View
    {
        self.compactAsyncIconButton(
            symbol: symbol,
            label: label,
            tint: (tint ?? nativeInfo).opacity(MenuBarLayoutTokens.Opacity.solid),
            role: nil,
            isLoading: false,
            size: 28,
            fontSize: MenuBarLayoutTokens.FontSize.caption,
            hierarchicalSymbol: true,
            action: action)
    }

    func makeMetaCubeXDSetupURL(controller: String, secret: String?) -> URL? {
        guard let endpoint = parseControllerEndpoint(controller) else { return nil }

        var query = URLComponents()
        var items: [URLQueryItem] = [
            URLQueryItem(name: "hostname", value: endpoint.host),
            URLQueryItem(name: "port", value: "\(endpoint.port)"),
            URLQueryItem(name: "http", value: endpoint.useHTTP ? "true" : "false"),
        ]
        if let trimmedSecret = secret.trimmedNonEmpty {
            items.append(URLQueryItem(name: "secret", value: trimmedSecret))
        }
        query.queryItems = items

        guard let encodedQuery = query.percentEncodedQuery else { return nil }
        return URL(string: "https://metacubexd.pages.dev/#/setup?\(encodedQuery)")
    }

    func parseControllerEndpoint(_ raw: String) -> (host: String, port: Int, useHTTP: Bool)? {
        let trimmed = raw.trimmed
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        guard let components = URLComponents(string: normalized),
              let host = components.host,
              !host.isEmpty
        else {
            return nil
        }

        let scheme = components.scheme?.lowercased() ?? "http"
        let useHTTP = scheme != "https"
        let fallbackPort = useHTTP ? 80 : 443
        return (host: host, port: components.port ?? fallbackPort, useHTTP: useHTTP)
    }

    func compactTopIcon(
        _ symbol: String,
        label: String,
        role: ButtonRole? = nil,
        warning: Bool = false,
        toneOverride: Color? = nil,
        isLoading: Bool = false,
        action: @escaping () async -> Void) -> some View
    {
        let tone: Color = if let toneOverride {
            toneOverride
        } else if warning {
            nativeCritical
        } else if symbol.contains("arrow.clockwise") {
            nativeInfo
        } else if symbol.contains("stop") {
            nativeWarning
        } else {
            nativeSecondaryLabel
        }

        return self.compactAsyncIconButton(
            symbol: symbol,
            label: label,
            tint: tone.opacity(MenuBarLayoutTokens.Opacity.solid),
            role: role,
            isLoading: isLoading,
            action: action)
    }
}
