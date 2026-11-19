import Foundation
import Observation
import SwiftUI

/// One open Markdown file, read and written in place.
@MainActor @Observable final class MarkdownFile {
    let url: URL
    /// The document exactly as the editor shows it and as it is saved, character for character.
    var text: String {
        didSet {
            guard !text.utf8.elementsEqual(oldValue.utf8) else { return }
            revision += 1
            isDirty = !text.utf8.elementsEqual(savedText.utf8)
            recount()
        }
    }
    @ObservationIgnored private var savedText: String
    private(set) var revision = 0
    private(set) var isDirty = false
    /// Words a reader sees, counted a moment after typing stops, so neither typing nor
    /// resizing the window pays for it.
    private(set) var wordCount: Int
    @ObservationIgnored private let scoped: Bool
    @ObservationIgnored private var counting: Task<Void, Never>?

    var name: String { url.lastPathComponent }

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
        self.text = text
        wordCount = MarkdownText.wordCount(text)
    }

    private func recount() {
        counting?.cancel()
        let text = text
        counting = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            let count = await Task.detached(priority: .utility) { MarkdownText.wordCount(text) }.value
            if !Task.isCancelled { wordCount = count }
        }
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
        isDirty = false
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
    nonisolated static func wordCount(_ text: String) -> Int {
        func words(_ text: some StringProtocol) -> Int {
            text.split(whereSeparator: \.isWhitespace).filter { $0.contains { $0.isLetter || $0.isNumber } }.count
        }
        // The parser joins blocks with no space between them, so count each block apart.
        guard let parsed = try? AttributedString(markdown: text) else { return words(text) }
        return parsed.runs[\.presentationIntent].reduce(0) { $0 + words(String(parsed[$1.1].characters)) }
    }
}
