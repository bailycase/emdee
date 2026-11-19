import SwiftUI
import UniformTypeIdentifiers

/// Recents beside the open file. One layout for every size: the split view collapses
/// into a stack on a narrow window, such as an iPhone or a folded iPhone Duo.
struct LibraryView: View {
    @Environment(Recents.self) private var recents
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selection: RecentFile.ID?
    @State private var file: MarkdownFile?
    @State private var query = ""
    @State private var importing = false
    @State private var columns = NavigationSplitViewVisibility.automatic
    @State private var failure: Failure?
    /// Squat windows (iPhone Duo, iPad, iPhone in landscape) put controls in a trailing rail.
    @State private var usesRail = false

    private var chrome: Chrome {
        #if os(macOS)
        .mac
        #else
        usesRail ? .rail : .phone
        #endif
    }
    private var collapsed: Bool { sizeClass == .compact }

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            RecentsList(
                groups: recents.files.grouped(matching: query),
                selection: $selection,
                query: query,
                chrome: chrome
            )
            .modifier(SidebarChrome(chrome: chrome, collapsed: collapsed, query: $query, openFile: openFile))
        } detail: {
            if let file {
                FileView(
                    file: file,
                    recent: recents.files.first { $0.id == selection },
                    chrome: chrome,
                    openFile: openFile,
                    back: collapsed ? { selection = nil } : nil,
                    sidebar: collapsed ? nil : SidebarToggle(hidden: columns == .detailOnly) {
                        columns = columns == .detailOnly ? .all : .detailOnly
                    }
                )
                .id(ObjectIdentifier(file))
            } else {
                ContentUnavailableView {
                    Label("No File Open", systemImage: "doc.text")
                } description: {
                    Text("Open a Markdown file, or choose one from Recents.")
                } actions: {
                    Button("Open File…", action: openFile)
                }
            }
        }
        .background {
            // Measure the whole window, so the keyboard coming up doesn't switch layouts.
            Color.clear
                .onGeometryChange(for: Bool.self) { $0.size.height < $0.size.width * 1.8 } action: { usesRail = $0 }
                .ignoresSafeArea()
        }
        .onChange(of: selection) { load($1) }
        .onOpenURL(perform: open)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.markdown]) { result in
            switch result {
            case .success(let url): open(url)
            case .failure(let error): failure = Failure(title: "Couldn't Open File", message: error.localizedDescription)
            }
        }
        .alert(failure?.title ?? "", isPresented: Binding { failure != nil } set: { if !$0 { failure = nil } }, presenting: failure) { failure in
            if let id = failure.recent {
                Button("Remove from Recents", role: .destructive) { recents.remove(id) }
            }
            Button("OK", role: .cancel) {}
        } message: { failure in
            Text(failure.message)
        }
        .focusedSceneValue(\.importing, $importing)
        #if os(macOS)
        .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
        #endif
    }

    private func openFile() { importing = true }

    /// Adds a file picked or sent from Finder or Files to Recents, then shows it.
    private func open(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let id = try recents.record(url, edited: false)
            if selection == id { load(id) } else { selection = id }
        } catch {
            failure = Failure(title: "Couldn't Open \(url.lastPathComponent)", message: error.localizedDescription)
        }
    }

    private func load(_ id: RecentFile.ID?) {
        file = nil
        guard let id else { return }
        do {
            file = try MarkdownFile(url: recents.url(for: id))
        } catch {
            let name = recents.files.first { $0.id == id }?.name ?? "File"
            failure = Failure(title: "Couldn't Open \(name)", message: "It may have been moved, renamed or deleted. \(error.localizedDescription)", recent: id)
            selection = nil
        }
    }
}

enum Chrome { case mac, phone, rail }

struct SidebarToggle {
    let hidden: Bool
    let toggle: () -> Void
}

private struct Failure {
    let title: String
    let message: String
    var recent: RecentFile.ID?
}

extension UTType {
    static let markdown = UTType(importedAs: "net.daringfireball.markdown")
}

/// Title, search and Open File around the recents list, placed per platform.
private struct SidebarChrome: ViewModifier {
    let chrome: Chrome
    let collapsed: Bool
    @Binding var query: String
    let openFile: () -> Void

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .searchable(text: $query, placement: .sidebar, prompt: "Search recents")
            .navigationSplitViewColumnWidth(min: 220, ideal: 264, max: 360)
        #else
        content
            .navigationTitle("Recents")
            .searchable(text: $query, placement: chrome == .rail ? .navigationBarDrawer(displayMode: .always) : .automatic, prompt: "Search")
            .toolbar(removing: chrome == .rail ? .sidebarToggle : nil)
            .toolbar {
                if chrome == .phone && collapsed {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Open File", systemImage: "folder.badge.plus", action: openFile).tint(.accentColor)
                    }
                }
            }
            .safeAreaInset(edge: .trailing, spacing: 0) {
                if chrome == .rail && collapsed {
                    VStack {
                        Spacer()
                        RailButton("Open File", systemImage: "folder.badge.plus", tint: .accentColor, action: openFile)
                    }
                    .padding(10)
                }
            }
        #endif
    }
}

private struct RecentsList: View {
    let groups: [RecentGroup]
    @Binding var selection: RecentFile.ID?
    let query: String
    let chrome: Chrome

    var body: some View {
        List(selection: $selection) {
            ForEach(groups) { group in
                Section(group.title) {
                    ForEach(group.files) { file in
                        if chrome == .phone {
                            NavigationLink(value: file.id) { RecentRow(file: file, chrome: chrome) }
                        } else {
                            RecentRow(file: file, chrome: chrome)
                        }
                    }
                }
            }
        }
        .overlay {
            if groups.isEmpty {
                if query.isEmpty {
                    ContentUnavailableView("No Recent Files", systemImage: "doc.text", description: Text("Markdown files you open appear here."))
                } else {
                    Text("No recent file matches “\(query)”.").foregroundStyle(.secondary).padding()
                }
            }
        }
    }
}

private struct RecentRow: View {
    let file: RecentFile
    let chrome: Chrome

    var body: some View {
        HStack(spacing: 12) {
            if chrome != .mac {
                Image(systemName: "doc.text").font(.title3).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: chrome == .phone ? 2 : 1) {
                Text(file.name).font(nameFont)
                Text(verbatim: file.folder)
                    .font(detailFont)
                    .foregroundStyle(.secondary)
                    .truncationMode(.head)
            }
            .lineLimit(1)
        }
        .padding(.vertical, chrome == .mac ? 2 : 4)
        #if os(macOS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(Text(verbatim: file.path))
        #endif
    }

    private var nameFont: Font {
        switch chrome {
        case .mac: .body.weight(.medium)
        case .rail: .subheadline.weight(.medium)
        case .phone: .body
        }
    }

    private var detailFont: Font { chrome == .mac ? .subheadline : .footnote }
}
