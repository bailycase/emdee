import SwiftUI

/// Sizes of the editor column. Type and colors come from MarkdownEngine's editor configuration.
enum Theme {
    #if os(macOS)
    /// Body text size. Mac sizes are fixed points.
    static var bodySize: CGFloat { 15 }
    static let columnPadding: CGFloat = 48
    #else
    /// Body text size, following Dynamic Type.
    static var bodySize: CGFloat { UIFont.preferredFont(forTextStyle: .body).pointSize }
    static let columnPadding: CGFloat = 20
    #endif
    /// Width of the text column.
    static let column: CGFloat = 680
}
