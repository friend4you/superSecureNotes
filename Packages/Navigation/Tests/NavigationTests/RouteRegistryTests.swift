import SwiftUI
import XCTest

@testable import Navigation

private enum NotesRoute: Route {
    case list
}

private enum UnregisteredRoute: Route {
    case other
}

@MainActor
final class RouteRegistryTests: XCTestCase {
    func testRegisteredNotesRouteResolvesToView() {
        var capturedRoute: NotesRoute?
        let registry = RouteRegistry()
        registry.register(NotesRoute.self) { route in
            capturedRoute = route
            return AnyView(Text("Notes List"))
        }

        _ = registry.view(for: NotesRoute.list)

        XCTAssertEqual(capturedRoute, .list)
    }

    func testUnregisteredRouteTypeIsNotRegistered() {
        let registry = RouteRegistry()
        registry.register(NotesRoute.self) { _ in
            AnyView(Text("Notes List"))
        }

        XCTAssertTrue(registry.isRegistered(NotesRoute.self))
        XCTAssertFalse(registry.isRegistered(UnregisteredRoute.self))
    }

    func testViewForUnregisteredRouteReturnsPlaceholderWithoutInvokingRegisteredBuilder() {
        var builderCalled = false
        let registry = RouteRegistry(assertOnUnregisteredRoutes: false)
        registry.register(NotesRoute.self) { _ in
            builderCalled = true
            return AnyView(Text("Notes List"))
        }

        _ = registry.view(for: UnregisteredRoute.other)

        XCTAssertFalse(builderCalled)
    }

    func testVerifyRegisteredPassesWhenAllExpectedTypesRegistered() {
        let registry = RouteRegistry(assertOnUnregisteredRoutes: false)
        registry.register(NotesRoute.self) { _ in
            AnyView(Text("Notes List"))
        }

        registry.verifyRegistered([NotesRoute.self])
    }

    func testVerifyRegisteredDoesNotInvokeRegisteredBuilder() {
        var builderCalled = false
        let registry = RouteRegistry(assertOnUnregisteredRoutes: false)
        registry.register(NotesRoute.self) { _ in
            builderCalled = true
            return AnyView(Text("Notes List"))
        }

        registry.verifyRegistered([NotesRoute.self])

        XCTAssertFalse(builderCalled)
    }
}
