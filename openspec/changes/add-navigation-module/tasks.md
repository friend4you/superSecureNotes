## 1. Navigation package scaffold

- [x] 1.1 Create `Packages/Navigation/` with `NavigationProtocol` and `Navigation` targets, test targets, and `Package.swift` (iOS 17+, macOS 13+)
- [x] 1.2 Add `Navigation` and `NavigationProtocol` products to `superSecureNotes.xcodeproj`

## 2. NavigationProtocol — Route and NavigationRouting

- [x] 2.1 Write failing tests for `Route` constraint (sample enum conforms, is `Hashable`/`Sendable`) and `RoutePresentation` cases in `NavigationProtocolTests`
- [x] 2.2 Implement `Route`, `RoutePresentation`, and `NavigationRouting` in `NavigationProtocol`
- [x] 2.3 Write failing tests for `NavigationRouting` mock verifying `push`, `present`, `pop`, `popToRoot` contracts in `NavigationProtocolTests`
- [x] 2.4 Verify protocol surface compiles without SwiftUI
- [x] 2.5 Add `setRoot` to `NavigationRouting` with tests (replaces stack, clears modals)

## 3. Navigation — NavigationPath storage

- [x] 3.1 Design decision: `NavigationPath` stores module routes directly (no `RouteBox`)
- [x] 3.2 Remove `RouteBox` implementation and tests from Navigation package

## 4. Navigation — RouteRegistry

- [x] 4.1 Write failing tests: registered `NotesRoute` resolves to view; unregistered route type fails in debug (`NavigationTests`)
- [x] 4.2 Implement `RouteRegistry` keyed by route type with `AnyView` builder capture

## 5. Navigation — NavigationRouter

- [x] 5.1 Write failing tests: `setRoot` replaces `NavigationPath`; `push` appends route; `popToRoot` keeps root; `present` sets modal state (`NavigationTests`)
- [x] 5.2 Implement `@Observable NavigationRouter` conforming to `NavigationRouting` with `NavigationPath`

## 6. Navigation — NavigationHost

- [x] 6.1 Write failing SwiftUI tests: host renders pushed registered route; sheet presentation appears (`NavigationTests`)
- [x] 6.2 Implement `NavigationHost` with `NavigationStack`, per-route-type `navigationDestination`, sheet, and fullScreenCover bindings

## 7. AuthFlowRoutes target

- [x] 7.1 Write failing tests: `AuthRoute` conforms to `Route`; includes `.login` and `.register` (`AuthFlowRoutesTests` or `AuthFlowTests`)
- [x] 7.2 Add `AuthFlowRoutes` target to `AuthFlow` package depending on `NavigationProtocol`; implement `AuthRoute`
- [x] 7.3 Export `AuthFlowRoutes` product; add to Xcode project

## 8. AuthFlowDependencyProviding and AuthNavigation

- [x] 8.1 Write failing tests: `AuthNavigation.view(for: .login, deps:)` returns `LoginView`; `.register` returns `RegisterView` using mock `AuthFlowDependencyProviding` (`AuthFlowUITests`)
- [x] 8.2 Add public `AuthFlowDependencyProviding` protocol to `AuthFlowProtocol`
- [x] 8.3 Implement internal `AuthNavigation.view(for:deps:)` in `AuthFlowUI`

## 9. AuthFlowUI routing refactor

- [x] 9.1 Write failing tests: `LoginView` has no `NavigationLink`; tapping register calls `router.push(AuthRoute.register)` (`AuthFlowUITests`)
- [x] 9.2 Refactor `LoginView` to use `NavigationRouting` from environment; remove `makeRegisterViewModel` navigation parameter
- [x] 9.3 Update `RegisterView` previews and `PreviewSupport` to use `AuthFlowDependencyProviding` mock and router
- [x] 9.4 Update existing `LoginViewTests` and `RegisterViewTests` for new API

## 10. NotesFlowRoutes target

- [x] 10.1 Write failing tests: `NotesRoute` conforms to `Route`; includes `.list` (`NotesFlowTests`)
- [x] 10.2 Add `NotesFlowRoutes` target to `NotesFlow` package depending on `NavigationProtocol`; implement `NotesRoute`
- [x] 10.3 Export `NotesFlowRoutes` product; add to Xcode project

## 11. NotesDependencyProviding and NotesNavigation

- [x] 11.1 Write failing tests: `NotesNavigation.view(for: .list, deps:)` returns `NoteListView` with mock `NotesDependencyProviding` (`NotesFlowTests`)
- [x] 11.2 Add public `NotesDependencyProviding` protocol and internal `NotesNavigation.view(for:deps:)` to `NotesFlow`
- [x] 11.3 Update `NotesFlow` target to depend on `NotesFlowRoutes`

## 12. App navigation wiring

- [x] 12.1 Write failing tests or integration checks: `AppAuthDependencies` conforms to `AuthFlowDependencyProviding`; `AppNotesDependencies` conforms to `NotesDependencyProviding` (app test target if present, else compile-time wiring review task with XCTest scaffold)
- [x] 12.2 Implement `AppAuthDependencies` and `AppNotesDependencies` in app target mapping from `AppDependencies`
- [x] 12.3 Write failing tests: on `VaultSession` inactive → `setRoot(AuthRoute.login)`; on active → `setRoot(NotesRoute.list)` (app/UI test scaffold)
- [x] 12.4 Refactor `RootView` to register routes, mount `NavigationHost`, observe `VaultSession.changes`, and drive router on session transitions
- [x] 12.5 Remove ad-hoc `NavigationStack` wrappers from `RootView`
- [x] 12.6 Link `Navigation`, `NavigationProtocol`, `AuthFlowRoutes`, `NotesFlowRoutes` in app target

## 13. Final verification

- [ ] 13.1 Run full test suite; fix regressions from `LoginView` API change
- [ ] 13.2 Manual smoke: login → register via router; session activate → notes list; logout/session clear → auth entry
