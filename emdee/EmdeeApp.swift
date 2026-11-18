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
}

private struct AppCommands: Commands {
    @FocusedBinding(\.importing) private var importing
    @FocusedValue(\.file) private var file

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open…") { importing = true }
                .keyboardShortcut("o")
                .disabled(importing == nil)
        }
        CommandMenu("Format") {
            ForEach(MarkdownFormat.allCases) { action in
                Button(action.label) { file?.format(action) }
                    .keyboardShortcut(action.shortcut)
                    .disabled(file == nil)
            }
        }
    }
}
