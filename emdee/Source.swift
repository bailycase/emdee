import SwiftUI

/// Live Markdown: styles the source as it is typed. Headings grow, bold turns bold, code
/// turns monospaced, and the Markdown marks stay in place but muted. Only attributes
/// change, never characters, so the file on disk is exactly what was typed.
enum SourceStyle {
    static func styled(_ text: String) -> AttributedString {
        var source = AttributedString(text)
        apply(to: &source)
        return source
    }

    static func apply(to source: inout AttributedString) {
        let muted = AttributeContainer().foregroundColor(.secondary)
        let code = AttributeContainer().font(Theme.code).backgroundColor(Theme.codeBackground)
        source.setAttributes(AttributeContainer().font(Theme.body))

        let chars = source.characters
        var start = chars.startIndex
        var inFence = false
        while start < chars.endIndex {
            let end = chars[start...].firstIndex(where: \.isNewline) ?? chars.endIndex
            let line = String(chars[start..<end])
            func style(_ range: Range<String.Index>, _ attributes: AttributeContainer) {
                let lower = chars.index(start, offsetBy: line.distance(from: line.startIndex, to: range.lowerBound))
                let upper = chars.index(lower, offsetBy: line.distance(from: range.lowerBound, to: range.upperBound))
                source[lower..<upper].mergeAttributes(attributes)
            }
            let whole = line.startIndex..<line.endIndex
            /// Mutes the marks at both ends of `range` and styles what they enclose.
            func enclose(_ range: Range<String.Index>, marks: Int, _ attributes: AttributeContainer) {
                let inner = line.index(range.lowerBound, offsetBy: marks)..<line.index(range.upperBound, offsetBy: -marks)
                style(inner, attributes)
                style(range.lowerBound..<inner.lowerBound, muted)
                style(inner.upperBound..<range.upperBound, muted)
            }

            let trimmed = line.drop { $0 == " " }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                style(whole, code.merging(muted))
                inFence.toggle()
            } else if inFence {
                style(whole, code)
            } else if trimmed.hasPrefix("|") {
                // Tables in monospace so their columns line up.
                style(whole, AttributeContainer().font(Theme.code))
            } else if line.wholeMatch(of: /[ ]{0,3}(?:(?:-[ ]*){3,}|(?:\*[ ]*){3,}|(?:_[ ]*){3,})/) != nil {
                style(whole, muted)
            } else {
                var lineFont = Theme.body
                var body = line.startIndex
                if let heading = line.prefixMatch(of: /(#{1,6})[ \t]+/) {
                    lineFont = Theme.heading(heading.output.1.count)
                    style(whole, AttributeContainer().font(lineFont))
                    style(heading.range, muted)
                    body = heading.range.upperBound
                } else if let quote = line.prefixMatch(of: /[ \t]*(?:>[ \t]?)+/) {
                    style(whole, muted)
                    body = quote.range.upperBound
                } else if let item = line.prefixMatch(of: /[ \t]*(?:[-*+]|\d+[.)])[ \t]+(\[[ xX]\][ \t]+)?/) {
                    style(item.range, muted)
                    if item.output.1?.lowercased().contains("x") == true {
                        // A ticked task reads as done.
                        style(item.range.upperBound..<line.endIndex, muted)
                    }
                    body = item.range.upperBound
                }

                let rest = line[body...]
                for match in rest.matches(of: /\[([^\]\n]+)\]\(([^)\s]*)\)/) {
                    style(match.range, muted)
                    style(match.output.1.startIndex..<match.output.1.endIndex, AttributeContainer().foregroundColor(.accentColor))
                }
                for match in rest.matches(of: /~~[^~\n]+~~/) {
                    enclose(match.range, marks: 2, AttributeContainer().strikethroughStyle(.single))
                }
                for match in rest.matches(of: /(?:^|[^*\w])(\*[^*\s](?:[^*\n]*[^*\s])?\*)(?!\*)/) {
                    enclose(match.output.1.startIndex..<match.output.1.endIndex, marks: 1, AttributeContainer().font(lineFont.italic()))
                }
                for match in rest.matches(of: /(?:^|\W)(_[^_\s](?:[^_\n]*[^_\s])?_)(?!\w)/) {
                    enclose(match.output.1.startIndex..<match.output.1.endIndex, marks: 1, AttributeContainer().font(lineFont.italic()))
                }
                for match in rest.matches(of: /(\*\*|__)[^\n]+?\1/) {
                    enclose(match.range, marks: 2, AttributeContainer().font(lineFont.bold()))
                }
                for match in rest.matches(of: /`[^`\n]+`/) {
                    enclose(match.range, marks: 1, code)
                }
            }
            start = end < chars.endIndex ? chars.index(after: end) : end
        }
    }
}

/// The format bar's actions. Each edits plain text and returns the new selection, in characters.
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

    func apply(to text: String, selection: Range<Int>) -> (text: String, selection: Range<Int>) {
        let lo = text.index(text.startIndex, offsetBy: selection.lowerBound)
        let hi = text.index(text.startIndex, offsetBy: selection.upperBound)
        let selected = text[lo..<hi]
        func wrap(_ open: String, _ close: String) -> (String, Range<Int>) {
            (String(text[..<lo]) + open + selected + close + text[hi...],
             selection.lowerBound + open.count..<selection.upperBound + open.count)
        }
        switch self {
        case .heading: return toggleLinePrefix("# ", existing: /#{1,6}[ \t]+/, in: text, selection: selection)
        case .bulletList: return toggleLinePrefix("- ", existing: /[-*+][ \t]+/, in: text, selection: selection)
        case .checklist: return toggleLinePrefix("- [ ] ", existing: /[-*+][ \t]+\[[ xX]\][ \t]+/, in: text, selection: selection)
        case .bold: return wrap("**", "**")
        case .italic: return wrap("*", "*")
        case .code: return selected.contains(where: \.isNewline) ? wrap("```\n", "\n```") : wrap("`", "`")
        case .link:
            let caret = selected.isEmpty ? selection.lowerBound + 1 : selection.upperBound + 3
            return (String(text[..<lo]) + "[" + selected + "]()" + text[hi...], caret..<caret)
        }
    }

    /// Adds `prefix` to every selected line, or removes the existing prefix when all lines have one.
    private func toggleLinePrefix(_ prefix: String, existing: Regex<Substring>, in text: String, selection: Range<Int>) -> (String, Range<Int>) {
        let chars = Array(text)
        var starts = [selection.lowerBound]
        while let first = starts.first, first > 0, !chars[first - 1].isNewline { starts[0] = first - 1 }
        for i in starts[0]..<selection.upperBound where chars[i].isNewline { starts.append(i + 1) }

        func prefixLength(at offset: Int) -> Int? {
            let start = text.index(text.startIndex, offsetBy: offset)
            return (try? existing.prefixMatch(in: text[start...]))?.output.count
        }
        let removing = starts.allSatisfy { prefixLength(at: $0) != nil }
        var result = text
        var deltas: [Int] = []
        for offset in starts.reversed() {
            let start = result.index(result.startIndex, offsetBy: offset)
            if removing {
                let length = prefixLength(at: offset)!
                result.removeSubrange(start..<result.index(start, offsetBy: length))
                deltas.append(-length)
            } else if prefixLength(at: offset) == nil {
                result.insert(contentsOf: prefix, at: start)
                deltas.append(prefix.count)
            } else {
                deltas.append(0)
            }
        }
        let first = deltas.last ?? 0
        let total = deltas.reduce(0, +)
        let lower = max(starts[0], selection.lowerBound + first)
        return (result, lower..<max(lower, selection.upperBound + total))
    }
}
