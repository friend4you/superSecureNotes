import AuthFlowProtocol
import AuthFlowRoutes
import AuthFlowUI
import XCTest

@testable import AuthFlowUI

@MainActor
private final class MockAuthFlowDependencies: AuthFlowDependencyProviding {
    private(set) var makeLoginViewModelCallCount = 0
    private(set) var makeRegisterViewModelCallCount = 0
    private(set) var lastLoginNavigator: (any LoginNavigating)?

    func makeLoginViewModel(navigator: any LoginNavigating) -> DefaultLoginViewModel {
        makeLoginViewModelCallCount += 1
        lastLoginNavigator = navigator
        return PreviewSupport.makeLoginViewModel(navigator: navigator)
    }

    func makeRegisterViewModel() -> DefaultRegisterViewModel {
        makeRegisterViewModelCallCount += 1
        return PreviewSupport.makeRegisterViewModel()
    }
}

@MainActor
private final class MockLoginNavigator: LoginNavigating {
    func showRegister() {}
}

@MainActor
final class AuthNavigationTests: XCTestCase {
    func testViewForLoginBuildsLoginView() {
        let deps = MockAuthFlowDependencies()
        let navigator = MockLoginNavigator()

        _ = AuthNavigation.loginView(deps: deps, navigator: navigator)

        XCTAssertEqual(deps.makeLoginViewModelCallCount, 1)
        XCTAssertEqual(deps.makeRegisterViewModelCallCount, 0)
        XCTAssertTrue(deps.lastLoginNavigator === navigator)
    }

    func testViewForRegisterBuildsRegisterView() {
        let deps = MockAuthFlowDependencies()

        _ = AuthNavigation.registerView(deps: deps)

        XCTAssertEqual(deps.makeRegisterViewModelCallCount, 1)
        XCTAssertEqual(deps.makeLoginViewModelCallCount, 0)
    }

    func testViewForLoginUsesDependencyProviding() {
        let deps = MockAuthFlowDependencies()
        let navigator = MockLoginNavigator()

        _ = AuthNavigation.view(for: .login, deps: deps, navigator: navigator)

        XCTAssertEqual(deps.makeLoginViewModelCallCount, 1)
    }

    func testViewForRegisterUsesDependencyProviding() {
        let deps = MockAuthFlowDependencies()
        let navigator = MockLoginNavigator()

        _ = AuthNavigation.view(for: .register, deps: deps, navigator: navigator)

        XCTAssertEqual(deps.makeRegisterViewModelCallCount, 1)
    }
}
