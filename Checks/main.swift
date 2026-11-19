import Foundation

// Opening a file keeps its exact source, and bytes that aren't UTF-8 are refused, not replaced.
let bytes = Data("# Café\r\n\r\n- *First*\r\n- Second\r\n".utf8)
precondition(Data(try! MarkdownText.decode(bytes).utf8) == bytes)
precondition((try? MarkdownText.decode(Data([0xFF]))) == nil)

precondition(MarkdownText.wordCount("## Install\n\n- `brew install`") == 3)

// A table edit saves Markdown, not rendered cells, and preserves untouched CRLF and Unicode.
try MainActor.assumeIsolated {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".md")
    let original = "# Café\r\n\r\n| Source | Reference |\r\n| --- | --- |\r\n| App | **Pending** |\r\n"
    try Data(original.utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    let file = try MarkdownFile(url: url)
    precondition(!file.isDirty && Data(file.text.utf8) == Data(original.utf8))
    let edited = original.replacingOccurrences(of: "Pending", with: "Approved")
    file.text = edited
    precondition(file.isDirty)
    try file.save()
    let saved = try Data(contentsOf: url)
    precondition(!file.isDirty && saved == Data(edited.utf8))
}

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
