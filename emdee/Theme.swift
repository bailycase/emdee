import SwiftUI

/// Type and colors from the emdee design. Mac sizes are fixed points; iOS sizes follow Dynamic Type.
enum Theme {
    #if os(macOS)
    static let body = Font.system(size: 15)
    static let code = Font.system(size: 13, design: .monospaced)
    static let columnPadding: CGFloat = 48

    static func heading(_ level: Int) -> Font {
        switch level {
        case 1: .system(size: 28, weight: .bold)
        case 2: .system(size: 20, weight: .semibold)
        case 3: .system(size: 17, weight: .semibold)
        default: .system(size: 15, weight: .semibold)
        }
    }
    #else
    static let body = Font.body
    static let code = Font.system(.subheadline, design: .monospaced)
    static let columnPadding: CGFloat = 20

    static func heading(_ level: Int) -> Font {
        switch level {
        case 1: .title.bold()
        case 2: .title2.weight(.semibold)
        case 3: .title3.weight(.semibold)
        default: .headline
        }
    }
    #endif
    static let column: CGFloat = 680
    static let lineSpacing: CGFloat = 6

    static let codeBackground = Color("CodeBackground")
}
