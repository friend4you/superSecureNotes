import SwiftUI
import XCTest

#if canImport(AppKit)
import AppKit
#endif

@testable import Navigation

private enum HostTestRoute: Route {
    case root
    case detail(Int)
}

@MainActor
private final class RouteRenderRecorder {
    private(set) var renderedIdentifiers: [String] = []

    func record(_ identifier: String) {
        renderedIdentifiers.append(identifier)
    }
}

@MainActor
private struct RouteRecordingView<Content: View>: View {
    let recorder: RouteRenderRecorder
    let identifier: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        let _ = recorder.record(identifier)
        content()
    }
}

@MainActor
final class NavigationHostTests: XCTestCase {
    func testNavigationHostRendersPushedRegisteredRoute() {
        let router = NavigationRouter()
        let recorder = RouteRenderRecorder()
        let registry = makeRegistry(recorder: recorder)
        router.setRoot(HostTestRoute.root)

        mountHost(NavigationHost(model: NavigationHostModel(router: router, registry: registry)))

        router.push(HostTestRoute.detail(42))

        waitForNavigation()

        XCTAssertTrue(recorder.renderedIdentifiers.contains("detail-route-42"))
    }

    func testNavigationHostPresentsRegisteredRouteAsSheet() {
        let router = NavigationRouter()
        let recorder = RouteRenderRecorder()
        let registry = makeRegistry(recorder: recorder)
        router.present(HostTestRoute.detail(7), style: .sheet)

        mountHost(NavigationHost(model: NavigationHostModel(router: router, registry: registry)))

        XCTAssertTrue(recorder.renderedIdentifiers.contains("detail-route-7"))
    }

    private func makeRegistry(recorder: RouteRenderRecorder) -> RouteRegistry {
        let registry = RouteRegistry(assertOnUnregisteredRoutes: false)
        registry.register(HostTestRoute.self) { route in
            switch route {
            case .root:
                AnyView(
                    RouteRecordingView(recorder: recorder, identifier: "root-route") {
                        Text("Root")
                    }
                )
            case let .detail(value):
                AnyView(
                    RouteRecordingView(recorder: recorder, identifier: "detail-route-\(value)") {
                        Text("Detail \(value)")
                    }
                )
            }
        }
        return registry
    }

    private func mountHost(_ host: NavigationHost) {
        let hostingView = NSHostingView(rootView: host)
        hostingView.frame = CGRect(x: 0, y: 0, width: 400, height: 400)

        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)

        for _ in 0 ..< 20 {
            hostingView.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
    }

    private func waitForNavigation() {
        for _ in 0 ..< 20 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
    }
}
