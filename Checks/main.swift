import Foundation

let bytes = Data("# Café\r\n\r\n- *First*\r\n- Second\r\n".utf8)
let document = try MarkdownDocument(data: bytes)
precondition(Data(document.text.utf8) == bytes, "Opening a file must preserve its source")
precondition((try? MarkdownDocument(data: Data([0xFF]))) == nil, "Refuse invalid UTF-8 rather than replacing bytes")
let blocks = MarkdownBlock.parse(document.text)
precondition(blocks.map { String($0.text.characters) } == ["Café", "First", "Second"])
precondition(blocks.first?.heading == 1 && blocks.compactMap(\.marker) == ["•", "•"])
print("Document and preview checks passed.")
