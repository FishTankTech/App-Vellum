// PreferencesWindowController.swift

import Cocoa

enum KeyCodeMap {
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

/// Which stored hotkey a HotKeyRecorderControl reads from and writes to.
enum HotKeyKind {
    case primary
    case scratch

    var keyCode: UInt16 {
        get {
            switch self {
            case .primary: return PreferencesManager.shared.hotKeyCode
            case .scratch: return PreferencesManager.shared.scratchHotKeyCode
            }
        }
    }

    var modifiers: NSEvent.ModifierFlags {
        switch self {
        case .primary: return PreferencesManager.shared.hotKeyModifiers
        case .scratch: return PreferencesManager.shared.scratchHotKeyModifiers
        }
    }

    func save(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        switch self {
        case .primary:
            PreferencesManager.shared.hotKeyCode = keyCode
            PreferencesManager.shared.hotKeyModifiers = modifiers
        case .scratch:
            PreferencesManager.shared.scratchHotKeyCode = keyCode
            PreferencesManager.shared.scratchHotKeyModifiers = modifiers
        }
    }

    var changedNotification: Notification.Name {
        switch self {
        case .primary: return PreferencesManager.hotKeyChangedNotification
        case .scratch: return PreferencesManager.scratchHotKeyChangedNotification
        }
    }
}

class HotKeyRecorderControl: NSButton {
    private var isRecording = false
    private var monitor: Any?
    private let kind: HotKeyKind

    init(kind: HotKeyKind = .primary) {
        self.kind = kind
        super.init(frame: .zero)
        bezelStyle = .rounded
        target = self
        action = #selector(startRecording)
        refreshTitle()
    }

    required init?(coder: NSCoder) {
        self.kind = .primary
        super.init(coder: coder)
    }

    func refreshTitle() {
        if isRecording {
            title = "Press a key combination…"
        } else {
            let mods = kind.modifiers
            let code = kind.keyCode
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
            self.kind.save(keyCode: event.keyCode, modifiers: modifiers)
            self.refreshTitle()
            NotificationCenter.default.post(name: self.kind.changedNotification, object: nil)
            return nil
        }
    }
}

/// One row of the Tag Routing table.
private struct TagRouteEntry {
    var tag: String
    var filename: String
}

class PreferencesWindowController: NSWindowController {
    private let hotKeyRecorder = HotKeyRecorderControl(kind: .primary)
    private let scratchHotKeyRecorder = HotKeyRecorderControl(kind: .scratch)
    private let storagePathLabel = NSTextField(labelWithString: "")

    private let inlineMathCheckbox = NSButton(checkboxWithTitle: "Show inline math results", target: nil, action: nil)
    private let mathDelaySlider = NSSlider()
    private let mathDelayValueLabel = NSTextField(labelWithString: "")

    private let tagRoutesTableView = NSTableView()
    private let tagRoutesAddRemoveControl = NSSegmentedControl()
    private var tagRouteEntries: [TagRouteEntry] = []

