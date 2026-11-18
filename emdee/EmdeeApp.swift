import SwiftUI

@main
struct EmdeeApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            DocumentView(document: file.$document)
        }
        #if os(macOS)
        .defaultSize(width: 740, height: 680)
        #endif
    }
}
