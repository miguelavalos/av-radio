import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            "English"
        case .spanish:
            "Espanol"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    static func resolved(from rawValue: String?) -> AppLanguage {
        guard let rawValue else { return .english }

        if let exactMatch = AppLanguage(rawValue: rawValue) {
            return exactMatch
        }

        let normalized = rawValue.lowercased()
        if normalized.hasPrefix("es") {
            return .spanish
        }

        return .english
    }
}

final class AppLanguageController: ObservableObject {
    @Published private(set) var currentLanguage: AppLanguage

    var locale: Locale {
        currentLanguage.locale
    }

    private let userDefaults: UserDefaults
    private let userDefaultsKey = "avradio.appLanguage"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        currentLanguage = AppLanguage.resolved(from: userDefaults.string(forKey: userDefaultsKey))
    }

    func select(_ language: AppLanguage) {
        guard currentLanguage != language else { return }
        currentLanguage = language
        userDefaults.set(language.rawValue, forKey: userDefaultsKey)
    }
}

enum L10n {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
    }

    static func string(_ key: String, _ arguments: CVarArg...) -> String {
        format(key, arguments: arguments)
    }

    static func plural(singular singularKey: String, plural pluralKey: String, count: Int, _ arguments: CVarArg...) -> String {
        format(count == 1 ? singularKey : pluralKey, arguments: arguments)
    }

    static func markdown(_ key: String) -> AttributedString {
        let localized = string(key)
        return (try? AttributedString(markdown: localized)) ?? AttributedString(localized)
    }

    static func markdown(_ key: String, _ arguments: CVarArg...) -> AttributedString {
        let localized = format(key, arguments: arguments)
        return (try? AttributedString(markdown: localized)) ?? AttributedString(localized)
    }

    static func genreLabel(for tag: String) -> String {
        switch tag.lowercased() {
        case "rock":
            return string("genre.rock")
        case "pop":
            return string("genre.pop")
        case "jazz":
            return string("genre.jazz")
        case "news":
            return string("genre.news")
        case "electronic":
            return string("genre.electronic")
        case "ambient":
            return string("genre.ambient")
        default:
            return tag.capitalized(with: .current)
        }
    }

    private static func format(_ key: String, arguments: [CVarArg]) -> String {
        let format = string(key)
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: .current, arguments: arguments)
    }

    private static var bundle: Bundle {
        let selectedLanguage = AppLanguage.resolved(from: UserDefaults.standard.string(forKey: "avradio.appLanguage"))

        guard let path = Bundle.main.path(forResource: selectedLanguage.rawValue, ofType: "lproj"),
              let localizedBundle = Bundle(path: path) else {
            return .main
        }

        return localizedBundle
    }
}
