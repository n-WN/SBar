import SwiftUI

enum MenuBarLayoutTokens {
    static let panelWidth: CGFloat = 284

    // MARK: - Spacing

    static let space1: CGFloat = 2
    static let space2: CGFloat = 4
    static let space4: CGFloat = 6
    static let space6: CGFloat = 8
    static let space8: CGFloat = 12

    // MARK: - Stroke

    static let stroke: CGFloat = 0.9

    // MARK: - Corner Radius

    static let cornerRadius: CGFloat = 18
    static let cardRadius: CGFloat = 16
    static let innerCardRadius: CGFloat = 14
    static let rowRadius: CGFloat = 11
    static let pillRadius: CGFloat = 999

    // MARK: - Insets

    static let panelOuterPadding: CGFloat = 2
    static let panelHorizontalInset: CGFloat = 8
    static let panelTopInset: CGFloat = 8
    static let sectionInset: CGFloat = 6
    static let denseSectionInset: CGFloat = 5

    // MARK: - Row Heights

    static let compactRowHeight: CGFloat = 24
    static let rowHeight: CGFloat = 36

    // MARK: - Icon Size

    static let rowLeadingIcon: CGFloat = 18

    // MARK: - Text

    static let minimumScale: CGFloat = 0.85

    // MARK: - Opacity

    enum Opacity {
        static let solid: CGFloat = 0.96
        static let tint: CGFloat = 0.16
        static let faint: CGFloat = 0.08
    }

    // MARK: - Theme Appearance

    enum Theme {
        enum Dark {
            static let labelSecondary: CGFloat = 0.78
            static let labelTertiary: CGFloat = 0.56
            static let separator: CGFloat = 0.42
            static let controlFill: CGFloat = 0.94
            static let controlBorder: CGFloat = 0.88
            static let hoverFill: CGFloat = 0.40
            static let borderEmphasis: CGFloat = 0.94
        }

        enum Light {
            static let labelSecondary: CGFloat = 0.72
            static let labelTertiary: CGFloat = 0.48
            static let separator: CGFloat = 0.35
            static let controlFill: CGFloat = 0.98
            static let controlBorder: CGFloat = 0.84
            static let hoverFill: CGFloat = 0.26
            static let borderEmphasis: CGFloat = 0.94
        }
    }

    // MARK: - Shadow

    enum Shadow {
        static let standard = (opacity: 0.18, radius: 28.0, x: 0.0, y: 16.0)
        static let card = (opacity: 0.08, radius: 10.0, x: 0.0, y: 4.0)
    }

    // MARK: - Font Sizes

    enum FontSize {
        static let micro: CGFloat = 10
        static let caption: CGFloat = 11
        static let body: CGFloat = 13
        static let subhead: CGFloat = 15
        static let title: CGFloat = 18
        static let hero: CGFloat = 24
    }
}

extension View {
    func menuRowPadding(vertical: CGFloat = MenuBarLayoutTokens.space6) -> some View {
        padding(.horizontal, MenuBarLayoutTokens.space4)
            .padding(.vertical, vertical)
    }
}
