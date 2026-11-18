# emdee

A Markdown viewer and plain-text editor for Mac, iPad, and iPhone. Open a UTF-8 `.md` or `.markdown` file in Finder or Files. Existing notes open in preview; a new document starts blank in the editor.

## Run it

1. Open `emdee.xcodeproj` in Xcode 16 or later.
2. Choose **My Mac** or an iPhone or iPad simulator, then press **Command-R**.

To run on a physical iPhone or iPad, choose your signing team in the app target. The minimum versions are macOS 14 and iOS/iPadOS 17.

## Try it

Open this README in emdee. Choose **Edit** to see its source, then **Preview** to read it again. With a keyboard, **Shift-Command-E** switches modes. The system handles opening and saving; the file stays plain Markdown.

The preview supports headings, emphasis, links, lists, quotes, and fenced code. It does not render HTML, images, or tables. Editing keeps their source intact.

Run the document and preview checks on a Mac:

```sh
./Checks/run.sh
```
