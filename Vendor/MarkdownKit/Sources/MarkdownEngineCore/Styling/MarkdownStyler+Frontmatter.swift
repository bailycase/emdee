// MarkdownKit, modified for emdee: fold flat YAML mappings into key/value rows.
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension MarkdownStyler {
    static func styleFrontmatter(_ ctx: StylingContext) -> [StyledRange] {
        guard let (idx, token) = ctx.tokens.enumerated().first(where: { $0.element.kind == .frontmatter }),
              ctx.inScope(token.range) else { return [] }
        var attrs: [StyledRange] = [(token.range, [.spellingState: 0])]
        let content = ctx.nsText.substring(with: token.contentRange)
        let theme = ctx.configuration.theme
        guard !ctx.activeTokenIndices.contains(idx),
              let image = frontmatterRows(content, width: effectiveContainerWidth(for: ctx), font: ctx.baseFont,
                                          theme: theme, appearance: tableRenderAppearance(ctx)) else {
            attrs += frontmatterSourceAttributes(token, ns: ctx.nsText, theme: theme, source: ctx.configuration.source)
            attrs.append((token.range, [.font: PlatformFont.monospacedSystemFont(ofSize: ctx.baseFont.pointSize * 0.88, weight: .regular)]))
            return attrs
        }
        _ = appendRenderedStandaloneBlock(for: token, rawContent: content, image: image,
            imageBounds: CGRect(origin: .zero, size: image.size), paragraphSpacingBefore: 0,
            paragraphSpacing: ctx.configuration.linkPreviews.paragraphSpacing, alignment: .left,
            mode: .collapsedSource(markerTexts: []), ctx: ctx, attrs: &attrs)
        return attrs
    }

    static func frontmatterSourceAttributes(_ token: MarkdownToken, ns: NSString, theme: MarkdownEditorTheme,
                                            source: SourceModeStyle) -> [StyledRange] {
        var attrs: [StyledRange] = token.markerRanges.map { ($0, [.foregroundColor: theme.mutedText]) }
        var cursor = token.contentRange.location
        while cursor < NSMaxRange(token.contentRange) {
            let line = ns.lineRange(for: NSRange(location: cursor, length: 0))
            let colon = ns.range(of: ":", range: line)
            if colon.location != NSNotFound, colon.location > cursor {
                attrs.append((NSRange(location: cursor, length: colon.location - cursor), [.foregroundColor: source.keyColor]))
            }
            cursor = NSMaxRange(line)
        }
        return attrs
    }

    // This is a view of simple scalar properties, not a YAML serializer. Leave an
    // unfamiliar construct, duplicate key, or very large block in source rather than hiding it.
    private static func frontmatterRows(_ content: String, width: CGFloat, font: PlatformFont,
                                        theme: MarkdownEditorTheme, appearance: PlatformAppearance) -> PlatformImage? {
        guard width >= 40, width <= 4096, content.utf8.count <= 16_384 else { return nil }
        let mono = PlatformFont.monospacedSystemFont(ofSize: round(font.pointSize * 0.84), weight: .regular)
        let muted = theme.mutedText.mdResolved(in: appearance)
        let ink = theme.bodyText.mdResolved(in: appearance)
        var seen = Set<String>()
        var rows: [(NSAttributedString, NSAttributedString)] = []
        for line in content.split(whereSeparator: \.isNewline) {
            guard let colon = line.firstIndex(of: ":") else { return nil }
            let key = String(line[..<colon]), rest = line[line.index(after: colon)...]
            guard !key.isEmpty, key.allSatisfy({ $0.isLetter || $0.isNumber || "_-".contains($0) }),
                  seen.insert(key).inserted, rest.first == " " else { return nil }
            var value = rest.trimmingCharacters(in: .whitespaces)
            guard let first = value.first else { return nil }
            if first == "\"" || first == "'" {
                guard value.count >= 2, value.last == first else { return nil }
                value = String(value.dropFirst().dropLast())
                guard !value.contains(first), !value.contains("\\") else { return nil }
            } else if "[{|>&*!#%@`".contains(first) || value.contains(" #") || value.contains(": ") {
                return nil
            }
            rows.append((NSAttributedString(string: key, attributes: [.font: mono, .foregroundColor: muted]),
                         NSAttributedString(string: value, attributes: [.font: ["true", "false"].contains(value) ? mono : font, .foregroundColor: ink])))
        }
        guard !rows.isEmpty else { return nil }
        let stacked = width < 440
        let keyWidth = stacked ? width : min(ceil(rows.map { $0.0.size().width }.max() ?? 0), width * 0.4)
        let x = stacked ? 0 : keyWidth + 24, valueWidth = width - x
        func height(_ text: NSAttributedString, _ w: CGFloat) -> CGFloat {
            ceil(text.boundingRect(with: CGSize(width: w, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height) + 1
        }
        var parts: [(NSAttributedString, CGRect)] = []
        var y: CGFloat = 0
        for (key, value) in rows {
            let kh = height(key, keyWidth), vh = height(value, valueWidth)
            let vy = stacked ? y + kh + 2 : y
            parts.append((key, CGRect(x: 0, y: stacked ? y : y + 2, width: keyWidth, height: kh)))
            parts.append((value, CGRect(x: x, y: vy, width: valueWidth, height: vh)))
            y = max(y + kh + 2, vy + vh) + 8
        }
        let h = ceil(y + 8)
        // UIKit rasterizes this attachment; don't allocate an unbounded bitmap.
        guard width * h <= 1_500_000 else { return nil }
        return PlatformImage.mdDrawing(size: CGSize(width: width, height: h)) {
            for (label, rect) in parts { label.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil) }
            ink.withAlphaComponent(0.14).setFill()
            PlatformBezierPath(rect: CGRect(x: 0, y: h - 1, width: width, height: 1)).fill()
        }
    }
}
