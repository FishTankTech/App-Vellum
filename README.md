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

## Editing your notes

Vellum saves plain Markdown, so any editor can open your notes. These are free, purpose-built Markdown editors that work well with Vellum's output, grouped by use case.

| Use case | Editor | License | Notes |
| --- | --- | --- | --- |
| **Everyday / general** | [VS Code](https://code.visualstudio.com/) | Free (MIT source, Microsoft build) | Open `~/Vellum/` as a folder for full-text search across every note. Built-in preview (`⇧⌘V`). Best if you already live in a code editor. |
| **Writing-focused** | [MarkText](https://github.com/marktext/marktext) | MIT | Live-rendered editing with source, typewriter and focus modes. *Works, but dormant* (see below). |
| **Long-form & research** | [Zettlr](https://www.zettlr.com/) | GPLv3 | Actively maintained. Workspaces, citations, Zettelkasten-style linking, export to PDF/Word. |
| **Linked notes / outliner** | [Logseq OG](https://github.com/logseq/logseq) | AGPL-3.0 | Use the **file-based "OG" edition**: the newer database edition stores notes in SQLite, not plain `.md` files. |
| **Simple split-pane preview** | [MacDown 3000](https://github.com/fluxa/macdown-evo) | MIT | Lightweight native macOS editor with live preview. Continues the original MacDown, which is *works, but dormant*. |

### Tips for Vellum notes

* **Open the whole folder, not single files.** Point your editor at `~/Vellum/` (or your custom notes folder) to search and browse every note at once.
* **Timestamp headings double as an outline.** Each capture starts with a heading, so the outline or table-of-contents pane in most editors becomes a quick timeline.
* **Tag routes are just files.** A note routed with `//am` lands in its own file (e.g. `ActivismMotorsports.md`) and shows up as a separate note in your editor's file list.
* **Edit in one place at a time.** Vellum appends to files as you type, so avoid keeping the day's note file open in an editor while capturing, to prevent your editor from overwriting new text on save.

### Works, but dormant

* **MarkText** is stable and usable, but releases have slowed (latest stable is 0.17.x). Its Homebrew cask is deprecated and slated to be disabled, so download it from the [Releases](https://github.com/marktext/marktext/releases) page instead.
* **MacDown** (the original) is no longer actively maintained. **MacDown 3000** is a community continuation (`brew install --cask macdown-3000`).

Status noted as of October 2026; check each project's releases page for current activity.

## License

GPLv3 — see `LICENSE` for details.