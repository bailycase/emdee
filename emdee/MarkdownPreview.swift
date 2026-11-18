import SwiftUI

struct MarkdownPreview: View {
    let source: String

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(MarkdownBlock.parse(source)) { block in
                    if block.isRule {
                        Divider()
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            if let marker = block.marker { Text(verbatim: marker).foregroundStyle(.secondary) }
                            Text(block.text)
                                .font(block.font)
                                .lineSpacing(3)
                                .accessibilityAddTraits(block.heading == nil ? [] : .isHeader)
                        }
                        .padding(block.isCode ? 12 : 0)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(block.isCode ? Color.secondary.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 6))
                        .padding(.leading, block.quoted ? 14 : 0)
                        .overlay(alignment: .leading) {
                            if block.quoted { Capsule().fill(.tertiary).frame(width: 3) }
                        }
                        .padding(.leading, CGFloat(max(0, block.listDepth - 1)) * 16)
                    }
                }
            }
            .textSelection(.enabled)
            .frame(maxWidth: 660, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }
}

struct MarkdownBlock: Identifiable {
    let id: Int
    var text: AttributedString
    var heading: Int?
    var marker: String?
    var listDepth = 0
    var isCode = false
    var isRule = false
    var quoted = false

    var font: Font {
        if isCode { return .system(.body, design: .monospaced) }
        switch heading {
        case 1: return .largeTitle.bold()
        case 2: return .title.bold()
        case .some: return .headline
        case nil: return .body
        }
    }

    static func parse(_ source: String) -> [Self] {
        guard let parsed = try? AttributedString(markdown: source) else {
            return [Self(id: 0, text: AttributedString(source))]
        }
        var seenItems = Set<Int>()
        return parsed.runs[\.presentationIntent].enumerated().map { index, run in
            let components = run.0?.components ?? []
            var block = Self(id: index, text: AttributedString(parsed[run.1]))
            for (offset, component) in components.enumerated() {
                switch component.kind {
                case .header(let level): block.heading = level
                case .codeBlock: block.isCode = true
                case .thematicBreak: block.isRule = true
                case .blockQuote: block.quoted = true
                case .orderedList, .unorderedList: block.listDepth += 1
                case .listItem(let ordinal):
                    if block.marker == nil, seenItems.insert(component.identity).inserted {
                        let parent = components.dropFirst(offset + 1).first?.kind
                        block.marker = parent == .orderedList ? "\(ordinal)." : "•"
                    }
                default: break
                }
            }
            return block
        }
    }
}
