import Foundation
import Observation
#if os(iOS)
import UIKit
#endif

/// A file the user opened or edited. emdee keeps a bookmark to it, never a copy.
struct RecentFile: Codable, Identifiable, Hashable {
    var id = UUID()
    var path: String
    var bookmark: Data
    var date: Date
    var edited: Bool

    var name: String { (path as NSString).lastPathComponent }
    @MainActor var folder: String { Self.folder(of: path) }

    /// "Edited 9:41 AM", "Opened Mon", "Opened Jun 3"
    func when(now: Date = .now, calendar: Calendar = .current) -> String {
        let time = switch RecentGroup.index(of: date, now: now, calendar: calendar) {
        case 0, 1: date.formatted(date: .omitted, time: .shortened)
        case 2: date.formatted(.dateTime.weekday(.abbreviated))
        default: date.formatted(.dateTime.month(.abbreviated).day())
        }
        return "\(edited ? "Edited" : "Opened") \(time)"
    }

    @MainActor static func folder(of path: String, home: String = realHome) -> String {
        let dir = (path as NSString).deletingLastPathComponent
        for (marker, label) in [("/Mobile Documents/com~apple~CloudDocs", "iCloud Drive"), ("/File Provider Storage", onMyDevice)] {
            if let range = dir.range(of: marker) { return label + dir[range.upperBound...] }
        }
        // Files iOS copied in for emdee, such as Mail attachments, live in its Documents folder.
        if let match = dir.firstMatch(of: /\/Containers\/Data\/Application\/[^\/]+\/Documents/) {
            return "emdee" + dir[match.range.upperBound...]
        }
        if dir == home || dir.hasPrefix(home + "/") { return "~" + dir.dropFirst(home.count) }
        return dir
    }

    @MainActor private static var onMyDevice: String {
        #if os(iOS)
        "On My \(UIDevice.current.model)"
        #else
        "On My Mac"
        #endif
    }

    /// The user's home folder, not the sandbox container's.
    static var realHome: String {
        #if os(macOS)
        if let entry = getpwuid(getuid()) { return String(cString: entry.pointee.pw_dir) }
        #endif
        return NSHomeDirectory()
    }
}

struct RecentGroup: Identifiable {
    static let titles = ["Today", "Yesterday", "Previous 7 Days", "Earlier"]
    let title: String
    let files: [RecentFile]
    var id: String { title }

    static func index(of date: Date, now: Date, calendar: Calendar) -> Int {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        return days <= 0 ? 0 : days == 1 ? 1 : days <= 7 ? 2 : 3
    }
}

extension [RecentFile] {
    func grouped(matching query: String, now: Date = .now, calendar: Calendar = .current) -> [RecentGroup] {
        let matches = query.isEmpty ? self : filter { $0.path.localizedStandardContains(query) }
        let buckets = Dictionary(grouping: matches) { RecentGroup.index(of: $0.date, now: now, calendar: calendar) }
        return RecentGroup.titles.indices.compactMap { i in
            buckets[i].map { RecentGroup(title: RecentGroup.titles[i], files: $0) }
        }
    }
}

/// The recent files list, newest first, shared by every window.
@MainActor @Observable final class Recents {
    private(set) var files: [RecentFile]
    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "recentFiles"
    #if os(macOS)
    private static let bookmarkOptions: URL.BookmarkCreationOptions = .withSecurityScope
    private static let resolveOptions: URL.BookmarkResolutionOptions = .withSecurityScope
    #else
    private static let bookmarkOptions: URL.BookmarkCreationOptions = []
    private static let resolveOptions: URL.BookmarkResolutionOptions = []
    #endif

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        files = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode([RecentFile].self, from: $0) } ?? []
    }

    /// Moves `url` to the top of the list. The caller must hold access to `url`.
    @discardableResult
    func record(_ url: URL, edited: Bool) throws -> RecentFile.ID {
        let bookmark = try url.bookmarkData(options: Self.bookmarkOptions, includingResourceValuesForKeys: nil, relativeTo: nil)
        var file = files.first { $0.path == url.path } ?? RecentFile(path: url.path, bookmark: bookmark, date: .now, edited: edited)
        files.removeAll { $0.id == file.id }
        file.bookmark = bookmark
        file.date = .now
        file.edited = edited
        // ponytail: fixed cap of 50, make it a setting if anyone asks.
        files = Array(([file] + files).prefix(50))
        save()
        return file.id
    }

    /// Resolves a recent file's bookmark, following the file if it moved.
    func url(for id: RecentFile.ID) throws -> URL {
        guard let i = files.firstIndex(where: { $0.id == id }) else { throw CocoaError(.fileNoSuchFile) }
        var stale = false
        let url = try URL(resolvingBookmarkData: files[i].bookmark, options: Self.resolveOptions, relativeTo: nil, bookmarkDataIsStale: &stale)
        if stale {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let fresh = try? url.bookmarkData(options: Self.bookmarkOptions, includingResourceValuesForKeys: nil, relativeTo: nil) {
                files[i].bookmark = fresh
            }
        }
        if stale || files[i].path != url.path {
            files[i].path = url.path
            save()
        }
        return url
    }

    func remove(_ id: RecentFile.ID) {
        files.removeAll { $0.id == id }
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(files), forKey: Self.key)
    }
}
