import MarkdownEngine
import SwiftUI

/// How emdee sets up MarkdownEngine's editor: formatted Markdown whose text is the file,
/// character for character.
extension MarkdownEditorConfiguration {
    /// Inset the text, not the scroll view. A fixed engine readingWidth would clip
    /// the column when the sidebar leaves less than that width for the document.
    static func emdee(margin: CGFloat) -> MarkdownEditorConfiguration {
        var configuration = MarkdownEditorConfiguration.default
        let ink = configuration.theme.bodyText
        configuration.theme.tableHeaderBackground = ink.withAlphaComponent(0.06)
        configuration.theme.tableBorder = ink.withAlphaComponent(0.16)
        // The file is plain text: no autocorrect or spelling marks while writing Markdown.
        configuration.spellChecking = SpellCheckingPolicy(
            continuousSpellChecking: false, grammarChecking: false, automaticSpellingCorrection: false)
        configuration.textInsets = TextInsets(horizontal: margin, vertical: 8)
        return configuration
    }
}

/// The format bar's and Format menu's actions, run by the editor so they undo as one step
/// and keep the selection.
enum MarkdownFormat: String, CaseIterable, Identifiable {
    case heading, bold, italic, bulletList, checklist, code, link
    var id: Self { self }

    var label: String {
        switch self {
        case .heading: "Heading"
        case .bold: "Bold"
        case .italic: "Italic"
        case .bulletList: "Bulleted List"
        case .checklist: "Checklist"
        case .code: "Code"
        case .link: "Link"
        }
    }

    var shortcut: KeyboardShortcut? {
        switch self {
        case .bold: KeyboardShortcut("b")
        case .italic: KeyboardShortcut("i")
        case .link: KeyboardShortcut("k")
        default: nil
        }
    }

    /// Applies the action at the editor's selection. `text` is the document the editor shows.
    @MainActor func perform(on editor: MarkdownEditorController, in text: String) {
        switch self {
        case .heading: editor.setBlockStyle(.title)
        case .bold: editor.toggle(.bold)
        case .italic: editor.toggle(.italic)
        case .bulletList: editor.setBlockStyle(.bullet)
        case .checklist: editor.setBlockStyle(.task)
        case .code: editor.toggle(.code)
        case .link:
            guard let range = editor.selectedRange, NSMaxRange(range) <= (text as NSString).length else { return }
            let selected = (text as NSString).substring(with: range)
            editor.replace(range, with: "[\(selected)]()", actionName: "Link")
            // Words become the link's text and the caret waits in the parentheses; no
            // selection leaves the caret in the brackets.
            let caret = range.length == 0 ? range.location + 1 : range.location + range.length + 3
            editor.reveal(NSRange(location: caret, length: 0))
        }
    }
}
