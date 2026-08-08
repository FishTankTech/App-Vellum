// QuickTipsWindowController.swift

import Cocoa

class QuickTipsWindowController: NSWindowController {

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Quick Tips"
        window.center()
        self.init(window: window)
        setupUI()
    }

    private struct Tip {
        let key: String
        let description: String
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let rows: [NSView] = Self.currentTips().map { tip in
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 10
            row.alignment = .firstBaseline

            let keyLabel = NSTextField(labelWithString: tip.key)
            keyLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
            keyLabel.textColor = .labelColor
            keyLabel.alignment = .right
            keyLabel.widthAnchor.constraint(equalToConstant: 100).isActive = true

            let descriptionLabel = NSTextField(labelWithString: tip.description)
            descriptionLabel.font = NSFont.systemFont(ofSize: 12)
            descriptionLabel.textColor = .secondaryLabelColor
            descriptionLabel.lineBreakMode = .byWordWrapping
            descriptionLabel.maximumNumberOfLines = 2
            descriptionLabel.preferredMaxLayoutWidth = 170

            row.addArrangedSubview(keyLabel)
            row.addArrangedSubview(descriptionLabel)

            return row
        }

        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    /// Built fresh every time the window is shown (rather than cached),
    /// so a hotkey rebind in Preferences is always reflected correctly —
    /// there's no stale-state risk to worry about.
    private static func currentTips() -> [Tip] {
        [
            Tip(
                key: hotkeyString(
                    code: PreferencesManager.shared.hotKeyCode,
                    modifiers: PreferencesManager.shared.hotKeyModifiers
                ),
                description: "Open a capture"
            ),
            Tip(
                key: hotkeyString(
                    code: PreferencesManager.shared.scratchHotKeyCode,
                    modifiers: PreferencesManager.shared.scratchHotKeyModifiers
                ),
                description: "Open a scratch capture — never saved to disk"
            ),
            Tip(key: "Esc", description: "Dismiss the capture window"),
            Tip(key: "//TAG note", description: "Routes the note to a tagged file instead of notes.md"),
            Tip(key: "12 * 4", description: "Inline math shows a live result as you type"),
            Tip(key: "—", description: "Everything else saves automatically as you type")
        ]
    }

    private static func hotkeyString(code: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        var parts = ""
        if modifiers.contains(.control) { parts += "⌃" }
        if modifiers.contains(.option) { parts += "⌥" }
        if modifiers.contains(.shift) { parts += "⇧" }
        if modifiers.contains(.command) { parts += "⌘" }
        parts += KeyCodeMap.string(for: code)
        return parts
    }
}