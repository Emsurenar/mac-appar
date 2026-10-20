import Foundation

/// Returns the translation of an English source string.
/// Translations live in `Resources/<language>.lproj/Localizable.strings`; English is the fallback.
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

/// Formats a translated string, e.g. `L("%ld min", 5)`.
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: .current, arguments: args)
}
