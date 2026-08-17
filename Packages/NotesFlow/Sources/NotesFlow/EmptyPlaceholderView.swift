import SwiftUI

struct EmptyPlaceholderView: View {
    let systemImage: String
    let title: String
    let description: String

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(verbatim: title)
            } icon: {
                Image(systemName: systemImage)
            }
        } description: {
            Text(verbatim: description)
        }
    }
}
