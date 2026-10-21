import Foundation

/// The language the app speaks. "System" follows the Mac's own language.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english = "en", swedish = "sv"

    var id: String { rawValue }

    /// Languages are listed in their own language, so they're easy to find.
    var title: String {
        switch self {
        case .system: return L("System default")
        case .english: return "English"
        case .swedish: return "Svenska"
        }
    }
}

/// Picks the strings and the locale (weekday names, times) for the chosen language.
enum Localizer {
    private(set) static var bundle = Bundle.main
    private(set) static var locale = Locale.current

    static func apply(_ language: AppLanguage) {
        guard language != .system,
              let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            bundle = .main
            locale = .current
            return
        }
        bundle = languageBundle
        // Keep the region, so dates and times still look the way the person is used to.
        let region = Locale.current.region.map { "_\($0.identifier)" } ?? ""
        locale = Locale(identifier: language.rawValue + region)
    }
}

/// Returns the translation of an English source string.
/// Translations live in `Resources/<language>.lproj/Localizable.strings`; English is the fallback.
func L(_ key: String) -> String {
    Localizer.bundle.localizedString(forKey: key, value: key, table: nil)
}

/// Formats a translated string, e.g. `L("%ld min", 5)`.
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), locale: Localizer.locale, arguments: args)
}
