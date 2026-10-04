// appdelegate.swift

import Cocoa
import HotKey

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var panel: NSPanel?
    var scratchPanel: NSPanel?
    var hotKey: HotKey?
    var scratchHotKey: HotKey?
    var statusItem: NSStatusItem?
    var preferencesWindowController: PreferencesWindowController?
    var recentCapturesWindowController: RecentCapturesWindowController?
    var digestWindowController: DigestWindowController?
    var quickTipsWindowController: QuickTipsWindowController?

    private let recentCapturesSubmenu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {

        NSSetUncaughtExceptionHandler { exception in
            VellumLog.fault(
                "Uncaught exception: \(exception.name.rawValue) — \(exception.reason ?? "no reason")\n"
                + exception.callStackSymbols.joined(separator: "\n")
            )
        }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        VellumLog.info("Vellum launched (version \(version))")
        VellumLog.info("Storage folder: \(PreferencesManager.shared.storageFolder.path)")

        registerHotKey()
        registerScratchHotKey()
        setupStatusItem()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotKeyPreferencesChanged),
            name: PreferencesManager.hotKeyChangedNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scratchHotKeyPreferencesChanged),
            name: PreferencesManager.scratchHotKeyChangedNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        VellumLog.info("Vellum quitting")
    }

    @objc private func hotKeyPreferencesChanged() {
        registerHotKey()
    }

    @objc private func scratchHotKeyPreferencesChanged() {
        registerScratchHotKey()
    }

    func registerHotKey() {
        let code = PreferencesManager.shared.hotKeyCode
        let modifiers = PreferencesManager.shared.hotKeyModifiers
        guard let key = Key(carbonKeyCode: UInt32(code)) else {
            VellumLog.error("Failed to register hotkey: unrecognized key code \(code)")
            return
        }

        hotKey = HotKey(key: key, modifiers: modifiers)
        hotKey?.keyDownHandler = { [weak self] in
            self?.togglePanel()
        }

        VellumLog.info("Hotkey registered (key code \(code))")
    }

    func registerScratchHotKey() {
        let code = PreferencesManager.shared.scratchHotKeyCode
        let modifiers = PreferencesManager.shared.scratchHotKeyModifiers
        guard let key = Key(carbonKeyCode: UInt32(code)) else {
            VellumLog.error("Failed to register scratch hotkey: unrecognized key code \(code)")
            return
        }

        scratchHotKey = HotKey(key: key, modifiers: modifiers)
        scratchHotKey?.keyDownHandler = { [weak self] in
            self?.toggleScratchPanel()
        }

        VellumLog.info("Scratch hotkey registered (key code \(code))")
    }

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let iconURL = Bundle.module.url(forResource: "menubar-icon", withExtension: "png")

        if let iconURL = iconURL,
           let image = NSImage(contentsOf: iconURL) {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            statusItem?.button?.image = image
        } else {
            statusItem?.button?.title = "V"
        }

        let menu = NSMenu()

        let recentItem = NSMenuItem(title: "Recent Captures", action: nil, keyEquivalent: "")
        recentCapturesSubmenu.delegate = self
        recentItem.submenu = recentCapturesSubmenu

        let digestItem = NSMenuItem(title: "Weekly Digest…", action: #selector(openWeeklyDigest), keyEquivalent: "")
        let notesItem = NSMenuItem(title: "Open Notes", action: #selector(openNotesFile), keyEquivalent: "")
        let hintItem = NSMenuItem(title: "Quick Tips", action: #selector(showQuickTips), keyEquivalent: "")
        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: "")
        let creditsItem = NSMenuItem(title: "Credits", action: #selector(showCredits), keyEquivalent: "")
        let quitItem = NSMenuItem(title: "Quit Vellum", action: #selector(quitApp), keyEquivalent: "q")

        digestItem.target = self
        notesItem.target = self
        hintItem.target = self
        prefsItem.target = self
        creditsItem.target = self
        quitItem.target = self

        menu.addItem(recentItem)
        menu.addItem(digestItem)
        menu.addItem(notesItem)
        menu.addItem(hintItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(prefsItem)
        menu.addItem(creditsItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    /// Rebuilds the Recent Captures submenu right before it's shown, so
    /// files that have only just started being written to (a tag used
    /// for the first time, say) show up without needing a relaunch.
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === recentCapturesSubmenu else {
            return
        }

        menu.removeAllItems()

        let allItem = NSMenuItem(title: "All Notes", action: #selector(selectRecentCaptures(_:)), keyEquivalent: "")
        allItem.target = self
        allItem.representedObject = CaptureFileSelection.all
        menu.addItem(allItem)

        menu.addItem(.separator())

        let files = CaptureFileCatalog.availableFiles()

        if files.isEmpty {
            let emptyItem = NSMenuItem(title: "No captures yet", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for filename in files {
                let item = NSMenuItem(title: filename, action: #selector(selectRecentCaptures(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = CaptureFileSelection.file(filename)
                menu.addItem(item)
            }
        }
    }

    @objc func selectRecentCaptures(_ sender: NSMenuItem) {
        guard let selection = sender.representedObject as? CaptureFileSelection else {
            return
        }

        if recentCapturesWindowController == nil {
            recentCapturesWindowController = RecentCapturesWindowController()
        }

        recentCapturesWindowController?.loadEntries(for: selection)
        recentCapturesWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openWeeklyDigest() {
        if digestWindowController == nil {
            digestWindowController = DigestWindowController()
        }

        digestWindowController?.loadDigest()
        digestWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openNotesFile() {
        let fileURL = PreferencesManager.shared.storageFolder.appendingPathComponent("notes.md")
        NSWorkspace.shared.open(fileURL)
    }

    @objc func openPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
        }

        preferencesWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showQuickTips() {
        // Rebuilt every time (not cached) so a hotkey rebind in
        // Preferences is always reflected correctly.
        quickTipsWindowController = QuickTipsWindowController()
        quickTipsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showCredits() {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center

    let credits = NSMutableAttributedString(
        string:
"""
Developed by FishTankTech
FishTankTech.xyz

Reach Out:
MyFishTankTech@gmail.com

Enjoying Vellum?
Support continued development:
ko-fi.com/fishtanktech
""",
        attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraphStyle
        ]
    )

    let string = credits.string as NSString

    credits.addAttribute(
        NSAttributedString.Key.link,
        value: "https://fishtanktech.xyz",
        range: string.range(of: "FishTankTech.xyz")
    )

    credits.addAttribute(
        NSAttributedString.Key.link,
        value: "mailto:MyFishTankTech@gmail.com",
        range: string.range(of: "MyFishTankTech@gmail.com")
    )

    credits.addAttribute(
        NSAttributedString.Key.link,
        value: "https://ko-fi.com/fishtanktech",
        range: string.range(of: "ko-fi.com/fishtanktech")
    )

    NSApp.activate(ignoringOtherApps: true)

    NSApp.orderFrontStandardAboutPanel(options: [
        .credits: credits,
        NSApplication.AboutPanelOptionKey(rawValue: "ApplicationName"): "Vellum",
        NSApplication.AboutPanelOptionKey(rawValue: "ApplicationVersion"): "2.0.1 (S-L)"
    ])
}

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    func togglePanel() {
        if let panel = panel, panel.isVisible {
            (panel as? CapturePanel)?.flushCurrentText()
            (panel as? CapturePanel)?.animateOut {}
        } else {
            showPanel()
        }
    }

    func showPanel() {
        if panel == nil {
            panel = CapturePanel(mode: .permanent)

            (panel as? CapturePanel)?.onRequestDismiss = { [weak self] in
                self?.togglePanel()
            }
        }

        (panel as? CapturePanel)?.centerOnActiveScreen()
        (panel as? CapturePanel)?.beginNewCapture()
        (panel as? CapturePanel)?.showFirstRunHintIfNeeded()
        (panel as? CapturePanel)?.animateIn()

        NSApp.activate(ignoringOtherApps: true)

        (panel as? CapturePanel)?.focusTextView()
    }

    func toggleScratchPanel() {
        if let scratchPanel = scratchPanel, scratchPanel.isVisible {
            (scratchPanel as? CapturePanel)?.flushCurrentText()
            (scratchPanel as? CapturePanel)?.animateOut {}
        } else {
            showScratchPanel()
        }
    }

    func showScratchPanel() {
        if scratchPanel == nil {
            scratchPanel = CapturePanel(mode: .scratch)

            (scratchPanel as? CapturePanel)?.onRequestDismiss = { [weak self] in
                self?.toggleScratchPanel()
            }
        }

        (scratchPanel as? CapturePanel)?.centerOnActiveScreen()
        (scratchPanel as? CapturePanel)?.beginNewCapture()
        (scratchPanel as? CapturePanel)?.animateIn()

        NSApp.activate(ignoringOtherApps: true)

        (scratchPanel as? CapturePanel)?.focusTextView()
    }
}