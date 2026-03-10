import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

struct SeparatedForEach<Element: Equatable, ID: Hashable, RowContent: View>: View {
    private struct Item: Identifiable {
        let id: ID
        let element: Element
        let isLast: Bool
    }

    private let items: [Item]
    private let separator: Color
    private let content: (Element) -> RowContent

    init<Data: RandomAccessCollection>(
        data: Data,
        id idPath: KeyPath<Element, ID>,
        separator: Color,
        @ViewBuilder content: @escaping (Element) -> RowContent) where Data.Element == Element
    {
        let array = Array(data)
        self.items = array.enumerated().map { index, el in
            Item(id: el[keyPath: idPath], element: el, isLast: index == array.count - 1)
        }
        self.separator = separator
        self.content = content
    }

    var body: some View {
        ForEach(self.items) { item in
            self.content(item.element)
            if !item.isLast {
                Rectangle()
                    .fill(self.separator)
                    .frame(height: MenuBarLayoutTokens.stroke)
            }
        }
    }
}

struct MeasurementAwareVStack<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(alignment: HorizontalAlignment = .center, spacing: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        LazyVStack(alignment: self.alignment, spacing: self.spacing) { self.content }
    }
}

extension MenuBarRoot {
    func fractionSummaryBadge(current: Int, total: Int) -> some View {
        HStack(spacing: MenuBarLayoutTokens.space1) {
            Text("\(current)")
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .bold))
            Text("/")
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
            Text("\(total)")
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
        }
        .foregroundStyle(self.nativeSecondaryLabel)
        .padding(.horizontal, MenuBarLayoutTokens.space6)
        .padding(.vertical, MenuBarLayoutTokens.space4)
        .background(self.nativeBadgeCapsule())
    }

    // swiftlint:disable:next function_parameter_count
    func compactSelectionMenu<Option: Hashable & Identifiable>(
        selection: Option,
        options: [Option],
        symbol: String,
        helpText: String,
        optionTitle: @escaping (Option) -> String,
        onSelect: @escaping (Option) -> Void) -> some View
    {
        Menu {
            ForEach(options) { option in
                Button {
                    onSelect(option)
                } label: {
                    if selection == option {
                        Label(optionTitle(option), systemImage: "checkmark")
                    } else {
                        Text(optionTitle(option))
                    }
                }
            }
        } label: {
            Label(optionTitle(selection), systemImage: symbol)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, T.space6)
                .padding(.vertical, T.space4)
                .background(
                    RoundedRectangle(cornerRadius: T.cardRadius, style: .continuous)
                        .fill(self.cardFillColor.opacity(0.92))
                        .overlay {
                            RoundedRectangle(cornerRadius: T.cardRadius, style: .continuous)
                                .stroke(self.cardBorderColor.opacity(0.72), lineWidth: T.stroke)
                        })
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    var isDarkAppearance: Bool {
        self.colorScheme == .dark
    }

    var panelCanvasFill: Color {
        if self.isDarkAppearance {
            return Color(red: 0.10, green: 0.105, blue: 0.125)
        }
        return Color(red: 0.972, green: 0.973, blue: 0.982)
    }

    var panelShellFill: Color {
        if self.isDarkAppearance {
            return Color(red: 0.135, green: 0.14, blue: 0.165)
        }
        return Color(red: 0.952, green: 0.954, blue: 0.966)
    }

    var panelShellBorder: Color {
        if self.isDarkAppearance {
            return Color.white.opacity(0.08)
        }
        return Color.black.opacity(0.07)
    }

    var cardFillColor: Color {
        if self.isDarkAppearance {
            return Color(red: 0.165, green: 0.17, blue: 0.20)
        }
        return Color.white.opacity(0.74)
    }

    var cardProminentFillColor: Color {
        if self.isDarkAppearance {
            return Color(red: 0.185, green: 0.19, blue: 0.225)
        }
        return Color.white.opacity(0.88)
    }

    var cardBorderColor: Color {
        if self.isDarkAppearance {
            return Color.white.opacity(0.08)
        }
        return Color.black.opacity(0.065)
    }

    var elevatedCardBorderColor: Color {
        if self.isDarkAppearance {
            return Color.white.opacity(0.12)
        }
        return Color.black.opacity(0.085)
    }

    var nativeAccent: Color {
        Color(red: 0.47, green: 0.60, blue: 0.94)
    }

    var nativeInfo: Color {
        Color(red: 0.38, green: 0.64, blue: 0.95)
    }

    var nativePositive: Color {
        Color(red: 0.25, green: 0.78, blue: 0.48)
    }

    var nativeWarning: Color {
        Color(red: 0.96, green: 0.65, blue: 0.28)
    }

    var nativeCritical: Color {
        Color(red: 0.94, green: 0.44, blue: 0.46)
    }

    var nativeTeal: Color {
        Color(red: 0.29, green: 0.74, blue: 0.79)
    }

    var nativeIndigo: Color {
        Color(red: 0.53, green: 0.53, blue: 0.93)
    }

    var nativePurple: Color {
        Color(red: 0.74, green: 0.54, blue: 0.94)
    }

    var nativePrimaryLabel: Color {
        if self.isDarkAppearance {
            return Color.white.opacity(0.94)
        }
        return Color.black.opacity(0.82)
    }

    var nativeSecondaryLabel: Color {
        self.nativePrimaryLabel
            .opacity(self.isDarkAppearance ? T.Theme.Dark.labelSecondary : T.Theme.Light.labelSecondary)
    }

    var nativeTertiaryLabel: Color {
        self.nativePrimaryLabel
            .opacity(self.isDarkAppearance ? T.Theme.Dark.labelTertiary : T.Theme.Light.labelTertiary)
    }

    var nativeSeparator: Color {
        self.cardBorderColor
            .opacity(self.isDarkAppearance ? T.Theme.Dark.separator : T.Theme.Light.separator)
    }

    var nativeControlFill: Color {
        self.cardFillColor
            .opacity(self.isDarkAppearance ? T.Theme.Dark.controlFill : T.Theme.Light.controlFill)
    }

    var nativeControlBorder: Color {
        self.cardBorderColor
            .opacity(self.isDarkAppearance ? T.Theme.Dark.controlBorder : T.Theme.Light.controlBorder)
    }

    var nativeHoverFill: Color {
        if self.isDarkAppearance {
            return Color.white.opacity(0.08)
        }
        return Color.black.opacity(0.045)
    }

    var nativeBadgeFill: Color {
        if self.isDarkAppearance {
            return Color.white.opacity(0.09)
        }
        return Color.black.opacity(0.045)
    }

    func nativeHoverRowBackground(
        _ hovered: Bool,
        cornerRadius: CGFloat = MenuBarLayoutTokens.rowRadius) -> some View
    {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(hovered ? self.nativeHoverFill : .clear)
    }

    func nativeBadgeCapsule() -> some View {
        Capsule(style: .continuous)
            .fill(self.nativeBadgeFill)
            .overlay {
                Capsule(style: .continuous)
                    .stroke(self.cardBorderColor.opacity(0.55), lineWidth: T.stroke)
            }
    }

    func softTintBackground(_ tint: Color, intensity: CGFloat = 1) -> some View {
        RoundedRectangle(cornerRadius: T.cardRadius, style: .continuous)
            .fill(tint.opacity(0.08 * intensity))
            .overlay {
                RoundedRectangle(cornerRadius: T.cardRadius, style: .continuous)
                    .stroke(tint.opacity(0.16 * intensity), lineWidth: T.stroke)
            }
    }

    func sectionCardBackground(prominent: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: T.cardRadius, style: .continuous)
            .fill(prominent ? self.cardProminentFillColor : self.nativeControlFill)
            .overlay {
                RoundedRectangle(cornerRadius: T.cardRadius, style: .continuous)
                    .stroke(
                        (prominent ? self.elevatedCardBorderColor : self.nativeControlBorder)
                            .opacity(prominent ? 0.95 : 0.82),
                        lineWidth: T.stroke)
            }
            .shadow(
                color: Color.black.opacity(prominent ? T.Shadow.card.opacity : 0.04),
                radius: prominent ? T.Shadow.card.radius : 6,
                x: 0,
                y: prominent ? T.Shadow.card.y : 2)
    }

    func sectionInnerSurfaceBackground(prominent: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: T.innerCardRadius, style: .continuous)
            .fill(prominent ? self.cardProminentFillColor.opacity(0.86) : self.cardFillColor.opacity(0.9))
            .overlay {
                RoundedRectangle(cornerRadius: T.innerCardRadius, style: .continuous)
                    .stroke(self.cardBorderColor.opacity(prominent ? 0.78 : 0.66), lineWidth: T.stroke)
            }
    }

    func sectionInnerListSurface(
        spacing: CGFloat = 0,
        @ViewBuilder content: () -> some View) -> some View
    {
        VStack(spacing: spacing) {
            content()
        }
        .padding(T.space2)
        .background(self.sectionInnerSurfaceBackground())
    }

    func sectionInnerEmptyState(_ text: String) -> some View {
        Text(text)
            .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .regular))
            .foregroundStyle(self.nativeSecondaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, T.space6)
            .padding(.vertical, T.space6)
            .background(self.sectionInnerSurfaceBackground())
    }

    func emptyCard(_ text: String) -> some View {
        Text(text)
            .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .regular))
            .foregroundStyle(self.nativeSecondaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .menuRowPadding()
            .background(self.sectionCardBackground())
    }

    var footerBar: some View {
        let repositoryURL: URL?
        let iconSystemName: String
        let coreText: String

        switch appState.coreBinaryKind {
        case .mihomo:
            repositoryURL = URL(string: "https://github.com/MetaCubeX/mihomo")
            iconSystemName = "antenna.radiowaves.left.and.right"
            coreText = tr("ui.footer.core_mihomo", appState.version)
        case .singBox:
            repositoryURL = URL(string: "https://github.com/SagerNet/sing-box")
            iconSystemName = "point.3.connected.trianglepath.dotted"
            coreText = tr("ui.footer.core_sing_box", appState.version)
        }

        return VStack(spacing: 0) {
            HStack(spacing: MenuBarLayoutTokens.space6) {
                self.footerInfo(
                    coreText,
                    url: repositoryURL,
                    iconSystemName: iconSystemName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                self.footerVersionInfo
                    .fixedSize(horizontal: true, vertical: false)
            }
            .menuRowPadding(vertical: MenuBarLayoutTokens.space2)
            .background(self.footerSurfaceBackground)
        }
        .task {
            await self.appState.refreshLatestAppReleaseIfNeeded()
        }
    }

    var footerSurfaceBackground: some View {
        RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
            .fill(self.nativeControlFill)
            .overlay {
                RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
                    .stroke(
                        self.nativeControlBorder.opacity(0.82),
                        lineWidth: MenuBarLayoutTokens.stroke)
            }
            .shadow(
                color: Color.black.opacity(T.Shadow.card.opacity),
                radius: T.Shadow.card.radius,
                x: T.Shadow.card.x,
                y: T.Shadow.card.y)
    }

    @ViewBuilder
    func footerInfo(_ text: String, url: URL?, iconSystemName: String? = nil) -> some View {
        if let url {
            Link(destination: url) {
                self.footerInfoLabel(text, iconSystemName: iconSystemName)
            }
            .buttonStyle(.plain)
        } else {
            self.footerInfoLabel(text, iconSystemName: iconSystemName)
        }
    }

    func footerInfoLabel(_ text: String, iconSystemName: String?) -> some View {
        HStack(spacing: MenuBarLayoutTokens.space4) {
            if let iconSystemName {
                Image(systemName: iconSystemName)
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                    .foregroundStyle(self.nativeSecondaryLabel)
            }

            Text(text)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                .foregroundStyle(self.nativeSecondaryLabel)
                .lineLimit(1)
                .truncationMode(.middle)
                .minimumScaleFactor(MenuBarLayoutTokens.minimumScale)
                .allowsTightening(true)
        }
        .help(text)
    }

    @ViewBuilder
    var footerVersionInfo: some View {
        if let update = self.appState.availableAppUpdate {
            Link(destination: update.releaseURL) {
                self.footerVersionUpdateLabel(update)
            }
            .buttonStyle(.plain)
            .help(tr("ui.footer.version_update_help", update.displayVersion))
            .accessibilityLabel(tr(
                "ui.footer.version_update_accessibility",
                self.appState.currentAppVersionText,
                update.displayVersion))
        } else {
            self.footerInfo(
                tr("ui.footer.version", self.appState.currentAppVersionText),
                url: self.appState.appReleaseIndexURL,
                iconSystemName: "chevron.left.forwardslash.chevron.right")
        }
    }

    func footerVersionUpdateLabel(_ release: AppReleaseInfo) -> some View {
        HStack(spacing: MenuBarLayoutTokens.space4) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                .foregroundStyle(self.nativeAccent.opacity(MenuBarLayoutTokens.Opacity.solid))

            Text(tr("ui.footer.version", self.appState.currentAppVersionText))
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                .foregroundStyle(self.nativeSecondaryLabel)
                .lineLimit(1)
                .minimumScaleFactor(MenuBarLayoutTokens.minimumScale)

            Text(release.displayVersion)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .bold))
                .foregroundStyle(self.nativeAccent.opacity(MenuBarLayoutTokens.Opacity.solid))
                .lineLimit(1)
                .padding(.horizontal, MenuBarLayoutTokens.space4)
                .padding(.vertical, MenuBarLayoutTokens.space1)
                .background(
                    Capsule(style: .continuous)
                        .fill(self.nativeAccent.opacity(MenuBarLayoutTokens.Opacity.tint)))
        }
    }

    var statusColor: Color {
        switch appState.runtimeVisualStatus {
        case .runningHealthy: self.nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .runningDegraded: self.nativeWarning.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .starting: self.nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .failed: self.nativeCritical.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .stopped: self.nativeSecondaryLabel
        }
    }

    var runtimeBadgeText: String {
        switch appState.runtimeVisualStatus {
        case .runningHealthy, .runningDegraded:
            tr("ui.header.status.running")
        case .starting:
            tr("ui.header.status.starting")
        case .failed:
            tr("ui.header.status.failed")
        case .stopped:
            tr("ui.header.status.stopped")
        }
    }

    var appVersionText: String {
        self.appState.currentAppVersionText
    }

    func sortedProviderNodes(provider: String, detail: ProviderDetail?) -> [String] {
        guard let proxies = detail?.proxies else { return [] }
        return self.sortedNodes(
            names: proxies.map(\.name),
            latencyForNode: { self.appState.providerNodeLatencies[provider]?[$0] })
    }

    func orderedUniqueNames(_ names: [String]) -> [String] {
        var seen: Set<String> = []
        var ordered: [String] = []
        ordered.reserveCapacity(names.count)

        for name in names where !name.isEmpty {
            if seen.insert(name).inserted {
                ordered.append(name)
            }
        }

        return ordered
    }

    func compareLatency(lhs: Int?, rhs: Int?, ascending: Bool) -> ComparisonResult {
        let leftAvailable = self.isProxyNodeAvailable(lhs)
        let rightAvailable = self.isProxyNodeAvailable(rhs)

        if leftAvailable != rightAvailable {
            return leftAvailable ? .orderedAscending : .orderedDescending
        }

        guard leftAvailable, rightAvailable, let lhs, let rhs, lhs != rhs else {
            return .orderedSame
        }

        if ascending {
            return lhs < rhs ? .orderedAscending : .orderedDescending
        }
        return lhs > rhs ? .orderedAscending : .orderedDescending
    }

    func isProxyNodeAvailable(_ latency: Int?) -> Bool {
        guard let latency else { return false }
        return latency > 0
    }

    func latencyColor(_ value: Int?) -> Color {
        guard let value else {
            return self.nativeTertiaryLabel
        }
        if value == 0 { return self.nativeCritical.opacity(MenuBarLayoutTokens.Opacity.solid) }
        if value <= 400 { return self.nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid) }
        return self.nativeWarning.opacity(MenuBarLayoutTokens.Opacity.solid)
    }

    func sortedGroupNodes(_ group: ProxyGroup) -> [String] {
        self.sortedNodes(
            names: group.all,
            latencyForNode: { self.appState.delayValue(group: group.name, node: $0) })
    }

    private func sortedNodes(names: [String], latencyForNode: (String) -> Int?) -> [String] {
        let unique = self.orderedUniqueNames(names)
        let sorted = unique.sorted { lhs, rhs in
            let cmp = self.compareLatency(lhs: latencyForNode(lhs), rhs: latencyForNode(rhs), ascending: true)
            if cmp != .orderedSame { return cmp == .orderedAscending }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        guard self.appState.hideUnavailableProxyNodes else { return sorted }
        return sorted.filter { self.isProxyNodeAvailable(latencyForNode($0)) }
    }

    func compactAsyncIconButton(
        symbol: String,
        label: String,
        tint: Color,
        baseTint: Color? = nil,
        role: ButtonRole? = nil,
        isLoading: Bool = false,
        size: CGFloat = 20,
        fontSize: CGFloat = MenuBarLayoutTokens.FontSize.body,
        hierarchicalSymbol: Bool = false,
        action: @escaping () async -> Void) -> some View
    {
        CompactAsyncIconButton(
            symbol: symbol,
            tint: tint,
            baseTint: baseTint ?? self.nativeSecondaryLabel,
            role: role,
            isLoading: isLoading,
            size: size,
            fontSize: fontSize,
            hierarchicalSymbol: hierarchicalSymbol,
            action: action)
            .accessibilityLabel(label)
    }
}

