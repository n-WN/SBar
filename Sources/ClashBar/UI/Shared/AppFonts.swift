import AppKit
import SwiftUI

private typealias FS = MenuBarLayoutTokens.FontSize

extension Font {
    static func app(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func appMono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static let appCaption = app(size: FS.caption, weight: .medium)
    static let appBody = app(size: FS.body, weight: .medium)
    static let appSubhead = app(size: FS.subhead, weight: .semibold)
    static let appTitle = app(size: FS.title, weight: .bold)
}
