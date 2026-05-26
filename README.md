# Go Home You're Drunk

A native macOS app for uninstalling applications installed with [Homebrew](https://brew.sh) casks — for people who prefer a GUI over the terminal.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5](https://img.shields.io/badge/Swift-5-orange)
<img width="2024" height="1448" alt="image" src="https://github.com/user-attachments/assets/f8d63165-9954-4d71-ac6d-c1c6d9116e6f" />

## Features

- Lists all installed **Homebrew casks** (GUI apps and other cask packages)
- Search by app name, cask token, or description
- **Update** selected casks (`brew upgrade --cask`)
- Multi-select **uninstall** with optional **--zap**
- **Live log** panel streaming stdout/stderr from brew as commands run
- **Available commands** for the selected cask (info, upgrade, reinstall, outdated, uninstall) with **Copy** and **Run**
- Shows app icons, installed version, and whether an update is available
- Runs the same `brew` commands you would use in Terminal

## Requirements

- macOS 14 (Sonoma) or later
- [Homebrew](https://brew.sh) installed (`brew` on your PATH)
- **Xcode** (from `/Applications/Xcode.app`) to build — Command Line Tools alone are not enough for app icons

## App icon

The project uses **three** icon layers so the Dock icon works on macOS 14/15 and can use Icon Composer on newer Xcode:

| File | Purpose |
|------|---------|
| `AppIcon.icon` | Icon Composer source (renamed from `final.icon`) — Liquid Glass on macOS 26+ when built with Xcode 26 |
| `Assets.xcassets/AppIcon.appiconset` | Classic asset catalog icons (used on macOS 14/15 today) |
| `AppIcon.icns` | Legacy fallback referenced from `Info.plist` |

**Why `final.icon` alone did not show:** Xcode only applies an Icon Composer `.icon` file when the asset catalog compiler runs it together with a matching name (`AppIcon`). This project had no `Assets.xcassets`, so nothing was compiled into `Assets.car` and the system showed the default placeholder icon.

### After pulling these changes

1. Open the project in **Xcode** (not only Command Line Tools).
2. Select target **GoHomeYou'reDrunk** → **General** → set **App Icon** to `AppIcon`.
3. **Product → Clean Build Folder** (⇧⌘K), then **Run** (⌘R).
4. If the Dock still shows the old icon: quit the app, run again, or restart the Dock:
   ```bash
   killall Dock
   ```

### Regenerating PNGs from your Icon Composer artwork

If you edit `AppIcon.icon` in Icon Composer, refresh the bitmap icons:

```bash
./scripts/generate-app-icon.sh
```

Then clean and rebuild in Xcode.

## Build & run

1. Open `GoHomeYou'reDrunk.xcodeproj` in Xcode.
2. Select the **GoHomeYou'reDrunk** scheme and **My Mac** as the destination.
3. Press **⌘R** to build and run.

Or from the command line (requires full Xcode):

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project "GoHomeYou'reDrunk.xcodeproj" \
  -scheme "GoHomeYou'reDrunk" -configuration Release build
```

## Usage

1. Launch **Go Home You're Drunk**.
2. Wait for your installed casks to load.
3. Select one or more apps in the sidebar.
4. Use **Update** or **Uninstall** in the toolbar, or pick a command under **Available commands** in the detail pane.
5. Watch output in the **Live log** at the bottom (toggle with the terminal icon in the toolbar).
6. Optionally enable **Also remove support files (--zap)** before uninstalling from the toolbar.

## How it works

The app shells out to your local `brew` binary (Apple Silicon: `/opt/homebrew/bin/brew`, Intel: `/usr/local/bin/brew`, or whatever `command -v brew` finds). It does not reimplement Homebrew — uninstalls go through the same code path as the CLI.

## License

MIT
