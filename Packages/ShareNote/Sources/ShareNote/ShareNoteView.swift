import SwiftUI

public struct ShareNoteView: View {
    public static let placeholderText = "Share note"

    @Bindable private var viewModel: DefaultShareNoteViewModel

    public init(viewModel: DefaultShareNoteViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Text(Self.placeholderText)
    }
}

#Preview {
    ShareNoteView(
        viewModel: DefaultShareNoteViewModel(
            noteID: UUID(),
            navigator: PreviewNavigating()
        )
    )
}

#if DEBUG
import Foundation
import NavigationProtocol

@MainActor
private final class PreviewNavigating: Navigating {
    func setRoot<R: Route>(_ route: R) {}
    func push<R: Route>(_ route: R) {}
    func present<R: Route>(_ route: R, style: RoutePresentation) {}
    func pop() {}
    func popToRoot() {}
    func dismissPresentation() {}
}
#endif
