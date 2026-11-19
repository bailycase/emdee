import MarkdownEngine
import SwiftUI

/// One open file, always editable. MarkdownEngine styles the Markdown as it is typed.
struct FileView: View {
    @Bindable var file: MarkdownFile
    let recent: RecentFile?
    let chrome: Chrome
    let openFile: () -> Void
    /// Rail only: back to Recents when the split view is collapsed.
    let back: (() -> Void)?
    /// Rail only: show or hide Recents when the split view is expanded.
    let sidebar: SidebarToggle?

    @Environment(Recents.self) private var recents
    @Environment(\.scenePhase) private var scenePhase
    @State private var saveError: String?
    @State private var margin = Theme.columnPadding
    @State private var controller = MarkdownEditorController()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if chrome == .rail {
                FileHeader(name: file.name, subtitle: subtitle).padding(.horizontal, margin + 5)
            }
            NativeTextViewWrapper(
                text: $file.text,
                configuration: .emdee(margin: margin),
                fontName: MarkdownFontName.system,
                fontSize: Theme.bodySize,
                documentId: file.url.absoluteString,
                controller: controller
            )
            .accessibilityLabel(file.name)
        }
        .padding(.top, chrome == .mac ? 24 : 8)
        // Full-width scrolling with the text held to a centered 680 pt column.
        .onGeometryChange(for: CGFloat.self) { max(Theme.columnPadding, ($0.size.width - Theme.column) / 2) } action: { margin = $0 }
        .task(id: file.revision) {
            try? await Task.sleep(for: .seconds(1))
            if !Task.isCancelled { save() }
        }
        .onDisappear(perform: save)
        .focusedSceneValue(\.file, file)
        .focusedSceneValue(\.editor, controller)
        .onChange(of: scenePhase) { if $1 != .active { save() } }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in save() }
        #endif
        .alert("Couldn't Save \(file.name)", isPresented: Binding { saveError != nil } set: { if !$0 { saveError = nil } }) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
        .modifier(FileChrome(file: file, chrome: chrome, editing: controller.isEditingAnything, endEditing: controller.endEditing, subtitle: subtitle, openFile: openFile, back: back, sidebar: sidebar, format: { $0.perform(on: controller, in: file.text) }))
    }

    /// Mac: "~/Developer/emdee · 77 words". Rail: "~/Developer/emdee · Edited 9:41 AM".
    private var subtitle: String {
        let folder = RecentFile.folder(of: file.url.path)
        if chrome == .rail { return [folder, recent?.when()].compactMap(\.self).joined(separator: " · ") }
        let words = file.wordCount
        return "\(folder) · \(words) \(words == 1 ? "word" : "words")\(file.isDirty ? " · Edited" : "")"
    }

    private func save() {
        guard file.isDirty else { return }
        do {
            try file.save()
            _ = try? recents.record(file.url, edited: true)
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private struct FileHeader: View {
    let name: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.headline)
            Text(subtitle).font(.footnote).foregroundStyle(.secondary)
        }
        .lineLimit(1)
    }
}

/// The toolbar on Mac and iPhone, or the trailing rail on squat windows. While the text has
/// focus on iOS, Done puts the keyboard away and the format bar appears.
private struct FileChrome: ViewModifier {
    let file: MarkdownFile
    let chrome: Chrome
    let editing: Bool
    let endEditing: () -> Void
    let subtitle: String
    let openFile: () -> Void
    let back: (() -> Void)?
    let sidebar: SidebarToggle?
    let format: (MarkdownFormat) -> Void

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .navigationTitle(file.name)
            .navigationSubtitle(subtitle)
            .navigationDocument(file.url)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Open File", systemImage: "folder.badge.plus", action: openFile)
                    ShareLink(item: file.url)
                }
            }
        #else
        if chrome == .rail {
            content
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .trailing, spacing: 0) { rail }
        } else {
            content
                .navigationTitle(file.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if editing {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done", systemImage: "checkmark", action: endEditing).buttonStyle(.glassProminent)
                        }
                    } else {
                        ToolbarItem(placement: .topBarTrailing) {
                            ShareLink(item: file.url) { Label("Share", systemImage: "square.and.arrow.up") }
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if editing {
                        FormatBar(axis: .horizontal, apply: format)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                    }
                }
        }
        #endif
    }

    #if os(iOS)
    private var rail: some View {
        VStack(spacing: 12) {
            if let sidebar {
                RailButton(sidebar.hidden ? "Show Sidebar" : "Hide Sidebar", systemImage: "sidebar.left", action: sidebar.toggle)
            }
            if let back {
                RailButton("Recents", systemImage: "chevron.left", action: back)
            }
            if editing {
                RailButton("Done", systemImage: "checkmark", prominent: true) { endEditing() }
                FormatBar(axis: .vertical, apply: format)
            } else {
                ShareLink(item: file.url) {
                    Image(systemName: "square.and.arrow.up").font(.title3).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Share")
            }
            Spacer()
            RailButton("Open File", systemImage: "folder.badge.plus", tint: .accentColor, action: openFile)
        }
        .padding(10)
    }
    #endif
}

/// A 44 pt glass circle with an icon, for the rail.
struct RailButton: View {
    let title: String
    let systemImage: String
    var tint: Color?
    var prominent = false
    let action: () -> Void

    init(_ title: String, systemImage: String, tint: Color? = nil, prominent: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.prominent = prominent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(prominent ? .semibold : .regular))
                .foregroundStyle(prominent ? AnyShapeStyle(.white) : tint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.primary))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .glassEffect(prominent ? .regular.tint(.accentColor).interactive() : .regular.interactive(), in: .circle)
        .accessibilityLabel(title)
    }
}

/// Heading, bold, italic, lists, code and link, as a glass pill.
private struct FormatBar: View {
    let axis: Axis
    let apply: (MarkdownFormat) -> Void

    var body: some View {
        let layout = axis == .horizontal ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
        layout {
            ForEach(MarkdownFormat.allCases) { action in
                Button { apply(action) } label: {
                    icon(action)
                        .frame(width: 44, height: 44)
                        .frame(maxWidth: axis == .horizontal ? .infinity : nil)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(action.label)
            }
        }
        .padding(axis == .horizontal ? .horizontal : .vertical, 4)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    @ViewBuilder private func icon(_ action: MarkdownFormat) -> some View {
        switch action {
        case .heading: Text(verbatim: "H").font(.title3.bold())
        case .bold: Text(verbatim: "B").font(.title3.bold())
        case .italic: Text(verbatim: "I").font(.system(.title3, design: .serif)).italic()
        case .bulletList: Image(systemName: "list.bullet").font(.title3)
        case .checklist: Image(systemName: "checklist").font(.title3)
        case .code: Image(systemName: "chevron.left.forwardslash.chevron.right").font(.body)
        case .link: Image(systemName: "link").font(.title3)
        }
    }
}
