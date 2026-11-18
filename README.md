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

## Releasing

Push a version tag:

```sh
git tag v0.2.0 && git push origin v0.2.0
```

The Release workflow signs the Mac app with the Zenixbyte LLC Developer ID, notarizes it and attaches `emdee-0.2.0-mac.zip` to a GitHub Release. It also uploads the iOS build to TestFlight. The tag sets the version; the workflow run number sets the build number.

It needs these repository secrets:

| Secret | What it is |
| --- | --- |
| `ASC_KEY_ID` | App Store Connect API key ID (Users and Access › Integrations, Admin role) |
| `ASC_ISSUER_ID` | The issuer ID shown above the keys list |
| `ASC_KEY_P8` | The contents of the downloaded `AuthKey_<ID>.p8` |
| `DEVELOPER_ID_P12` | The Developer ID Application certificate and key, exported as `.p12`, base64-encoded |
| `DEVELOPER_ID_P12_PASSWORD` | The password set when exporting the `.p12` |

TestFlight also needs an App Store Connect app with the bundle ID `app.emdee.editor`.

## Checks

Run the styling, format bar, file and recents checks on a Mac:

```sh
./Checks/run.sh
```
