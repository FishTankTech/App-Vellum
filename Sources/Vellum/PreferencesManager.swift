// PreferencesManager.swift

import Cocoa

class PreferencesManager {
    static let shared = PreferencesManager()

    private let defaults = UserDefaults.standard
    private let keyCodeKey = "hotKeyCode"
    private let modifiersKey = "hotKeyModifiersRaw"
    private let scratchKeyCodeKey = "scratchHotKeyCode"
    private let scratchModifiersKey = "scratchHotKeyModifiersRaw"
    private let storagePathKey = "storagePath"
    private let inlineMathEnabledKey = "inlineMathEnabled"
    private let mathPreviewDelayKey = "mathPreviewDelay"
    private let tagRoutesKey = "tagRoutes"
    private let hasShownFirstRunHintKey = "hasShownFirstRunHint"
    private let saveSoundEnabledKey = "saveSoundEnabled"
    private let saveHapticEnabledKey = "saveHapticEnabled"

    static let mathPreviewDelayRange: ClosedRange<Double> = 0.15...1.5
    static let defaultMathPreviewDelay: Double = 0.4

    var hotKeyCode: UInt16 {
        get {
            let stored = defaults.object(forKey: keyCodeKey) as? Int
            return UInt16(stored ?? 45) // 45 = "N"
        }
        set { defaults.set(Int(newValue), forKey: keyCodeKey) }
    }

    var hotKeyModifiers: NSEvent.ModifierFlags {
        get {
            let stored = defaults.object(forKey: modifiersKey) as? UInt
            let raw = stored ?? NSEvent.ModifierFlags([.command, .option]).rawValue
            return NSEvent.ModifierFlags(rawValue: raw)
        }
        set { defaults.set(newValue.rawValue, forKey: modifiersKey) }
    }

    /// Key code for the scratch-capture hotkey. Defaults to the same "N"
    /// key as the primary hotkey — the modifier set is what
    /// distinguishes them (⇧⌥⌘N vs ⌥⌘N by default).
    var scratchHotKeyCode: UInt16 {
        get {
            let stored = defaults.object(forKey: scratchKeyCodeKey) as? Int
            return UInt16(stored ?? 45) // 45 = "N"
        }
        set { defaults.set(Int(newValue), forKey: scratchKeyCodeKey) }
    }

    var scratchHotKeyModifiers: NSEvent.ModifierFlags {
        get {
            let stored = defaults.object(forKey: scratchModifiersKey) as? UInt
            let raw = stored ?? NSEvent.ModifierFlags([.command, .option, .shift]).rawValue
            return NSEvent.ModifierFlags(rawValue: raw)
        }
        set { defaults.set(newValue.rawValue, forKey: scratchModifiersKey) }
    }

    var storageFolder: URL {
        get {
            if let path = defaults.string(forKey: storagePathKey) {
                return URL(fileURLWithPath: path)
            }
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Vellum")
        }
        set { defaults.set(newValue.path, forKey: storagePathKey) }
    }

    /// Whether inline math previews (e.g. typing "12 * 3" shows "= 36")
    /// are shown in the capture panel at all.
    var inlineMathEnabled: Bool {
        get { defaults.object(forKey: inlineMathEnabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: inlineMathEnabledKey) }
    }

    /// How long the current line must sit unchanged before an inline math
    /// result is shown. Clamped to `mathPreviewDelayRange` on write.
    var mathPreviewDelay: TimeInterval {
        get {
            let stored = defaults.object(forKey: mathPreviewDelayKey) as? Double
            return stored ?? Self.defaultMathPreviewDelay
        }
        set {
            let clamped = min(max(newValue, Self.mathPreviewDelayRange.lowerBound), Self.mathPreviewDelayRange.upperBound)
            defaults.set(clamped, forKey: mathPreviewDelayKey)
        }
    }

    /// Maps a lowercase tag (the part after `//`, before the tag's
    /// terminating whitespace) to a destination filename within
    /// `storageFolder`. Editable via the Tag Routing table in
    /// Preferences.
    var tagRoutes: [String: String] {
        get {
            guard let data = defaults.data(forKey: tagRoutesKey) else {
                return Self.defaultTagRoutes
            }
            do {
                return try JSONDecoder().decode([String: String].self, from: data)
            } catch {
                VellumLog.error("Failed to load tag routes, using defaults: \(error.localizedDescription)")
                return Self.defaultTagRoutes
            }
        }
        set {
            do {
                let encoded = try JSONEncoder().encode(newValue)
                defaults.set(encoded, forKey: tagRoutesKey)
            } catch {
                VellumLog.error("Failed to save tag routes: \(error.localizedDescription)")
            }
        }
    }

    static let defaultTagRoutes: [String: String] = [
        "am": "ActivismMotorsports.md",
        "ap": "ActivismPhotography.md",
        "ftt": "FishTankTech.md",
        "br": "CremeanArchives.md"
    ]

    /// Whether the one-time onboarding hint has already been shown
    /// automatically. Doesn't gate the "Quick Tips" menu item, which shows
    /// it on demand regardless.
    var hasShownFirstRunHint: Bool {
        get { defaults.bool(forKey: hasShownFirstRunHintKey) }
        set { defaults.set(newValue, forKey: hasShownFirstRunHintKey) }
    }

    /// Plays a short system sound whenever a capture is actually written
    /// to disk. Off by default.
    var saveSoundEnabled: Bool {
        get { defaults.bool(forKey: saveSoundEnabledKey) }
        set { defaults.set(newValue, forKey: saveSoundEnabledKey) }
    }

    /// Triggers a trackpad haptic whenever a capture is actually written
    /// to disk. Off by default.
    var saveHapticEnabled: Bool {
        get { defaults.bool(forKey: saveHapticEnabledKey) }
        set { defaults.set(newValue, forKey: saveHapticEnabledKey) }
    }

    static let hotKeyChangedNotification = Notification.Name("VellumHotKeyChanged")
    static let scratchHotKeyChangedNotification = Notification.Name("VellumScratchHotKeyChanged")
}