// swift-tools-version: 5.9
import PackageDescription

// Core editor from github.com/emdzej/markdownkit at abf548b277fcbc2adb55a2af778ef534da4a7baf.
// emdee omits the optional math and highlighter modules, and customizes folded frontmatter.
let package = Package(
    name: "MarkdownKit", defaultLocalization: "en", platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "MarkdownEngine", type: .dynamic, targets: ["MarkdownEngine"])],
    targets: [
        .target(name: "MarkdownEngineCore", resources: [.process("Resources")]),
        .target(name: "MarkdownEngine", dependencies: ["MarkdownEngineCore"])
    ]
)
