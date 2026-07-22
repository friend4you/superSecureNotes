import Foundation

public enum AuthFlowUILocalization {
    public static func localized(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: .module)
    }
}
