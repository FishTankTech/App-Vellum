import Cocoa

private enum KeyCodeMap {
    private static let names: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[",
        34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 41: ";", 43: ",", 45: "N",
        46: "M", 47: ".", 49: "Space"
    ]
    static func string(for keyCode: UInt16) -> String {
        return names[keyCode] ?? "Key(\(keyCode))"
    }
}

class HotKeyRecorderControl: NSButton {
    private var isRecording = false
    private var monitor: Any?

    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        target = self
        action = #selector(startRecording)
        refreshTitle()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func refreshTitle() {
        if isRecording {
            title = "Press a key combination…"
        } else {
            let mods = PreferencesManager.shared.hotKeyModifiers
            let code = PreferencesManager.shared.hotKeyCode
            var parts = ""
            if mods.contains(.control) { parts += "⌃" }
            if mods.contains(.option) { parts += "⌥" }
            if mods.contains(.shift) { parts += "⇧" }
            if mods.contains(.command) { parts += "⌘" }
            parts += KeyCodeMap.string(for: code)
            title = parts
        }
    }

    @objc private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        refreshTitle()

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let relevantMods: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
            let modifiers = event.modifierFlags.intersection(relevantMods)
            guard !modifiers.isEmpty else { return nil } // require at least one modifier

            self.isRecording = false
            if let monitor = self.monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            PreferencesManager.shared.hotKeyCode = event.keyCode
            PreferencesManager.shared.hotKeyModifiers = modifiers
            self.refreshTitle()
            NotificationCenter.default.post(name: PreferencesManager.hotKeyChangedNotification, object: nil)
            return nil
        }
    }
}

class PreferencesWindowController: NSWindowController {
    private let hotKeyRecorder = HotKeyRecorderControl()
    private let storagePathLabel = NSTextField(labelWithString: "")

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Vellum Preferences"
        window.center()
        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let hotKeyLabel = NSTextField(labelWithString: "Global Hotkey:")
        let storageLabel = NSTextField(labelWithString: "Notes Folder:")
        let chooseFolderButton = NSButton(title: "Choose…", target: self, action: #selector(chooseFolder))

        storagePathLabel.stringValue = PreferencesManager.shared.storageFolder.path
        storagePathLabel.lineBreakMode = .byTruncatingMiddle
        storagePathLabel.maximumNumberOfLines = 1

        let hotKeyStack = NSStackView(views: [hotKeyLabel, hotKeyRecorder])
        hotKeyStack.orientation = .horizontal
        hotKeyStack.spacing = 8

        let storageStack = NSStackView(views: [storageLabel, storagePathLabel, chooseFolderButton])
        storageStack.orientation = .horizontal
        storageStack.spacing = 8

        let mainStack = NSStackView(views: [hotKeyStack, storageStack])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 16
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24)
        ])
    }

    @objc private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.directoryURL = PreferencesManager.shared.storageFolder

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            PreferencesManager.shared.storageFolder = url
            self?.storagePathLabel.stringValue = url.path
        }
    }
}