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