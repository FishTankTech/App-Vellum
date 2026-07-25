import Cocoa
import HotKey

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel?
    var hotKey: HotKey?
    var statusItem: NSStatusItem?
    var preferencesWindowController: PreferencesWindowController?
    var recentCapturesWindowController: RecentCapturesWindowController?
    var digestWindowController: DigestWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerHotKey()
        setupStatusItem()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotKeyPreferencesChanged),
            name: PreferencesManager.hotKeyChangedNotification,
            object: nil
        )
    }

    @objc private func hotKeyPreferencesChanged() {
        registerHotKey()
    }

    func registerHotKey() {
        let code = PreferencesManager.shared.hotKeyCode
        let modifiers = PreferencesManager.shared.hotKeyModifiers
        guard let key = Key(carbonKeyCode: UInt32(code)) else { return }

        hotKey = HotKey(key: key, modifiers: modifiers)
        hotKey?.keyDownHandler = { [weak self] in
            self?.togglePanel()
        }
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

        let recentItem = NSMenuItem(title: "Recent Captures…", action: #selector(openRecentCaptures), keyEquivalent: "")
        let digestItem = NSMenuItem(title: "Weekly Digest…", action: #selector(openWeeklyDigest), keyEquivalent: "")
        let notesItem = NSMenuItem(title: "Open Notes", action: #selector(openNotesFile), keyEquivalent: "")
        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        let creditsItem = NSMenuItem(title: "Credits", action: #selector(showCredits), keyEquivalent: "")
        let quitItem = NSMenuItem(title: "Quit Vellum", action: #selector(quitApp), keyEquivalent: "q")

        recentItem.target = self
        digestItem.target = self
        notesItem.target = self
        prefsItem.target = self
        creditsItem.target = self
        quitItem.target = self

        menu.addItem(recentItem)
        menu.addItem(digestItem)
        menu.addItem(notesItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(prefsItem)
        menu.addItem(creditsItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc func openRecentCaptures() {
        if recentCapturesWindowController == nil {
            recentCapturesWindowController = RecentCapturesWindowController()
        }

        recentCapturesWindowController?.loadEntries()
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
        NSApplication.AboutPanelOptionKey(rawValue: "ApplicationVersion"): "1.4.0 (Public)"
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
            panel = CapturePanel()

            (panel as? CapturePanel)?.onRequestDismiss = { [weak self] in
                self?.togglePanel()
            }
        }

        (panel as? CapturePanel)?.centerOnActiveScreen()
        (panel as? CapturePanel)?.beginNewCapture()
        (panel as? CapturePanel)?.animateIn()

        NSApp.activate(ignoringOtherApps: true)

        (panel as? CapturePanel)?.focusTextView()
    }
}