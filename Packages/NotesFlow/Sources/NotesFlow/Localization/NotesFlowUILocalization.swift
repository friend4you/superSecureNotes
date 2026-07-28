import Foundation

public enum NotesFlowUILocalization {
    public static func localized(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: .module)
    }
}
