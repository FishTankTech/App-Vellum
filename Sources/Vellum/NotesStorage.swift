import Foundation

class NotesStorage {
    private let graceInterval: TimeInterval = 120 // 2 minutes

    private let mode: CaptureMode

    init(mode: CaptureMode = .permanent) {
        self.mode = mode
    }

    private var fileURL: URL {
        let folder = PreferencesManager.shared.storageFolder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("notes.md")
    }

    private var sessionHeader: String = ""
    private var sessionBaseContent: String = ""
    private var lastSessionText: String = ""
    private var lastDismissDate: Date?

    /// Call when the capture panel opens. Returns the text to pre-fill the
    /// text view with (empty for a fresh session, or the previous session's
    /// text if reopened within the grace window), plus whether this is a
    /// continuation.
    func beginSession() -> (text: String, isContinuing: Bool) {
        if mode == .scratch {
        return ("", false)
        }
        if let lastDismiss = lastDismissDate,
           Date().timeIntervalSince(lastDismiss) < graceInterval,
           !lastSessionText.isEmpty {
            // Continue the previous session — base content and header stay as they were
            return (lastSessionText, true)
        }

        // Fresh session
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        sessionBaseContent = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        let timestamp = DateFormatter.captureHeader.string(from: Date())
        sessionHeader = "\n\n## \(timestamp)\n\n"
        lastSessionText = ""
        return ("", false)
    }

    func updateSession(text: String) {
        guard mode == .permanent else {
        return
        }
        lastSessionText = text
        let fullContent = sessionBaseContent + sessionHeader + text
        writeAtomically(fullContent)
    }

    /// Call when the capture panel is dismissed — starts the grace window clock.
    func endSession() {
        lastDismissDate = Date()
        guard mode == .permanent else {
        return
        }
    }

    private func writeAtomically(_ content: String) {
        let folder = PreferencesManager.shared.storageFolder
        let tempURL = folder.appendingPathComponent("notes.tmp-\(UUID().uuidString)")
        do {
            try content.write(to: tempURL, atomically: false, encoding: .utf8)
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
        } catch {
            print("❌ atomic write failed: \(error)")
            try? FileManager.default.removeItem(at: tempURL)
        }
    }
}

extension DateFormatter {
    static let captureHeader: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}