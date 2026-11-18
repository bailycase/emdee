import Foundation

// Opening a file keeps its exact source, and bytes that aren't UTF-8 are refused, not replaced.
let bytes = Data("# Café\r\n\r\n- *First*\r\n- Second\r\n".utf8)
precondition(Data(try! MarkdownText.decode(bytes).utf8) == bytes)
precondition((try? MarkdownText.decode(Data([0xFF]))) == nil)

// Live styling: marks muted, headings and inline styles applied, characters untouched.
import SwiftUI
let typed = "## Install\nUse **brew** or `make`.\n- [x] Done"
let live = SourceStyle.styled(typed)
precondition(String(live.characters) == typed)
func attributes(of text: String) -> AttributedSubstring { live[live.range(of: text)!] }
precondition(attributes(of: "## ").foregroundColor == .secondary)
precondition(attributes(of: "Install").font == Theme.heading(2))
precondition(attributes(of: "brew").font == Theme.body.bold())
precondition(attributes(of: "make").font == Theme.code)
precondition(attributes(of: "Use").font == Theme.body && attributes(of: "Use").foregroundColor == nil)
precondition(attributes(of: "Done").foregroundColor == .secondary)
precondition(MarkdownText.wordCount("## Install\n\n- `brew install`") == 3)

// Format bar edits: wrapping keeps the selection on the words, line prefixes toggle.
let bold = MarkdownFormat.bold.apply(to: "say hi", selection: 4..<6)
precondition(bold.text == "say **hi**" && bold.selection == 6..<8)
let link = MarkdownFormat.link.apply(to: "docs", selection: 0..<4)
precondition(link.text == "[docs]()" && link.selection == 7..<7)
let listed = MarkdownFormat.bulletList.apply(to: "a\r\nb", selection: 0..<3)
precondition(listed.text == "- a\r\n- b" && listed.selection == 2..<7)
precondition(MarkdownFormat.bulletList.apply(to: listed.text, selection: listed.selection).text == "a\r\nb")
precondition(MarkdownFormat.heading.apply(to: "## Install", selection: 10..<10).text == "Install")

// Recents: grouped by day, newest first, with paths shown the way people know them.
let calendar = Calendar(identifier: .gregorian)
let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 12, hour: 10))!
func recent(_ path: String, daysAgo: Int) -> RecentFile {
    RecentFile(path: path, bookmark: Data(), date: calendar.date(byAdding: .day, value: -daysAgo, to: now)!, edited: false)
}
let groups = [recent("/a.md", daysAgo: 0), recent("/b.md", daysAgo: 1), recent("/c.md", daysAgo: 7), recent("/d.md", daysAgo: 30)]
    .grouped(matching: "", now: now, calendar: calendar)
precondition(groups.map(\.title) == ["Today", "Yesterday", "Previous 7 Days", "Earlier"])
precondition([recent("/notes/a.md", daysAgo: 0), recent("/b.md", daysAgo: 0)].grouped(matching: "NOTES", now: now, calendar: calendar).flatMap(\.files).map(\.name) == ["a.md"])
MainActor.assumeIsolated {
    precondition(RecentFile.folder(of: "/Users/me/Developer/emdee/README.md", home: "/Users/me") == "~/Developer/emdee")
    precondition(RecentFile.folder(of: "/Users/me/Library/Mobile Documents/com~apple~CloudDocs/Notes/ideas.md", home: "/x") == "iCloud Drive/Notes")
    precondition(RecentFile.folder(of: "/private/var/mobile/Containers/Data/Application/AB-12/Documents/Inbox/a.md", home: "/x") == "emdee/Inbox")
}

print("Checks passed.")
