import Foundation
import Observation

@MainActor
@Observable
public final class AppSettings {
    public static let defaultModelID = "large-v3-turbo"

    @ObservationIgnored private let defaults: UserDefaults

    public var hotkey: Hotkey { didSet { defaults.set(hotkey.rawValue, forKey: Key.hotkey) } }
    public var triggerMode: TriggerMode { didSet { defaults.set(triggerMode.rawValue, forKey: Key.triggerMode) } }
    public var language: Language { didSet { defaults.set(language.rawValue, forKey: Key.language) } }
    public var modelID: String { didSet { defaults.set(modelID, forKey: Key.modelID) } }
    public var dictionary: [String] { didSet { defaults.set(dictionary, forKey: Key.dictionary) } }
    public var removeFillers: Bool { didSet { defaults.set(removeFillers, forKey: Key.removeFillers) } }
    public var launchAtLogin: Bool { didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) } }

    /// Первичная настройка (разрешения и модель) хотя бы раз была завершена.
    public var setupCompleted: Bool { didSet { defaults.set(setupCompleted, forKey: Key.setupCompleted) } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hotkey = defaults.string(forKey: Key.hotkey).flatMap(Hotkey.init(rawValue:)) ?? .rightOption
        triggerMode = defaults.string(forKey: Key.triggerMode).flatMap(TriggerMode.init(rawValue:)) ?? .hold
        language = defaults.string(forKey: Key.language).flatMap(Language.init(rawValue:)) ?? .auto
        modelID = defaults.string(forKey: Key.modelID) ?? Self.defaultModelID
        dictionary = defaults.stringArray(forKey: Key.dictionary) ?? []
        removeFillers = defaults.object(forKey: Key.removeFillers) as? Bool ?? true
        setupCompleted = defaults.bool(forKey: Key.setupCompleted)
        launchAtLogin = defaults.object(forKey: Key.launchAtLogin) as? Bool ?? false
    }

    private enum Key {
        static let hotkey = "hotkey"
        static let triggerMode = "triggerMode"
        static let language = "language"
        static let modelID = "modelID"
        static let dictionary = "dictionary"
        static let removeFillers = "removeFillers"
        static let launchAtLogin = "launchAtLogin"
        static let setupCompleted = "setupCompleted"
    }
}
