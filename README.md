# emdee

A minimal Markdown editor for Mac, iPad and iPhone. There is one view: the source, styled as you type. Type `# ` and the line becomes a heading; wrap a word in `**` and it turns bold. The Markdown marks stay in the text, muted, so the file on disk is exactly what you typed.

Files stay where they are. emdee keeps a list of recently opened files as bookmarks and never copies your notes.

## Run it

Open `emdee.xcodeproj` in Xcode 26 or later, pick a scheme, choose a destination and press **Command-R**.

| Scheme | Config | Mac bundle id | Updates |
| --- | --- | --- | --- |
| `emdee (Dev)` | Debug | `com.bailycase.emdee.dev` | never |
| `emdee (Prod)` | Release | `com.bailycase.emdee` | Sparkle |

The iPhone and iPad app is `com.bailycase.emdee.ios` in both. Dev has its own bundle id so its preferences, recents and sandbox container never touch the installed app's. emdee needs macOS 26 or iOS/iPadOS 26; the Mac app is Apple silicon only.

## Use it

- Open a `.md` file with **Open File** (Command-O), from Finder or Files, or from Recents.
- Edits save on their own a second after you stop typing, and again when you switch files or leave the app.
- On iPhone and iPad, a format bar appears while you type: heading, bold, italic, bulleted list, checklist, code and link. On a keyboard, the Format menu has the same actions, with Command-B, Command-I and Command-K.
- On iPad, the iPhone Duo and an iPhone in landscape, the controls sit in a rail on the trailing edge.

Live styling covers headings, bold, italic, strikethrough, inline code, fenced code, links, lists, tasks, quotes and rules. Tables show in monospace so their columns line up. Images and HTML stay as plain text.

## Releasing

Releases work as Shepherd's do, with one app and one stable channel. Push a version tag:

```sh
git tag v0.2.0 && git push origin v0.2.0
```

The Release workflow builds the Mac app arm64-only, signs it inside-out with the Zenixbyte LLC Developer ID (`scripts/sign-app.sh`), notarizes it, and attaches `emdee.dmg` to a GitHub Release. It then points the Sparkle feed, `appcast.xml` on `gh-pages` (https://bailycase.github.io/emdee/appcast.xml), at that DMG. Installed copies find it on their next check, or with **emdee › Check for Updates…**. The same tag uploads the iPhone and iPad app to TestFlight; `gh workflow run release.yml -f testflight=true` uploads one without a Mac release. The tag sets the version and the run number sets the build number. Tags are immutable: a botched release gets the next number.

The TestFlight job archives unsigned and signs at export with the team's cloud-managed Apple Distribution certificate, on the `xcode-27` runner, because the iPhone Duo needs an iOS 27.1 SDK build.

Repository secrets, named as in Shepherd:

| Secret | What it is |
| --- | --- |
| `DEVELOPER_ID_P12`, `DEVELOPER_ID_P12_PASSWORD` | The Developer ID Application certificate and key as a base64 `.p12`, and its password |
| `NOTARY_KEY`, `NOTARY_KEY_ID`, `NOTARY_ISSUER_ID` | App Store Connect API key for `notarytool`: the `.p8` text, its ID, the issuer ID |
| `APP_STORE_CONNECT_KEY_P8`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID` | API key (Admin) for cloud signing and the TestFlight upload; the `.p8` as text, not base64 |
| `SPARKLE_PRIVATE_KEY` | emdee's EdDSA key; its public half is `SUPublicEDKey` in `Config/Info.plist` |

## Checks

Run the styling, format bar, file and recents checks on a Mac:

```sh
./Checks/run.sh
```