private struct CompactAsyncIconButton: View {
    let symbol: String
    let tint: Color
    let baseTint: Color
    let role: ButtonRole?
    let isLoading: Bool
    let size: CGFloat
    let fontSize: CGFloat
    let hierarchicalSymbol: Bool
    let action: () async -> Void

    @State private var hovered = false

    var body: some View {
        Button(role: self.role) {
            Task { await self.action() }
        } label: {
            ZStack {
                Image(systemName: self.symbol)
                    .font(.app(size: self.fontSize, weight: .semibold))
                    .foregroundStyle(self.hovered ? self.tint : self.baseTint)
                    .symbolRenderingMode(self.hierarchicalSymbol ? .hierarchical : .monochrome)
                    .opacity(self.isLoading ? 0 : 1)

                ProgressView()
                    .controlSize(.mini)
                    .opacity(self.isLoading ? 1 : 0)
            }
            .frame(width: self.size, height: self.size)
            .background(
                RoundedRectangle(
                    cornerRadius: min(self.size * 0.42, MenuBarLayoutTokens.cardRadius),
                    style: .continuous)
                    .fill(self.hovered ? self.tint.opacity(0.14) : self.baseTint.opacity(0.06)))
            .overlay {
                RoundedRectangle(
                    cornerRadius: min(self.size * 0.42, MenuBarLayoutTokens.cardRadius),
                    style: .continuous)
                    .stroke(self.hovered ? self.tint.opacity(0.26) : self.baseTint.opacity(0.08), lineWidth: 0.8)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(self.isLoading)
        .onHover { isHovering in
            withAnimation(.easeInOut(duration: 0.14)) {
                self.hovered = isHovering
            }
        }
    }
}
