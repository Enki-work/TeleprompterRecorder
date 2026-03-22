//
//  LanguageManager.swift
//  TeleprompterRecorder
//

import Foundation

final class LanguageManager {

    static let shared = LanguageManager()
    static let languageChangedNotification = Notification.Name("languageChanged")

    private let userDefaultsKey = "selectedLanguageCode"

    struct Language {
        let code: String
        let localName: String   // Name shown in its own language
    }

    let availableLanguages: [Language] = [
        Language(code: "ja",      localName: "日本語"),
        Language(code: "en",      localName: "English"),
        Language(code: "zh-Hans", localName: "简体中文"),
        Language(code: "zh-Hant", localName: "繁體中文"),
        Language(code: "ko",      localName: "한국어"),
        Language(code: "es",      localName: "Español"),
    ]

    var currentLanguage: String {
        get { UserDefaults.standard.string(forKey: userDefaultsKey) ?? autoDetectedLanguage }
        set {
            UserDefaults.standard.set(newValue, forKey: userDefaultsKey)
            _bundle = nil   // invalidate cache
            NotificationCenter.default.post(name: LanguageManager.languageChangedNotification, object: nil)
        }
    }

    // MARK: - Localize

    func localized(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: "???\(key)???", table: nil)
    }

    // MARK: - Private

    private var _bundle: Bundle?

    private var bundle: Bundle {
        if let b = _bundle { return b }
        let code = currentLanguage
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let b = Bundle(path: path) {
            _bundle = b
            return b
        }
        // Fallback: Japanese
        if let path = Bundle.main.path(forResource: "ja", ofType: "lproj"),
           let b = Bundle(path: path) {
            _bundle = b
            return b
        }
        _bundle = Bundle.main
        return Bundle.main
    }

    private var autoDetectedLanguage: String {
        let preferred = Locale.preferredLanguages.first ?? "ja"
        for lang in availableLanguages {
            if preferred.hasPrefix(lang.code) { return lang.code }
        }
        // Handle zh-Hans / zh-Hant prefix "zh"
        if preferred.hasPrefix("zh") {
            return preferred.contains("Hant") || preferred.contains("TW") || preferred.contains("HK") ? "zh-Hant" : "zh-Hans"
        }
        return "ja"
    }

    private init() {}
}

/// Convenience global function for localization.
func L(_ key: String) -> String {
    LanguageManager.shared.localized(key)
}
