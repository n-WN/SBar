import SwiftUI

extension MenuBarRoot {
    var modeAndTabSection: some View {
        VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space6) {
            self.modeSwitcher
            self.topTabs
        }
        .padding(MenuBarLayoutTokens.sectionInset)
        .background(self.sectionCardBackground())
    }

    var modeSwitcher: some View {
        HStack(spacing: MenuBarLayoutTokens.space4) {
            self.modeSegmentButton(
                title: tr("ui.mode.rule"),
                mode: .rule,
                symbol: "line.3.horizontal.decrease.circle")
            self.modeSegmentButton(
                title: tr("ui.mode.global"),
                mode: .global,
                symbol: "globe")
            self.modeSegmentButton(
                title: tr("ui.mode.direct"),
                mode: .direct,
                symbol: "paperplane")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func modeSegmentButton(title: String, mode: CoreMode, symbol: String) -> some View {
        let selected = appState.currentMode == mode
        let switchingThisMode = switchingMode == mode
        let hovered = hoveredMode == mode
        let tint = self.modeAccent(for: mode)

        return Button {
            if !appState.isModeSwitchEnabled || switchingMode != nil || mode == appState.currentMode { return }

            switchingMode = mode
            Task { @MainActor in
                await appState.switchMode(to: mode)
                switchingMode = nil
            }
        } label: {
            HStack(spacing: MenuBarLayoutTokens.space4) {
                Group {
                    if switchingThisMode {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: symbol)
                            .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                    }
                }
                .foregroundStyle(selected ? tint : nativeSecondaryLabel)

                Text(title)
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                    .foregroundStyle((selected || hovered) ? nativePrimaryLabel : nativeSecondaryLabel)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, MenuBarLayoutTokens.space4)
            .padding(.vertical, MenuBarLayoutTokens.space4)
            .background(self.pillChipBackground(selected: selected, hovered: hovered, tint: tint))
        }
        .buttonStyle(.plain)
        .onHover { hoveredMode = self.nextHovered(current: hoveredMode, target: mode, isHovering: $0) }
    }

    var topTabs: some View {
        HStack(spacing: MenuBarLayoutTokens.space4) {
            ForEach(RootTab.allCases, id: \.self) { tab in
                self.topTabButton(tab)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(MenuBarLayoutTokens.space1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func topTabButton(_ tab: RootTab) -> some View {
        let selected = self.currentTab == tab
        let hovered = self.hoveredTab == tab
        let tint = self.tabAccent(for: tab)
        let title = self.tr(tab.titleKey)

        return Button {
            self.setCurrentTabWithoutAnimation(tab)
        } label: {
            HStack(spacing: 0) {
                Image(systemName: tab.symbolName)
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                    .foregroundStyle(selected ? tint : nativeTertiaryLabel)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, MenuBarLayoutTokens.space4)
            .padding(.vertical, MenuBarLayoutTokens.space4)
            .background(self.pillChipBackground(selected: selected, hovered: hovered, tint: tint))
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .onHover { self.hoveredTab = self.nextHovered(current: self.hoveredTab, target: tab, isHovering: $0) }
    }

    func pillChipBackground(selected: Bool, hovered: Bool, tint: Color) -> some View {
        Capsule(style: .continuous)
            .fill(
                selected
                    ? tint.opacity(MenuBarLayoutTokens.Opacity.tint)
                    : (hovered ? self.nativeHoverFill : self.cardFillColor.opacity(0.84)))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(
                        selected
                            ? tint.opacity(0.22)
                            : self.cardBorderColor.opacity(hovered ? 0.74 : 0.58),
                        lineWidth: MenuBarLayoutTokens.stroke)
            }
    }

    func modeAccent(for mode: CoreMode) -> Color {
        switch mode {
        case .rule:
            self.nativeAccent
        case .global:
            self.nativeInfo
        case .direct:
            self.nativePositive
        }
    }

    func tabAccent(for tab: RootTab) -> Color {
        switch tab {
        case .proxy:
            self.nativeAccent
        case .rules:
            self.nativeWarning
        case .activity:
            self.nativeTeal
        case .logs:
            self.nativePurple
        case .system:
            self.nativeIndigo
        }
    }
}
