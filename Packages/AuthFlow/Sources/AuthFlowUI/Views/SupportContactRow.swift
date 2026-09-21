import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SupportContactRow: View {
    @Environment(\.openURL) private var openURL
    @State private var showCopiedAlert = false

    var body: some View {
        Button {
            openSupportEmail()
        } label: {
            Text(String(localized: "bio.settings.support", bundle: .module))
        }
        .alert(
            String(localized: "bio.settings.support.unavailable.title", bundle: .module),
            isPresented: $showCopiedAlert
        ) {
            Button(String(localized: "bio.settings.done", bundle: .module), role: .cancel) {}
        } message: {
            Text(
                String(
                    format: String(localized: "bio.settings.support.unavailable.message", bundle: .module),
                    AuthLegalLinks.supportEmailAddress
                )
            )
        }
    }

    private func openSupportEmail() {
        openURL(AuthLegalLinks.supportEmailURL) { accepted in
            guard !accepted else { return }
            #if canImport(UIKit)
            UIPasteboard.general.string = AuthLegalLinks.supportEmailAddress
            #endif
            showCopiedAlert = true
        }
    }
}
