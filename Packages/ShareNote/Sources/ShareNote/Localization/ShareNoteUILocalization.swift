import Foundation

enum ShareNoteUILocalization {
    private static let englishDefaults: [String: String] = [
        "share.title": "Share Note",
        "share.emailField": "Recipient Email",
        "share.button": "Share",
        "share.loading": "Sharing…",
        "share.error.emptyEmail": "Enter a recipient email.",
        "share.error.notSynced": "Sync this note before sharing.",
        "share.error.recipientNotFound": "No account found for that email.",
        "share.cancel": "Cancel",
    ]

    static func localized(_ key: String.LocalizationValue) -> String {
        let localized = String(localized: key, bundle: .module)
        let keyString = String(describing: key)
        if localized != keyString {
            return localized
        }
        return englishDefaults[keyString] ?? keyString
    }
}
