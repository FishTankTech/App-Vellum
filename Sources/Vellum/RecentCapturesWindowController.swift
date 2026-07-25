import Cocoa

struct CaptureEntry {
    let timestamp: String
    let preview: String
}

class RecentCapturesWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private var entries: [CaptureEntry] = []

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Recent Captures"
        window.center()
        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.title = "Captures"
        column.width = 380
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 44
        tableView.target = self
        tableView.doubleAction = #selector(openNotesFile)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    func loadEntries() {
        let fileURL = PreferencesManager.shared.storageFolder.appendingPathComponent("notes.md")
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            entries = []
            tableView.reloadData()
            return
        }

        let sessions = content.components(separatedBy: "\n\n## ")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        var parsed: [CaptureEntry] = []
        for session in sessions {
            let lines = session.components(separatedBy: "\n")
            guard let timestampLine = lines.first else { continue }
            let body = lines.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }
            let preview = String(body.prefix(80))
            parsed.append(CaptureEntry(timestamp: timestampLine.trimmingCharacters(in: .whitespaces), preview: preview))
        }

        entries = parsed.reversed() // most recent first
        tableView.reloadData()
    }

    @objc private func openNotesFile() {
        let fileURL = PreferencesManager.shared.storageFolder.appendingPathComponent("notes.md")
        NSWorkspace.shared.open(fileURL)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let entry = entries[row]
        let identifier = NSUserInterfaceItemIdentifier("captureCell")

        let cellView: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cellView = reused
        } else {
            cellView = NSTableCellView()
            cellView.identifier = identifier

            let timestampLabel = NSTextField(labelWithString: "")
            timestampLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
            timestampLabel.textColor = .secondaryLabelColor
            timestampLabel.tag = 1
            timestampLabel.translatesAutoresizingMaskIntoConstraints = false

            let previewLabel = NSTextField(labelWithString: "")
            previewLabel.font = NSFont.systemFont(ofSize: 12)
            previewLabel.lineBreakMode = .byTruncatingTail
            previewLabel.tag = 2
            previewLabel.translatesAutoresizingMaskIntoConstraints = false

            cellView.addSubview(timestampLabel)
            cellView.addSubview(previewLabel)

            NSLayoutConstraint.activate([
                timestampLabel.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 8),
                timestampLabel.topAnchor.constraint(equalTo: cellView.topAnchor, constant: 4),
                previewLabel.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 8),
                previewLabel.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8),
                previewLabel.topAnchor.constraint(equalTo: timestampLabel.bottomAnchor, constant: 2)
            ])
        }

        (cellView.viewWithTag(1) as? NSTextField)?.stringValue = entry.timestamp
        (cellView.viewWithTag(2) as? NSTextField)?.stringValue = entry.preview

        return cellView
    }
}