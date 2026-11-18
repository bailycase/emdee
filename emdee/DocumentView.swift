import SwiftUI

struct DocumentView: View {
    @Binding var document: MarkdownDocument
    @State private var editing: Bool

    init(document: Binding<MarkdownDocument>) {
        _document = document
        _editing = State(initialValue: document.wrappedValue.text.isEmpty)
    }

    var body: some View {
        Group {
            if editing {
                TextEditor(text: $document.text)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 16)
                    .accessibilityLabel("Markdown source")
                    .frame(maxWidth: 720)
            } else if document.text.isEmpty {
                ContentUnavailableView("Nothing to preview", systemImage: "doc.plaintext", description: Text("Choose Edit to start writing."))
            } else {
                MarkdownPreview(source: document.text)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editing.toggle()
                } label: {
                    if editing { Label("Preview", systemImage: "book") }
                    else { Label("Edit", systemImage: "pencil") }
                }
                .labelStyle(.titleAndIcon)
                .help(editing ? "Preview Markdown" : "Edit Markdown source")
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }
}
