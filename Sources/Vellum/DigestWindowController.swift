import Cocoa

class DigestWindowController: NSWindowController {
    private let summaryLabel = NSTextField(wrappingLabelWithString: "")
    private let exportButton = NSButton(title: "Export This Week…", target: nil, action: nil)
    private var thisWeekCaptures: [ParsedCapture] = []

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Weekly Digest"
        window.center()

        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        summaryLabel.font = NSFont.systemFont(ofSize: 13)
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false

        exportButton.target = self
        exportButton.action = #selector(exportWeek)
        exportButton.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(summaryLabel)
        contentView.addSubview(exportButton)

        NSLayoutConstraint.activate([
            summaryLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            summaryLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            summaryLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),

            exportButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            exportButton.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 20)
        ])
    }

    func loadDigest() {
        let fileURL = PreferencesManager.shared.storageFolder
            .appendingPathComponent("notes.md")

        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            summaryLabel.stringValue = "No captures found yet."
            exportButton.isEnabled = false
            return
        }

        let allCaptures = NotesParser.parseCaptures(from: content)

        let calendar = Calendar.current
        let now = Date()

        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
            return
        }

        thisWeekCaptures = allCaptures.filter {
            $0.date >= weekAgo && $0.date <= now
        }

        let totalWords = thisWeekCaptures.reduce(0) { total, capture in
            total + capture.body.split(whereSeparator: \.isWhitespace).count
        }

        if thisWeekCaptures.isEmpty {
            summaryLabel.stringValue = "No captures in the last 7 days."
            exportButton.isEnabled = false
        } else {
            let noteWord = thisWeekCaptures.count == 1 ? "note" : "notes"

            summaryLabel.stringValue =
                "You captured \(thisWeekCaptures.count) \(noteWord) this week (\(totalWords) words total)."

            exportButton.isEnabled = true

            // Automatically update the Markdown report.
            exportWeek()
        }
    }

    @objc
    private func exportWeek() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let outputURL = PreferencesManager.shared.storageFolder
            .appendingPathComponent("Digest&Specs.md")

        var output = """
# Weekly Capture Digest

Generated: \(formatter.string(from: Date()))

"""

        if thisWeekCaptures.isEmpty {
            output += "_No captures this week._\n"
        } else {
            for capture in thisWeekCaptures {
                output += """
## \(capture.timestampString)

\(capture.body)

---

"""
            }
        }

        do {
            try output.write(
                to: outputURL,
                atomically: true,
                encoding: .utf8
            )
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }
}