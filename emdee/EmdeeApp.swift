import MarkdownEngine
import SwiftUI

@main
struct EmdeeApp: App {
    @State private var recents = Recents()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(recents)
        }
        .commands {
            AppCommands()
            #if os(macOS)
            UpdateCommands()
            #endif
        }
        #if os(macOS)
        .defaultSize(width: 1280, height: 800)
        #endif
    }
}

extension FocusedValues {
    @Entry var importing: Binding<Bool>?
    @Entry var file: MarkdownFile?
    @Entry var editor: MarkdownEditorController?
}

private struct AppCommands: Commands {
    @FocusedBinding(\.importing) private var importing
    @FocusedValue(\.file) private var file
    @FocusedValue(\.editor) private var editor

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open…") { importing = true }
                .keyboardShortcut("o")
                .disabled(importing == nil)
        }
        CommandMenu("Format") {
            ForEach(MarkdownFormat.allCases) { action in
                Button(action.label) {
                    if let file, let editor { action.perform(on: editor, in: file.text) }
                }
                .keyboardShortcut(action.shortcut)
                .disabled(file == nil || editor == nil)
            }
        }
    }
}