    private let saveSoundCheckbox = NSButton(checkboxWithTitle: "Play sound on save", target: nil, action: nil)
    private let saveHapticCheckbox = NSButton(checkboxWithTitle: "Trackpad haptic on save", target: nil, action: nil)

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 520),
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
        let scratchHotKeyLabel = NSTextField(labelWithString: "Scratch Hotkey:")
        let storageLabel = NSTextField(labelWithString: "Notes Folder:")
        let chooseFolderButton = NSButton(title: "Choose…", target: self, action: #selector(chooseFolder))

        storagePathLabel.stringValue = PreferencesManager.shared.storageFolder.path
        storagePathLabel.lineBreakMode = .byTruncatingMiddle
        storagePathLabel.maximumNumberOfLines = 1

        let hotKeyStack = NSStackView(views: [hotKeyLabel, hotKeyRecorder])
        hotKeyStack.orientation = .horizontal
        hotKeyStack.spacing = 8

        let scratchHotKeyStack = NSStackView(views: [scratchHotKeyLabel, scratchHotKeyRecorder])
        scratchHotKeyStack.orientation = .horizontal
        scratchHotKeyStack.spacing = 8

        let storageStack = NSStackView(views: [storageLabel, storagePathLabel, chooseFolderButton])
        storageStack.orientation = .horizontal
        storageStack.spacing = 8

        // Inline math section
        inlineMathCheckbox.target = self
        inlineMathCheckbox.action = #selector(toggleInlineMath)
        inlineMathCheckbox.state = PreferencesManager.shared.inlineMathEnabled ? .on : .off

        let delayLabel = NSTextField(labelWithString: "Pause before showing result:")

        mathDelaySlider.minValue = PreferencesManager.mathPreviewDelayRange.lowerBound
        mathDelaySlider.maxValue = PreferencesManager.mathPreviewDelayRange.upperBound
        mathDelaySlider.doubleValue = PreferencesManager.shared.mathPreviewDelay
        mathDelaySlider.target = self
        mathDelaySlider.action = #selector(changeMathDelay)
        mathDelaySlider.isContinuous = true
        mathDelaySlider.widthAnchor.constraint(equalToConstant: 160).isActive = true

        mathDelayValueLabel.stringValue = Self.delayString(PreferencesManager.shared.mathPreviewDelay)
        mathDelayValueLabel.textColor = .secondaryLabelColor
        mathDelayValueLabel.widthAnchor.constraint(equalToConstant: 40).isActive = true

        let delayStack = NSStackView(views: [delayLabel, mathDelaySlider, mathDelayValueLabel])
        delayStack.orientation = .horizontal
        delayStack.spacing = 8

        let mathStack = NSStackView(views: [inlineMathCheckbox, delayStack])
        mathStack.orientation = .vertical
        mathStack.alignment = .leading
        mathStack.spacing = 8

        let mainStack = NSStackView(views: [
            hotKeyStack,
            scratchHotKeyStack,
            storageStack,
            mathStack,
            setupTagRoutesSection(),
            setupSaveConfirmationSection()
        ])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 20
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24)
        ])
    }

    // MARK: - Tag Routing

    private func setupTagRoutesSection() -> NSView {

        tagRouteEntries = PreferencesManager.shared.tagRoutes
            .sorted { $0.key < $1.key }
            .map { TagRouteEntry(tag: $0.key, filename: $0.value) }

        let label = NSTextField(labelWithString: "Tag Routing:")

        let tagColumn = NSTableColumn(identifier: .init("tag"))
        tagColumn.title = "Tag"
        tagColumn.width = 70

        let fileColumn = NSTableColumn(identifier: .init("file"))
        fileColumn.title = "File"
        fileColumn.width = 220

        tagRoutesTableView.addTableColumn(tagColumn)
        tagRoutesTableView.addTableColumn(fileColumn)
        tagRoutesTableView.dataSource = self
        tagRoutesTableView.delegate = self
        tagRoutesTableView.usesAlternatingRowBackgroundColors = true
        tagRoutesTableView.rowHeight = 20
        tagRoutesTableView.headerView = NSTableHeaderView()

        let scrollView = NSScrollView()
        scrollView.documentView = tagRoutesTableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.widthAnchor.constraint(equalToConstant: 320).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 110).isActive = true

        tagRoutesAddRemoveControl.segmentCount = 2
        tagRoutesAddRemoveControl.setLabel("+", forSegment: 0)
        tagRoutesAddRemoveControl.setLabel("–", forSegment: 1)
        tagRoutesAddRemoveControl.trackingMode = .momentary
        tagRoutesAddRemoveControl.target = self
        tagRoutesAddRemoveControl.action = #selector(addOrRemoveTagRoute(_:))
        tagRoutesAddRemoveControl.setWidth(30, forSegment: 0)
        tagRoutesAddRemoveControl.setWidth(30, forSegment: 1)

        let hint = NSTextField(labelWithString: "Double-click a cell to rename.")
        hint.font = NSFont.systemFont(ofSize: 10)
        hint.textColor = .tertiaryLabelColor

        let stack = NSStackView(views: [label, scrollView, tagRoutesAddRemoveControl, hint])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        return stack
    }

    @objc private func addOrRemoveTagRoute(_ sender: NSSegmentedControl) {

        if sender.selectedSegment == 0 {
            tagRouteEntries.append(TagRouteEntry(tag: "", filename: ""))
            tagRoutesTableView.reloadData()

            let newRow = tagRouteEntries.count - 1
            tagRoutesTableView.scrollRowToVisible(newRow)
            tagRoutesTableView.editColumn(0, row: newRow, with: nil, select: true)

        } else {
            let row = tagRoutesTableView.selectedRow
            guard row >= 0, row < tagRouteEntries.count else { return }

            tagRouteEntries.remove(at: row)
            tagRoutesTableView.reloadData()
            commitTagRoutes()
        }
    }

    /// Rebuilds the persisted tag → filename dictionary from the current
    /// table rows, skipping any incomplete rows.
    private func commitTagRoutes() {
        var routes: [String: String] = [:]

        for entry in tagRouteEntries {
            guard !entry.tag.isEmpty, !entry.filename.isEmpty else {
                continue
            }
            routes[entry.tag] = entry.filename
        }

        PreferencesManager.shared.tagRoutes = routes
    }

    // MARK: - Save Confirmation

    private func setupSaveConfirmationSection() -> NSView {

        let label = NSTextField(labelWithString: "Save Confirmation:")

        saveSoundCheckbox.target = self
        saveSoundCheckbox.action = #selector(toggleSaveSound)
        saveSoundCheckbox.state = PreferencesManager.shared.saveSoundEnabled ? .on : .off

        saveHapticCheckbox.target = self
        saveHapticCheckbox.action = #selector(toggleSaveHaptic)
        saveHapticCheckbox.state = PreferencesManager.shared.saveHapticEnabled ? .on : .off

        let stack = NSStackView(views: [label, saveSoundCheckbox, saveHapticCheckbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4

        return stack
    }

    @objc private func toggleSaveSound() {
        PreferencesManager.shared.saveSoundEnabled = saveSoundCheckbox.state == .on
    }

    @objc private func toggleSaveHaptic() {
        PreferencesManager.shared.saveHapticEnabled = saveHapticCheckbox.state == .on
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

    @objc private func toggleInlineMath() {
        PreferencesManager.shared.inlineMathEnabled = inlineMathCheckbox.state == .on
    }

    @objc private func changeMathDelay() {
        PreferencesManager.shared.mathPreviewDelay = mathDelaySlider.doubleValue
        mathDelayValueLabel.stringValue = Self.delayString(PreferencesManager.shared.mathPreviewDelay)
    }

    private static func delayString(_ value: Double) -> String {
        String(format: "%.2fs", value)
    }
}

extension PreferencesWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        tagRouteEntries.count
    }
}

extension PreferencesWindowController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let identifier = tableColumn?.identifier else {
            return nil
        }

        let entry = tagRouteEntries[row]

        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.font = NSFont.systemFont(ofSize: 12)
        field.delegate = self

        if identifier.rawValue == "tag" {
            field.stringValue = entry.tag
        } else {
            field.stringValue = entry.filename
        }

        return field
    }
}

extension PreferencesWindowController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else {
            return
        }

        let row = tagRoutesTableView.row(for: field)
        let column = tagRoutesTableView.column(for: field)

        guard row >= 0, row < tagRouteEntries.count, column >= 0 else {
            return
        }

        let value = field.stringValue.trimmingCharacters(in: .whitespaces)

        if column == 0 {
            tagRouteEntries[row].tag = value.lowercased()
        } else {
            // Keep destinations confined to the storage folder — strip
            // any path components the user might type, per spec.
            tagRouteEntries[row].filename = (value as NSString).lastPathComponent
        }

        commitTagRoutes()
    }
}