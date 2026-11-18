import Foundation
import Observation
import SwiftUI

/// One open Markdown file, read and written in place.
@MainActor @Observable final class MarkdownFile {
    let url: URL
    /// The source as the editor shows it, styled as Markdown.
    var source: AttributedString
    var selection = AttributedTextSelection()
    private(set) var savedText: String
    @ObservationIgnored private let scoped: Bool

    var name: String { url.lastPathComponent }
    var text: String { String(source.characters) }
    var isDirty: Bool { text != savedText }

    init(url: URL) throws {
        scoped = url.startAccessingSecurityScopedResource()
        self.url = url
        let text: String
        do {
            text = try Self.coordinate(url, writing: false) { try MarkdownText.decode(Data(contentsOf: $0)) }
        } catch {
            if scoped { url.stopAccessingSecurityScopedResource() }
            throw error
        }
        savedText = text
        source = SourceStyle.styled(text)
    }

    /// Takes an edit from the editor and restyles it, so "# " becomes a heading as it is
    /// typed. The editor reports the text and then the selection, so restyle on the next
    /// turn, once both have landed.
    func edit(_ edited: AttributedString) {
        source = edited
        Task { @MainActor in
            let selected = selectedRange()
            SourceStyle.apply(to: &source)
            select(selected)
        }
    }

    /// Applies a format bar or Format menu action at the selection.
    func format(_ action: MarkdownFormat) {
        let result = action.apply(to: text, selection: selectedRange())
        // Replace only the span that changed, so the editor sees an edit, not a new document.
        let before = Array(text), after = Array(result.text)
        let head = zip(before, after).prefix { $0 == $1 }.count
        let tail = zip(before[head...].reversed(), after[head...].reversed()).prefix { $0 == $1 }.count
        let chars = source.characters
        let lower = chars.index(chars.startIndex, offsetBy: head)
        let upper = chars.index(chars.startIndex, offsetBy: before.count - tail)
        source.replaceSubrange(lower..<upper, with: AttributedString(String(after[head..<(after.count - tail)])))
        SourceStyle.apply(to: &source)
        select(result.selection)
    }

    // AttributedString indices don't survive a restyle, so the selection crosses one as
    // character offsets.
    private func selectedRange() -> Range<Int> {
        let chars = source.characters
        let offset = { chars.distance(from: chars.startIndex, to: $0) }
        switch selection.indices(in: source) {
        case .insertionPoint(let index): return offset(index)..<offset(index)
        case .ranges(let ranges):
            guard let first = ranges.ranges.first else { return chars.count..<chars.count }
            return offset(first.lowerBound)..<offset(first.upperBound)
        }
    }

    private func select(_ range: Range<Int>) {
        let chars = source.characters
        let lower = chars.index(chars.startIndex, offsetBy: min(range.lowerBound, chars.count))
        let upper = chars.index(chars.startIndex, offsetBy: min(range.upperBound, chars.count))
        selection = lower == upper ? AttributedTextSelection(insertionPoint: lower) : AttributedTextSelection(range: lower..<upper)
    }

    deinit {
        if scoped { url.stopAccessingSecurityScopedResource() }
    }

    // ponytail: last writer wins. Watch the file with NSFilePresenter if two
    // windows or another app editing the same file becomes a real case.
    func save() throws {
        let text = text
        try Self.coordinate(url, writing: true) { try Data(text.utf8).write(to: $0, options: .atomic) }
        savedText = text
    }

    private static func coordinate<T>(_ url: URL, writing: Bool, _ body: (URL) throws -> T) throws -> T {
        var coordinationError: NSError?
        var result: Result<T, any Error> = .failure(CocoaError(.fileReadUnknown))
        let coordinator = NSFileCoordinator()
        if writing {
            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { url in result = Result { try body(url) } }
        } else {
            coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in result = Result { try body(url) } }
        }
        if let coordinationError { throw coordinationError }
        return try result.get()
    }
}

enum MarkdownText {
    /// Refuses bytes that aren't UTF-8 rather than replacing them, so saving can't corrupt a file.
    static func decode(_ data: Data) throws -> String {
        guard let text = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        return text
    }

    /// Words a reader sees, so Markdown marks don't count.
    static func wordCount(_ text: String) -> Int {
        func words(_ text: some StringProtocol) -> Int {
            text.split(whereSeparator: \.isWhitespace).filter { $0.contains { $0.isLetter || $0.isNumber } }.count
        }
        // The parser joins blocks with no space between them, so count each block apart.
        guard let parsed = try? AttributedString(markdown: text) else { return words(text) }
        return parsed.runs[\.presentationIntent].reduce(0) { $0 + words(String(parsed[$1.1].characters)) }
    }
}
