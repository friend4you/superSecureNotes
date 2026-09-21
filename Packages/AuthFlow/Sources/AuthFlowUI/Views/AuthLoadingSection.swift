import SwiftUI

struct AuthLoadingSection: View {
    var body: some View {
        Section {
            HStack {
                Spacer()
                ProgressView(String(localized: "common.loading", bundle: .module))
                Spacer()
            }
        }
    }
}
