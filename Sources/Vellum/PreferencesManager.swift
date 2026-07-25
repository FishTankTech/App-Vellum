import Cocoa

class PreferencesManager {
    static let shared = PreferencesManager()

    private let defaults = UserDefaults.standard
    private let keyCodeKey = "hotKeyCode"
    private let modifiersKey = "hotKeyModifiersRaw"
    private let storagePathKey = "storagePath"

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

    var storageFolder: URL {
        get {
            if let path = defaults.string(forKey: storagePathKey) {
                return URL(fileURLWithPath: path)
            }
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Vellum")
        }
        set { defaults.set(newValue.path, forKey: storagePathKey) }
    }

    static let hotKeyChangedNotification = Notification.Name("VellumHotKeyChanged")
}