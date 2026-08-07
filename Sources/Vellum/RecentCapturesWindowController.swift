// RecentCapturesWindowController.swift

import Cocoa

enum CaptureFileSelection: Equatable {
    case all
    case file(String)

    var displayName: String {
        switch self {
        case .all: return "All Notes"
        case .file(let name): return name
        }
    }
}

struct CaptureEntry {
    let timestamp: String
    let preview: String
    let sourceFilename: String
}

class RecentCapturesWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private var entries: [CaptureEntry] = []
    private var currentSelection: CaptureFileSelection = .file("notes.md")

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
        tableView.doubleAction = #selector(openSelectedEntry)

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

    /// Loads captures for the given selection — either a single file, or
    /// "All Notes", which merges every known capture file chronologically.
    func loadEntries(for selection: CaptureFileSelection) {
        currentSelection = selection
        window?.title = "Recent Captures — \(selection.displayName)"

        switch selection {
        case .file(let filename):
            entries = loadCaptures(from: filename)
                .map {
                    CaptureEntry(
                        timestamp: $0.timestampString,
                        preview: String($0.body.prefix(80)),
                        sourceFilename: filename
                    )
                }
                .reversed()

        case .all:
            var merged: [(capture: ParsedCapture, source: String)] = []

            for filename in CaptureFileCatalog.availableFiles() {
                merged += loadCaptures(from: filename).map { ($0, filename) }
            }

            merged.sort { $0.capture.date > $1.capture.date }

            entries = merged.map {
                CaptureEntry(
                    timestamp: $0.capture.timestampString,
                    preview: String($0.capture.body.prefix(80)),
                    sourceFilename: $0.source
                )
            }
        }

        tableView.reloadData()
    }

    private func loadCaptures(from filename: String) -> [ParsedCapture] {
        let fileURL = PreferencesManager.shared.storageFolder.appendingPathComponent(filename)
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }
        return NotesParser.parseCaptures(from: content)
    }

    @objc private func openSelectedEntry() {
        let row = tableView.clickedRow
        guard row >= 0, row < entries.count else {
            return
        }

        let fileURL = PreferencesManager.shared.storageFolder
            .appendingPathComponent(entries[row].sourceFilename)

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

            let sourceLabel = NSTextField(labelWithString: "")
            sourceLabel.font = NSFont.systemFont(ofSize: 10)
            sourceLabel.textColor = .tertiaryLabelColor
            sourceLabel.alignment = .right
            sourceLabel.lineBreakMode = .byTruncatingHead
            sourceLabel.tag = 3
            sourceLabel.translatesAutoresizingMaskIntoConstraints = false

            cellView.addSubview(timestampLabel)
            cellView.addSubview(previewLabel)
            cellView.addSubview(sourceLabel)

            NSLayoutConstraint.activate([
                timestampLabel.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 8),
                timestampLabel.topAnchor.constraint(equalTo: cellView.topAnchor, constant: 4),

                sourceLabel.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8),
                sourceLabel.centerYAnchor.constraint(equalTo: timestampLabel.centerYAnchor),
                sourceLabel.leadingAnchor.constraint(greaterThanOrEqualTo: timestampLabel.trailingAnchor, constant: 8),
                sourceLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 140),

                previewLabel.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 8),
                previewLabel.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8),
                previewLabel.topAnchor.constraint(equalTo: timestampLabel.bottomAnchor, constant: 2)
            ])
        }

        (cellView.viewWithTag(1) as? NSTextField)?.stringValue = entry.timestamp
        (cellView.viewWithTag(2) as? NSTextField)?.stringValue = entry.preview

        let sourceLabel = cellView.viewWithTag(3) as? NSTextField
        if case .all = currentSelection {
            sourceLabel?.stringValue = entry.sourceFilename
            sourceLabel?.isHidden = false
        } else {
            sourceLabel?.isHidden = true
        }

        return cellView
    }
}