import Foundation

enum NotesFlowUIBundleTesting {
    static var hasLocalizedCatalog: Bool {
        Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings") != nil
    }
}
