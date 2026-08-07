// NotesStorage.swift

import Foundation

/// A live preview of where the current text would be routed, without
/// writing anything. Used to drive the routing-feedback indicator as
/// the user types.
struct RoutingPreview {
    let destinationFilename: String
    let isRecognized: Bool
}

class NotesStorage {
    private let graceInterval: TimeInterval = 120 // 2 minutes

    private let mode: CaptureMode

    init(mode: CaptureMode = .permanent) {
        self.mode = mode
    }

    private var storageFolder: URL {
        let folder = PreferencesManager.shared.storageFolder
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            VellumLog.error("Failed to create storage folder at \(folder.path): \(error.localizedDescription)")
        }
        return folder
    }

    private var defaultFileURL: URL {
        storageFolder.appendingPathComponent("notes.md")
    }

    private var sessionHeader: String = ""
    private var lastSessionText: String = ""
    private var lastDismissDate: Date?

    /// Cache of each destination file's on-disk content as it was before
    /// this session touched it. Populated lazily the first time a given
    /// destination is written to, so a route change can roll the
    /// previous destination back to exactly this.
    private var sessionBaseContentByURL: [URL: String] = [:]

    /// The destination this session is currently writing to. Nil until
    /// the first updateSession() call resolves one.
    private var currentDestinationURL: URL?

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
            // Continue the previous session — header and destination
            // stay as they were; updateSession() will re-resolve routing
            // as the (already-typed) text comes back in.
            return (lastSessionText, true)
        }

        // Fresh session — destination is unknown until routing is
        // resolved on the first updateSession() call.
        sessionBaseContentByURL.removeAll()
        currentDestinationURL = nil
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

        let (destination, body) = destinationAndBody(for: text)

        if destination != currentDestinationURL {
            if let previous = currentDestinationURL {
                // This session no longer belongs in the previous
                // destination — restore it to how it looked before this
                // session wrote anything.
                writeAtomically(baseContent(for: previous), to: previous)
            }
            currentDestinationURL = destination
        }

        let base = baseContent(for: destination)
        let fullContent = base + sessionHeader + body
        writeAtomically(fullContent, to: destination)
    }

    /// Call when the capture panel is dismissed — starts the grace window clock.
    func endSession() {
        lastDismissDate = Date()
        guard mode == .permanent else {
            return
        }
    }

    /// Pure preview of where `text` would currently be routed, with no
    /// side effects — safe to call on every keystroke. Returns nil when
    /// there's no complete tag yet (plain text, or a tag still being
    /// typed), in which case no routing feedback should be shown.
    func routingPreview(for text: String) -> RoutingPreview? {
        guard let (tag, _) = NoteTag.extract(from: text) else {
            return nil
        }

        if let filename = PreferencesManager.shared.tagRoutes[tag] {
            return RoutingPreview(destinationFilename: filename, isRecognized: true)
        } else {
            return RoutingPreview(destinationFilename: "notes.md", isRecognized: false)
        }
    }

    /// Returns the routed destination file and the text to actually save
    /// (tag stripped, if one was found). Falls back to notes.md, using
    /// the text unmodified, when there's no tag or the tag has no
    /// configured route.
    private func destinationAndBody(for text: String) -> (url: URL, body: String) {
        guard let (tag, body) = NoteTag.extract(from: text),
              let filename = PreferencesManager.shared.tagRoutes[tag] else {
            return (defaultFileURL, text)
        }
        return (storageFolder.appendingPathComponent(filename), body)
    }

    private func baseContent(for url: URL) -> String {
        if let cached = sessionBaseContentByURL[url] {
            return cached
        }
        ensureFileExists(at: url)
        let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        sessionBaseContentByURL[url] = content
        return content
    }

    private func ensureFileExists(at url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            let created = FileManager.default.createFile(atPath: url.path, contents: nil)
            if !created {
                VellumLog.error("Failed to create note file at \(url.path)")
            }
        }
    }

    private func writeAtomically(_ content: String, to url: URL) {
        let folder = storageFolder
        let tempURL = folder.appendingPathComponent("notes.tmp-\(UUID().uuidString)")
        do {
            try content.write(to: tempURL, atomically: false, encoding: .utf8)
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        } catch {
            VellumLog.error("Failed to save note to \(url.lastPathComponent): \(error.localizedDescription)")
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