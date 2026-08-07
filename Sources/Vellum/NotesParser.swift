// NotesParser.swift

import Foundation

struct ParsedCapture {
    let date: Date
    let timestampString: String
    let body: String
}

enum NotesParser {
    static func parseCaptures(from content: String) -> [ParsedCapture] {
        let sessions = content.components(separatedBy: "\n\n## ")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        var results: [ParsedCapture] = []
        for session in sessions {
            let lines = session.components(separatedBy: "\n")
            guard let timestampLine = lines.first else { continue }
            let timestampString = timestampLine.trimmingCharacters(in: .whitespaces)
            guard let date = DateFormatter.captureHeader.date(from: timestampString) else { continue }
            let body = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }
            results.append(ParsedCapture(date: date, timestampString: timestampString, body: body))
        }
        return results
    }
}

enum NoteTag {
    /// If `text` begins with `//tag` followed by whitespace, returns the
    /// lowercased tag and the remaining body with the tag prefix (and the
    /// one separating space/tab) removed. Returns nil if there's no `//`
    /// prefix, or if the tag hasn't been terminated by whitespace yet
    /// (i.e. the user is still mid-typing it) — in that case the text
    /// isn't routable yet and should be treated as untagged for now.
    static func extract(from text: String) -> (tag: String, body: String)? {
        guard text.hasPrefix("//") else {
            return nil
        }

        let afterSlashes = text.dropFirst(2)

        guard let terminatorIndex = afterSlashes.firstIndex(where: { $0.isWhitespace }) else {
            return nil
        }

        let tag = afterSlashes[..<terminatorIndex].lowercased()

        guard !tag.isEmpty else {
            return nil
        }

        var body = afterSlashes[terminatorIndex...]
        body = body.drop { $0 == " " || $0 == "\t" }

        return (tag, String(body))
    }
}

enum CaptureFileCatalog {
    /// Filenames excluded from the picker — generated reports/exports
    /// rather than actual capture logs. Merging these into "All Notes"
    /// would double-count entries already present in their source file.
    private static let excludedFilenames: Set<String> = ["Digest&Specs.md"]

    /// Every markdown capture file currently present in the storage
    /// folder. notes.md sorts first if present, the rest alphabetically.
    /// Reads the folder directly, so a file only shows up here once it
    /// actually has captures in it.
    static func availableFiles() -> [String] {
        let folder = PreferencesManager.shared.storageFolder

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        let mdFiles = contents
            .map { $0.lastPathComponent }
            .filter { $0.hasSuffix(".md") && !excludedFilenames.contains($0) }

        let notes = mdFiles.filter { $0 == "notes.md" }
        let others = mdFiles.filter { $0 != "notes.md" }.sorted()

        return notes + others
    }
}