# emdee

A minimal Markdown editor for Mac, iPad and iPhone. There is one view: the source, styled as you type. Type `# ` and the line becomes a heading; wrap a word in `**` and it turns bold. The Markdown marks stay in the text, muted, so the file on disk is exactly what you typed.

Files stay where they are. emdee keeps a list of recently opened files as bookmarks and never copies your notes.

## Run it

1. Open `emdee.xcodeproj` in Xcode 26 or later.
2. Choose **My Mac**, or an iPhone or iPad simulator, and press **Command-R**.

To run on a device, choose your signing team in the app target. emdee needs macOS 26 or iOS/iPadOS 26.

## Use it

- Open a `.md` file with **Open File** (Command-O), from Finder or Files, or from Recents.
- Edits save on their own a second after you stop typing, and again when you switch files or leave the app.
- On iPhone and iPad, a format bar appears while you type: heading, bold, italic, bulleted list, checklist, code and link. On a keyboard, the Format menu has the same actions, with Command-B, Command-I and Command-K.
- On iPad, the iPhone Duo and an iPhone in landscape, the controls sit in a rail on the trailing edge.

Live styling covers headings, bold, italic, strikethrough, inline code, fenced code, links, lists, tasks, quotes and rules. Tables show in monospace so their columns line up. Images and HTML stay as plain text.

## Checks

Run the styling, format bar, file and recents checks on a Mac:

```sh
./Checks/run.sh
```
