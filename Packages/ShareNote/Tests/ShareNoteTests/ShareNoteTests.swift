import Navigation
import NavigationProtocol
import ShareNote
import ShareNoteRoutes
import XCTest

@MainActor
private final class MockNavigating: Navigating {
    private(set) var popCallCount = 0
    private(set) var dismissPresentationCallCount = 0

    func setRoot<R: Route>(_ route: R) {}
    func push<R: Route>(_ route: R) {}
    func present<R: Route>(_ route: R, style: RoutePresentation) {}
    func pop() { popCallCount += 1 }
    func popToRoot() {}
    func dismissPresentation() { dismissPresentationCallCount += 1 }
}

@MainActor
private final class MockShareNoteDependencies: ShareNoteDependencyProviding {
    private let navigator: any Navigating

    init(navigator: any Navigating) {
        self.navigator = navigator
    }

    func makeShareNoteViewModel(noteID: UUID) -> DefaultShareNoteViewModel {
        DefaultShareNoteViewModel(noteID: noteID, navigator: navigator)
    }
}

@MainActor
final class DefaultShareNoteViewModelTests: XCTestCase {
    func testViewModelExposesNoteID() {
        let noteID = UUID()
        let viewModel = DefaultShareNoteViewModel(
            noteID: noteID,
            navigator: MockNavigating()
        )

        XCTAssertEqual(viewModel.noteID, noteID)
    }

    func testDismissCallsDismissPresentation() {
        let navigator = MockNavigating()
        let viewModel = DefaultShareNoteViewModel(
            noteID: UUID(),
            navigator: navigator
        )

        viewModel.dismiss()

        XCTAssertEqual(navigator.dismissPresentationCallCount, 1)
        XCTAssertEqual(navigator.popCallCount, 0)
    }
}

@MainActor
final class ShareNoteDependenciesTests: XCTestCase {
    func testShareNoteDependenciesConformsToShareNoteDependencyProviding() {
        let dependencies: any ShareNoteDependencyProviding = ShareNoteDependencies(
            navigator: MockNavigating()
        )

        XCTAssertTrue(dependencies is ShareNoteDependencies)
    }

    func testMakeShareNoteViewModelReturnsDefaultImplementationWithMatchingNoteID() {
        let noteID = UUID()
        let dependencies = ShareNoteDependencies(navigator: MockNavigating())

        let viewModel = dependencies.makeShareNoteViewModel(noteID: noteID)

        XCTAssertTrue(viewModel is DefaultShareNoteViewModel)
        XCTAssertEqual(viewModel.noteID, noteID)
    }
}

@MainActor
final class ShareNoteViewTests: XCTestCase {
    func testShareNoteViewAcceptsViewModel() {
        let viewModel = DefaultShareNoteViewModel(
            noteID: UUID(),
            navigator: MockNavigating()
        )

        _ = ShareNoteView(viewModel: viewModel)
    }

    func testShareNoteViewPlaceholderText() {
        XCTAssertEqual(ShareNoteView.placeholderText, "Share note")
    }
}

@MainActor
final class ShareNoteNavigationTests: XCTestCase {
    func testViewForShareBuildsShareNoteView() {
        let noteID = UUID()
        let deps = MockShareNoteDependencies(navigator: MockNavigating())

        _ = ShareNoteNavigation.shareView(noteID: noteID, deps: deps)
    }

    func testViewForShareUsesDependencyProviding() {
        let noteID = UUID()
        let deps = MockShareNoteDependencies(navigator: MockNavigating())

        _ = ShareNoteNavigation.view(for: .share(noteID: noteID), deps: deps)
    }

    func testRegisterShareNoteRoutesResolvesRegisteredRoute() {
        let deps = MockShareNoteDependencies(navigator: MockNavigating())
        let registry = RouteRegistry(assertOnUnregisteredRoutes: false)
        registry.registerShareNoteRoutes(deps: deps)

        let noteID = UUID()
        _ = registry.view(for: ShareNoteRoute.share(noteID: noteID))

        XCTAssertTrue(registry.isRegistered(ShareNoteRoute.self))
    }
}
