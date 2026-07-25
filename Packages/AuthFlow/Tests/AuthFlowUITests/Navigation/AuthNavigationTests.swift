import AuthFlowProtocol
import AuthFlowRoutes
import AuthFlowUI
import XCTest

@testable import AuthFlowUI

@MainActor
private final class MockAuthFlowDependencies: AuthFlowDependencyProviding {
    private(set) var makeLoginViewModelCallCount = 0
    private(set) var makeRegisterViewModelCallCount = 0

    func makeLoginViewModel() -> DefaultLoginViewModel {
        makeLoginViewModelCallCount += 1
        return PreviewSupport.makeLoginViewModel()
    }

    func makeRegisterViewModel() -> DefaultRegisterViewModel {
        makeRegisterViewModelCallCount += 1
        return PreviewSupport.makeRegisterViewModel()
    }
}

@MainActor
final class AuthNavigationTests: XCTestCase {
    func testViewForLoginBuildsLoginView() {
        let deps = MockAuthFlowDependencies()

        _ = AuthNavigation.loginView(deps: deps)

        XCTAssertEqual(deps.makeLoginViewModelCallCount, 1)
        XCTAssertEqual(deps.makeRegisterViewModelCallCount, 0)
    }

    func testViewForRegisterBuildsRegisterView() {
        let deps = MockAuthFlowDependencies()

        _ = AuthNavigation.registerView(deps: deps)

        XCTAssertEqual(deps.makeRegisterViewModelCallCount, 1)
        XCTAssertEqual(deps.makeLoginViewModelCallCount, 0)
    }

    func testViewForLoginUsesDependencyProviding() {
        let deps = MockAuthFlowDependencies()

        _ = AuthNavigation.view(for: .login, deps: deps)

        XCTAssertEqual(deps.makeLoginViewModelCallCount, 1)
    }

    func testViewForRegisterUsesDependencyProviding() {
        let deps = MockAuthFlowDependencies()

        _ = AuthNavigation.view(for: .register, deps: deps)

        XCTAssertEqual(deps.makeRegisterViewModelCallCount, 1)
    }
}
