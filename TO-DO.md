# Vellum — To-Do List

**Concept:** Lightweight macOS quick-note capture utility. Global hotkey → floating input window → instant disk write. No save step, no app switching, minimal UI vs. Notes.app/Stickies.

---

## Phase 0 — Project Setup
- [ ] Create Xcode project (Swift, AppKit or SwiftUI-on-AppKit hybrid — AppKit recommended for a true accessory/floating panel)
- [ ] Set app type to `LSUIElement` (agent app, no Dock icon, no menu bar app window by default)
- [ ] Decide app identity: name, bundle ID, icon placeholder
- [ ] Set up git repo + `.gitignore` (standard Xcode/Swift)
- [ ] Confirm minimum macOS target (e.g., macOS 13+) based on APIs you'll need (global hotkeys, `NSVisualEffectView`, etc.)

## Phase 1 — Core Capture Loop (MVP)
- [ ] Register a global hotkey (e.g., via `Carbon` `RegisterEventHotKey`, or a small wrapper like `HotKey` Swift package)
- [ ] On hotkey press: instantiate and show a floating `NSPanel` (not a full `NSWindow`) with:
  - [ ] `.nonactivatingPanel` style so it doesn't steal focus from current app unnecessarily (decide: should it steal focus for typing? — likely yes, just not switch Spaces/Dock)
  - [ ] Borderless or minimal-chrome style
  - [ ] Always-on-top (`.floating` or `.statusBar` window level)
  - [ ] Centered on active screen, or near cursor — pick one and make it consistent
- [ ] Single `NSTextView`/`NSTextField` inside, auto-focused on show
- [ ] On text change or on a debounce timer, write buffer to disk immediately (no explicit save action)
- [ ] Define storage format/location for captured notes:
  - [ ] One append-only file? (e.g., `~/Vellum/notes.md` or `.txt`)
  - [ ] Or one file per capture session, timestamped (e.g., `~/Vellum/2026-07-23-1432.md`)
  - [ ] Decide now — this affects almost everything downstream (search, editing, sync)
- [ ] Dismiss window on:
  - [ ] `Esc` (discard vs. keep — decide behavior, probably just hides since it's already saved)
  - [ ] Hotkey pressed again (toggle open/close)
  - [ ] Click-away / loss of focus (optional, consider making this configurable)
- [ ] Verify text already typed is retained if the window is dismissed and reopened (session persistence within app lifetime)

## Phase 2 — Reliability & Data Integrity
- [ ] Handle app relaunch / crash recovery — in-progress text should never be lost
- [ ] Atomic writes (write to temp file, then rename) to avoid corruption on crash/power loss
- [ ] Handle edge cases: disk full, permissions error, iCloud Drive sync conflicts (if storing there)
- [ ] Decide and implement note "commit" boundary — i.e., what defines one note vs. a continuation (time gap? explicit hotkey dismiss? new day?)
- [ ] Basic unit tests around the file-writing logic

## Phase 3 — Minimal but Necessary UI Polish
- [ ] Subtle show/hide animation (fast — under ~150ms, this is a utility not a showcase)
- [ ] Light/dark mode support (match system appearance)
- [ ] Reasonable default window size + remember last size/position (or intentionally always reset — decide)
- [ ] Placeholder text state (e.g., "Capture a thought…") when empty
- [ ] Simple visual "saved" indicator (a small dot/checkmark, non-intrusive) since there's no save button to reassure the user
- [ ] Font choice + sizing considered deliberately (this is a writing tool — legibility matters)

## Phase 4 — Menu Bar Presence
- [ ] Optional `NSStatusItem` (menu bar icon) for:
  - [ ] Quick access without the hotkey
  - [ ] Preferences
  - [ ] Quit
  - [ ] "Open notes folder in Finder"
- [ ] Decide: is Vellum *purely* hotkey-driven, or does it need any persistent menu bar footprint? (Affects "minimal overhead" positioning — consider making menu bar icon optional/toggleable)

## Phase 5 — Preferences / Settings
- [ ] Preferences window (simple, single pane to start):
  - [ ] Custom hotkey rebinding
  - [ ] Notes storage location (folder picker)
  - [ ] Storage mode (single file vs. one-per-note)
  - [ ] Launch at login toggle (`SMAppService` on modern macOS)
  - [ ] Window position preference (center screen / near cursor / remember last)
- [ ] Persist preferences via `UserDefaults`

## Phase 6 — Quality-of-Life Capture Features
- [ ] Markdown-aware textview (not full rendering necessarily, just don't fight the user's markdown syntax)
- [ ] Paste support for plain text (strip rich formatting by default — keep it lightweight)
- [ ] Multi-line support with sane `Return` behavior (new line vs. dismiss-and-save — probably `Return` = new line, hotkey/Esc = dismiss)
- [ ] Optional: timestamp auto-inserted per capture session
- [ ] Optional: quick "new note" vs. "append to last note if opened within N minutes" logic

## Phase 7 — Retrieval (even a minimal capture tool needs some way back in)
- [ ] "Open notes folder" action (Finder)
- [ ] Optional lightweight in-app history/browse view (list of recent captures, read-only, opens externally to edit)
- [ ] Optional Spotlight-friendly storage (plain `.md`/`.txt` files are already Spotlight-searchable — lean on this instead of building your own search)

## Phase 8 — Permissions & System Integration
- [ ] Handle Accessibility/Input Monitoring permission prompts required for global hotkeys (macOS will require this — surface a clear explanation to the user, not just a raw system dialog)
- [ ] Graceful first-run onboarding: explain hotkey, permission request, storage location
- [ ] Code signing + notarization plan (required for distribution outside Mac App Store)

## Phase 9 — Distribution
- [ ] Decide distribution channel: direct download (notarized .dmg) vs. Mac App Store (App Store has restrictions on `LSUIElement`/global hotkeys via Accessibility API — research entitlements needed)
- [ ] Build a minimal landing page (this fits naturally under FishTankTech's design system if you want to ship it under that umbrella)
- [ ] Auto-update mechanism if distributing outside the App Store (e.g., Sparkle framework)
- [ ] Versioning + changelog convention

## Phase 10 — Nice-to-Haves (post-MVP, don't build these first)
- [ ] iCloud/Dropbox sync awareness (if storing in synced folder, handle conflict resolution)
- [ ] Tagging or folder routing based on simple syntax (e.g., `#tag` at start of note)
- [ ] Export/archive tools (e.g., "export today's captures as one file")
- [ ] Multiple hotkey "modes" (e.g., one hotkey for quick note, another for quick task/todo)
- [ ] Shortcuts.app / AppleScript support for automation

---

## Suggested Build Order (if you want a straight line to something usable)
1. Phase 0 → Phase 1 (get a hotkey opening a window that saves text to one file — this alone is a usable v0.1)
2. Phase 2 (don't skip this — data loss kills trust in a capture tool immediately)
3. Phase 3 (make it pleasant enough to actually reach for over Notes.app)
4. Phase 5 (hotkey rebinding is probably the first thing power users ask for)
5. Everything else is genuinely optional depending on how far you want to take it
