import Foundation

enum AuthFlowUIBundleTesting {
    static var hasLocalizedCatalog: Bool {
        Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings") != nil
    }
}
