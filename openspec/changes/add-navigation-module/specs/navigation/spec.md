## ADDED Requirements

### Requirement: Navigation package module boundary

The project SHALL provide a Swift Package `Navigation` with two library products: `NavigationProtocol` and `Navigation`. `NavigationProtocol` SHALL support iOS 17+ and macOS 13+ and SHALL NOT depend on SwiftUI. `Navigation` SHALL depend on `NavigationProtocol` and SwiftUI.

#### Scenario: Package builds with both targets

- **WHEN** the `Navigation` package is built
- **THEN** `NavigationProtocol` and `Navigation` targets compile successfully on supported platforms

#### Scenario: NavigationProtocol has no SwiftUI dependency

- **WHEN** `NavigationProtocol` is built
- **THEN** it does not import SwiftUI

### Requirement: Route protocol

`NavigationProtocol` SHALL define a public protocol `Route` that inherits `Hashable` and `Sendable`. Module route enums SHALL conform to `Route`.

#### Scenario: Route enum conforms to Route

- **WHEN** a module defines `enum NotesRoute: Route { case list }`
- **THEN** `NotesRoute` can be used with navigation APIs constrained to `Route`

### Requirement: NavigationRouting protocol

`NavigationProtocol` SHALL define a `@MainActor` protocol `NavigationRouting` with methods to `setRoot`, `push` a route, `present` a route with a presentation style, `pop`, and `popToRoot`. `present` SHALL support sheet and full-screen cover styles via a `RoutePresentation` type.

#### Scenario: SetRoot replaces stack with one route

- **WHEN** `router.setRoot(AuthRoute.login)` is called
- **THEN** the router's root route is `AuthRoute.login` and the push path is empty

#### Scenario: SetRoot clears presented modals

- **WHEN** a route is presented and then `router.setRoot(NotesRoute.list)` is called
- **THEN** the router has no presented modal route

#### Scenario: Push appends to navigation path

- **WHEN** `router.push(NotesRoute.list)` is called
- **THEN** the router's navigation path grows by one entry

#### Scenario: Present sets modal route

- **WHEN** `router.present(NotesRoute.list, style: .sheet)` is called
- **THEN** the router exposes a presented route for sheet display

#### Scenario: PopToRoot keeps root route

- **WHEN** `router.popToRoot()` is called after pushing routes on top of a root
- **THEN** the push path is empty and the root route is unchanged

### Requirement: NavigationPath storage

`Navigation` SHALL provide a `NavigationRouter` that stores the root route separately from a SwiftUI `NavigationPath` used for pushed routes. The router's `push` method SHALL append the concrete route value directly to the push path (`path.append(route)`). Module route enums (`AuthRoute`, `NotesRoute`, etc.) SHALL be storable in the same push path without a custom type-erasure wrapper.

#### Scenario: Heterogeneous routes in one push path

- **WHEN** `router.push(AuthRoute.login)` is called and then `router.push(NotesRoute.list)` is called
- **THEN** the router's push `NavigationPath` contains both entries

#### Scenario: Push appends route directly

- **WHEN** `router.push(NotesRoute.list)` is called
- **THEN** the navigation path grows by one entry holding `NotesRoute.list`

### Requirement: Route registry

`Navigation` SHALL provide a route registry that maps a concrete route type to a view builder. Registration SHALL occur at app composition time. `NavigationHost` SHALL apply `.navigationDestination(for:)` per registered route type and use the registry builder to produce the screen.

#### Scenario: Registered route resolves to view

- **WHEN** `NotesRoute` is registered with a view builder and `NavigationHost` handles `NotesRoute.list`
- **THEN** a non-empty SwiftUI view is returned

#### Scenario: Unregistered route fails in debug

- **WHEN** the router pushes a route type that was not registered
- **THEN** debug builds surface a diagnosable failure

### Requirement: NavigationHost

`Navigation` SHALL provide a `NavigationHost` SwiftUI view that binds to a `NavigationRouting` implementation, renders the navigation stack from the router path, applies registered destinations, and supports presented routes (sheet and full-screen cover).

#### Scenario: NavigationHost renders pushed route

- **WHEN** `NavigationHost` is mounted and the router pushes a registered route
- **THEN** the corresponding screen appears in the navigation hierarchy

### Requirement: Navigation does not observe VaultSession

The `Navigation` package SHALL NOT depend on `VaultSession` or observe session state. Session-driven navigation SHALL be performed by the app calling router methods.

#### Scenario: No VaultSession import in Navigation

- **WHEN** `Navigation` package sources are inspected
- **THEN** they do not import `VaultSession` or `VaultSessionProtocol`

### Requirement: Navigating protocol

`NavigationProtocol` SHALL define a `@MainActor` protocol `Navigating` that inherits `NavigationRouting` and adds `dismissPresentation()`. Feature modules SHALL depend on `NavigationProtocol` (UI-free) to navigate.

#### Scenario: Navigating includes dismissPresentation

- **WHEN** `Navigating` is inspected
- **THEN** it includes `dismissPresentation()` in addition to `NavigationRouting` methods

### Requirement: AppNavigator

`Navigation` SHALL provide an `AppNavigator` type that implements `Navigating`, wraps an internal `NavigationRouter` and `RouteRegistry`, and validates route type registration before `setRoot`, `push`, or `present`.

#### Scenario: Push validates registration before mutating state

- **WHEN** `navigator.push(route)` is called with an unregistered route type
- **THEN** debug builds surface a diagnosable failure and the router push path is not mutated

#### Scenario: Push delegates to router when registered

- **WHEN** `navigator.push(NotesRoute.list)` is called and `NotesRoute` is registered
- **THEN** the internal router's push path grows by one entry

### Requirement: Route registry startup verification

`RouteRegistry` SHALL auto-track route types registered via `register()`. It SHALL provide `verifyRegistered(...)` to assert all expected route types were registered. App composition SHALL call `verifyRegistered` after all module registrations (debug builds).

#### Scenario: VerifyRegistered passes when all types registered

- **WHEN** `AuthRoute` and `NotesRoute` are registered and `verifyRegistered(AuthRoute.self, NotesRoute.self)` is called
- **THEN** verification succeeds

#### Scenario: VerifyRegistered fails when type missing

- **WHEN** `NotesRoute` is not registered and `verifyRegistered(NotesRoute.self)` is called
- **THEN** debug builds surface a diagnosable failure

### Requirement: NavigationCoordinator exposes navigator

`NavigationCoordinator` SHALL expose `navigator: Navigating` as its public navigation API. `NavigationRouter` SHALL NOT be exposed to the app target.

#### Scenario: App uses navigator not router

- **WHEN** app composition performs session-driven root transitions
- **THEN** it calls `navigator.setRoot(...)` not `router.setRoot(...)`

### Requirement: No environment-injected router

`NavigationHost` SHALL NOT inject `NavigationRouting` into the SwiftUI environment. Feature navigation SHALL use `Navigating` from module deps bags.

#### Scenario: NavigationHost does not set navigationRouter environment

- **WHEN** `NavigationHost` source is inspected
- **THEN** it does not set `\.navigationRouter` on the environment
