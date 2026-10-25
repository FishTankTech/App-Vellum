# App-Vellum

> **vellum** *(noun)* — a fine, durable writing material traditionally made from prepared animal skin, historically used for manuscripts and important documents.
>
> Like its namesake, Vellum (the app) is designed for capturing thoughts quickly and preserving them with as little friction as possible.

Vellum is a lightweight (macOS) quick-note capture utility. A global hotkey opens a floating input window where text is written to disk instantly—no save step, no app switching, and minimal UI overhead compared to (Apple) "Notes.app" or "Stickies".

## Status

**Work-in-progress.** Current release @ V3.0.0 (STABLE)

## What it does

* **Global hotkey** opens a floating capture window (default `⌥⌘N`). `Esc` dismisses it.
* **Instant autosave** as you type, with optional sound and trackpad haptic confirmation.
* **Scratch paper** via a separate hotkey (default `⇧⌥⌘N`): a capture window that is never written to disk.
* **Inline math:** type something like `340 + 89 * 1.07` and, after an adjustable pause, a live `= 458.23` preview appears beside it.
* **Tag routing:** start a note with `//am` (or any tag you define) to send it to a matching file, e.g. `ActivismMotorsports.md`, instead of `notes.md`.
* **Recent Captures** browser and a **Weekly Digest** with usage stats, exported as Markdown.
* **Minimal UI, minimal overhead:** a native, menu bar-only macOS app with no Dock icon.

## Installation // Usage

### Download

Grab the latest `.dmg` from the [Releases](../../releases) tab, open it, and drag Vellum into your Applications folder.

### Build from source (optional)

Requires macOS 13+ and a Swift 5.9+ toolchain.

```bash
git clone https://github.com/<your-username>/App-Vellum.git
cd App-Vellum
swift build -c release
```

### Using it

Vellum lives in your menu bar. Press `⌥⌘N` to capture, `⇧⌥⌘N` for scratch paper, and `Esc` to dismiss. Hotkeys, notes folder, inline math, and tag routes can all be changed in **Preferences…**, and **Quick Tips** shows your current shortcuts.

Notes are saved as plain Markdown in `~/Vellum/` by default, with a timestamp heading per capture.

## License

GPLv3 — see `LICENSE` for details.