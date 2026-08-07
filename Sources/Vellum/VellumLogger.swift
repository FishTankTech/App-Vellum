// VellumLogger.swift

import Foundation
import os

/// Central logging for Vellum. Every call writes to both Console.app
/// (via os.Logger — structured, filterable by subsystem/category) and
/// a plain text file at ~/Vellum/vellum.log (easy to attach to a bug
/// report, readable without any tooling).
enum VellumLog {

    private static let osLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Vellum",
        category: "general"
    )

    /// Deliberately fixed at ~/Vellum, independent of the user-configurable
    /// notes storage folder — so logging still works even if the
    /// configured storage folder is missing, unwritable, or the cause
    /// of the very problem being logged.
    private static let logFileURL: URL = {
        let folder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Vellum")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("vellum.log")
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let fileQueue = DispatchQueue(label: "VellumLog.file")

    static func info(_ message: String) {
        osLogger.info("\(message, privacy: .public)")
        writeToFile(level: "INFO", message: message)
    }

    static func error(_ message: String) {
        osLogger.error("\(message, privacy: .public)")
        writeToFile(level: "ERROR", message: message)
    }

    /// For unexpected/unrecoverable conditions — uncaught exceptions,
    /// things that should never happen.
    static func fault(_ message: String) {
        osLogger.fault("\(message, privacy: .public)")
        writeToFile(level: "FAULT", message: message)
    }

    private static func writeToFile(level: String, message: String) {
        fileQueue.async {
            let line = "[\(dateFormatter.string(from: Date()))] [\(level)] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }

            if FileManager.default.fileExists(atPath: logFileURL.path) {
                guard let handle = try? FileHandle(forWritingTo: logFileURL) else { return }
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: logFileURL)
            }
        }
    }
}