# My Goals

Just a running list of ideas, improvements, and future projects.

---

# Vellum

## Reliability

### Crash / Error Logging

Right now almost every failure just uses `print()`, which is fine while running through `swift-bundler run`, but completely useless once the app is launched normally. If something silently fails (save errors, bad preferences, permission issues, etc.) there's no way to know why.

Need to replace this with actual logging.

Options:

- Apple `Logger` / `os_log`
    - Viewable in Console.app
    - Native solution
    - Structured logging

- Plain text log file
    - `~/Vellum/vellum.log`
    - Easy for users to attach to bug reports

Things worth logging:

- App launch / quit
- Failed saves
- Failed folder creation
- Preference loading
- Hotkey registration
- Unexpected exceptions
- Permission problems

---

### Code Signing

Currently the app only really runs through development.

Once it's copied into `/Applications` or shared with someone else, Gatekeeper will complain because it isn't signed.

Need to start signing builds.

Short term:

```bash
codesign --sign - --deep Vellum.app
```

Long term:

- Developer ID
- Notarization
- Public distribution

---

## UX

### First Run Hint

The app is intentionally minimal, but there should still be a tiny bit of onboarding.

First launch only.

Something like:

```
⌥⌘N to open

Esc to dismiss

Your text saves automatically.
```

Show once.

Fade away.

Never show again.

No dialogs.

No setup wizard.

---

### Save Confirmation

Right now the only confirmation is the "Saved" label.

Would be nice to optionally enable:

- system sound
- trackpad haptic

Off by default.

Useful when you're typing something quickly and dismissing the window without looking at it.

---

## Features

### Inline Math

If the current line looks like math:

```
340 + 89 * 1.07
```

show

```
= 458.23
```

or append

```
340 + 89 * 1.07 = 458.23
```

after a short pause.

Useful for:

- prices
- measurements
- quick estimates
- random calculations

Basically turns Vellum into a scratch calculator without opening Calculator.app.

---

### Voice Capture

Alternative hotkey that immediately starts macOS Dictation.

Workflow:

```
Hotkey

↓

Dictation

↓

Transcription

↓

Save
```

Would be useful while:

- working on a car
- carrying camera gear
- walking
- fabrication work

---

### Tag-Based Note Routing

Probably one of the bigger features.

Instead of dumping everything into `notes.md`, allow notes to be routed to different files with a tag at the beginning.

Example:

```text
//AM brake bias felt off on second run
```

Gets saved to

```
ActivismMotorsports.md
```

Actual saved note:

```text
brake bias felt off on second run
```

The tag is only used for routing - not saved as .md text.

Rules:

- must start with `//`
- case-insensitive
- tag stripped before writing
- everything else works exactly the same

If no tag exists:

```
notes.md
```

just like today.

---

### Tag Preferences

Need a simple mapping table.

| Tag | File |
|------|------|
| AM | ActivismMotorsports.md |
| AP | ActivismPhotography.md |
| FTT | FishTankTech.md |
| BR | CremeanArchives.md |

Should be editable.

Need:

- Add
- Remove
- Rename

All files stay inside the configured storage folder.

---

### Routing Feedback

As soon as a valid tag is detected, show something like

```
→ ActivismMotorsports.md
```

If the tag doesn't exist:

```
→ notes.md
Unknown tag
```

Never silently ignore invalid tags.

---

### Recent Captures

Currently only reads `notes.md`.

Needs a selector.

Something like:

- All Notes
- notes.md
- ActivismMotorsports.md
- FishTankTech.md
- CremeanArchives.md
- MountainMule.md

"All Notes" should merge everything chronologically.

---

### Weekly Digest

Same idea.

Allow selecting:

- All Notes
- Individual files